"""Hash-checked application-only deployment. Input has code/config, never passwords."""
import os,json,base64,hashlib,subprocess,time,urllib.request,shutil,re
SITE='/www/wwwroot/saas26.qianqi.online'
ROOT='/www/server/thwkb.zh.huawei'
APP='thwkb.zh.huawei'
NAME='harmonyos-saas26-api'
ALLOWED={'app.module.js','tenant/tenant.interceptor.js','modules/privacy/privacy.module.js','modules/privacy/privacy.controller.js','modules/auth/auth.service.js'}
def digest(p):
 return hashlib.sha256(open(p,'rb').read()).hexdigest()
def command(args,cwd=None,env=None):
 return subprocess.run(args,cwd=cwd,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=35).returncode==0
def processes():
 return json.loads(subprocess.check_output(['pm2','jlist'],stderr=subprocess.DEVNULL,timeout=10))
def health():
 try:
  with urllib.request.urlopen('http://127.0.0.1:3126/api/v1/platform/health',timeout=3) as r:return r.status==200
 except Exception:return False
def deploy(manifest):
 stage='preconditions';changed=False;created=False;tenantCreated=False;moduleCreated=False;status={'app':APP,'release':manifest['release'],'passed':False,'rolledBack':False}
 release=ROOT+'/releases/'+manifest['release'];backup=ROOT+'/backups/'+manifest['release'];server=SITE+'/server'
 tenant=SITE+'/tenants/'+APP+'.json';module=server+'/dist/modules/thwkb/thwkb.module.js'
 try:
  assert set(x['name'] for x in manifest['shared'])==ALLOWED
  assert re.fullmatch(r'api-[0-9TZ]+',manifest['release'])
  assert json.load(open(ROOT+'/owner.json'))['app']==APP
  assert manifest['tenant']['tenantId']==APP and manifest['tenant']['bundleId']==APP
  assert not os.path.exists(release) and not os.path.exists(backup) and not os.path.exists(module) and not os.path.exists(tenant)
  before=processes();api=next(p for p in before if p['name']==NAME)
  assert api['pm2_env']['pm_cwd']==server and api['pm2_env']['status']=='online'
  assert not api['pm2_env'].get('THWKB_APP_ROOT') and not api['pm2_env'].get('THWKB_DATABASE_URL') and not api['pm2_env'].get('THWKB_DATABASE_CONFIG_FILE')
  assert health()
  for x in manifest['shared']:assert digest(server+'/dist/'+x['name'])==x['before']
  os.makedirs(release,mode=0o700);os.makedirs(backup,mode=0o700);created=True
  stage='stage-and-syntax'
  for x in manifest['files']:
   name=x['name'];assert not name.startswith('/') and '..' not in name.split('/') and (name in ['AppSpec.json','db/seeds/001_content.json','server/package.json','server/production.mjs','server/contracts/entities.json','server/dist/main.js','server/dist/modules/privacy/privacy.controller.js'] or name.startswith('server/src/') and name.endswith('.mjs') and name.count('/')==2)
   p=release+'/'+name;os.makedirs(os.path.dirname(p),exist_ok=True);open(p,'wb').write(base64.b64decode(x['base64']));assert digest(p)==x['sha256']
   if p.endswith(('.js','.mjs')):assert command(['node','--check',p])
  for x in manifest['shared']:
   p=backup+'/patched/'+x['name'];os.makedirs(os.path.dirname(p),exist_ok=True);open(p,'wb').write(base64.b64decode(x['base64']));assert digest(p)==x['after'];assert command(['node','--check',p])
   p=backup+'/original/'+x['name'];os.makedirs(os.path.dirname(p),exist_ok=True);shutil.copy2(server+'/dist/'+x['name'],p)
  moduleStage=backup+'/thwkb.module.js';open(moduleStage,'wb').write(base64.b64decode(manifest['module']['base64']));assert digest(moduleStage)==manifest['module']['sha256'];assert command(['node','--check',moduleStage])
  stage='database-runtime-probe'
  probe="""(async()=>{const e=await import(process.argv[1]+'/server/production.mjs');const r=await e.createProductionRuntime({appRoot:process.argv[1],databaseConfigFile:process.argv[2],platformPackage:process.cwd()+'/package.json',auth:{resolveAppSession:()=>null},activity:{},resolveAdmin:()=>null});const v=await r.dispatch({method:'GET',path:'/biz/thwkb.zh.huawei/home',headers:{'x-tenant-id':'thwkb.zh.huawei'},query:{},body:{}});await r.close();if(v.code!==0)process.exit(2)})().catch(()=>process.exit(1));"""
  assert command(['node','-e',probe,release,ROOT+'/secrets/database.json'],cwd=server)
  stage='promote'
  # Recheck immediately before replacing: never overwrite a concurrent deployment.
  for x in manifest['shared']:assert digest(server+'/dist/'+x['name'])==x['before']
  changed=True
  os.makedirs(os.path.dirname(module),exist_ok=True)
  with open(module,'xb') as f:f.write(open(moduleStage,'rb').read())
  moduleCreated=True
  for x in manifest['shared']:
   p=server+'/dist/'+x['name'];shutil.copy2(backup+'/patched/'+x['name'],p+'.thwkb-pending');os.replace(p+'.thwkb-pending',p)
  with open(tenant,'x') as f:json.dump(manifest['tenant'],f,ensure_ascii=False,indent=2)
  tenantCreated=True
  # No shared MySQL migration, no public content import, no admin credential mutation.
  stage='restart-and-health'
  environment=dict(os.environ,THWKB_APP_ROOT=release,THWKB_DATABASE_CONFIG_FILE=ROOT+'/secrets/database.json')
  assert command(['pm2','restart',NAME,'--update-env'],env=environment)
  for _ in range(20):
   if health():break
   time.sleep(1)
  assert health()
  stage='route-probe'
  req=urllib.request.Request('http://127.0.0.1:3126/api/v1/biz/'+APP+'/home',headers={'x-tenant-id':APP})
  with urllib.request.urlopen(req,timeout=10) as r:
   envelope=json.load(r);assert r.status==200 and envelope.get('code')==0
  after=processes();others={p['name']:(p.get('pid'),p['pm2_env'].get('restart_time')) for p in before if p['name']!=NAME}
  assert all((p.get('pid'),p['pm2_env'].get('restart_time'))==others[p['name']] for p in after if p['name'] in others)
  assert command(['pm2','save'])
  status.update(passed=True,apiHealth=True,applicationHome=True,otherProcessesUnchanged=True,tenantRegistered=True,database='PostgreSQL',contentSeedImported=False,adminCredentialCreated=False,backup=backup,appRoot=release,sharedFiles=[{'name':x['name'],'before':x['before'],'after':x['after']} for x in manifest['shared']])
 except Exception:
  status['failedStage']=stage
  if changed:
   # Refuse to restore over a later concurrent edit; retain backups for manual recovery.
   safe=all(digest(server+'/dist/'+x['name']) in [x['before'],x['after']] for x in manifest['shared'])
   if safe:
    for x in manifest['shared']:shutil.copy2(backup+'/original/'+x['name'],server+'/dist/'+x['name'])
    if moduleCreated and os.path.isfile(module) and digest(module)==manifest['module']['sha256']:os.unlink(module)
    if tenantCreated and os.path.isfile(tenant) and json.load(open(tenant)).get('tenantId')==APP:os.unlink(tenant)
    environment=dict(os.environ,THWKB_APP_ROOT='',THWKB_DATABASE_CONFIG_FILE='')
    restored=command(['pm2','restart',NAME,'--update-env'],env=environment)
    for _ in range(20):
     if health():break
     time.sleep(1)
    status['rolledBack']=bool(restored and health());command(['pm2','save'])
   else:status['rollbackBlockedByConcurrentEdit']=True
 if created:json.dump(status,open(backup+'/result.json','w'),indent=2)
 return status
