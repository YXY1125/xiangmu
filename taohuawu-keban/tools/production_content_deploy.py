"""Application-only additive content release. No DDL, no private records, no credential output."""
import os,json,pathlib,hashlib,subprocess,shutil,time,urllib.request,re
APP='thwkb.zh.huawei'
ROOT=pathlib.Path('/www/server')/APP
SITE=pathlib.Path('/www/wwwroot/saas26.qianqi.online')
NAME='harmonyos-saas26-api'
def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def processes(): return json.loads(subprocess.check_output(['pm2','jlist'],stderr=subprocess.DEVNULL,timeout=10))
def api_process(): return next(p for p in processes() if p['name']==NAME)
def query(sql):
 return subprocess.run(['runuser','-u','thwkbpg','--',str(ROOT/'pgsql/bin/psql'),'-X','-q','-A','-t','-v','ON_ERROR_STOP=1','-h',str(ROOT/'postgres-socket'),'-p','55426','-U','thwkbpg','-d','thwkb_zh_huawei'],input=sql.encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,check=True).stdout.decode().strip()
def stage(m):
 assert json.loads((ROOT/'owner.json').read_text())['app']==APP
 assert re.fullmatch(r'content-[0-9TZ]+',m['release'])
 current=pathlib.Path(api_process()['pm2_env']['THWKB_APP_ROOT'])
 assert current==ROOT/'releases'/m['previousRelease'] and sha(current/'db/seeds/001_content.json')==m['beforeSeedSha256']
 dest=ROOT/'releases'/m['release'];assert not dest.exists()
 shutil.copytree(current,dest);(dest/'upload').mkdir(mode=0o700)
 return {'staged':True,'directory':str(dest),'mutations':'application-owned release staging only'}
def promote(m):
 status={'app':APP,'release':m['release'],'passed':False,'databaseCommitted':False,'apiRestoredOnFailure':False}
 phase='validate-staged-files';changed=False
 before=processes();current=ROOT/'releases'/m['previousRelease'];dest=ROOT/'releases'/m['release']
 try:
  assert pathlib.Path(api_process()['pm2_env']['THWKB_APP_ROOT'])==current
  assert sha(current/'db/seeds/001_content.json')==m['beforeSeedSha256']
  for name,expected in m['documents'].items(): assert sha(dest/'upload'/name)==expected
  seed=json.loads((dest/'upload/content.json').read_text());approval=json.loads((dest/'upload/approval.json').read_text())
  assert seed['scope']=={'tenantId':APP,'appId':APP} and seed['productionReleaseApproved'] is True
  assert approval['decision']=='approved-for-project-production-use' and approval['seedSha256']==m['documents']['content.json']
  allowed={'Category','Character','Topic','KnowledgeArticle','Material','Template','Artwork'}
  assert all(not rows for kind,rows in seed['entities'].items() if kind not in allowed)
  assert all(r['tenantId']==APP and r['appId']==APP for rows in seed['entities'].values() for r in rows)
  assert all(not r.get('ownerUserId') and r['rightsEvidence']['releaseReview']=='approved' for r in seed['entities']['Artwork'])
  assert all(r['licenseRecord']['releaseReview']=='approved' and r['licenseRecord']['scope']=='in_app_composition' for r in seed['entities']['Material'])
  assert len(m['assets'])==91 and len({a['key'] for a in m['assets']})==91
  for a in m['assets']:
   assert re.fullmatch('[a-z0-9_]+',a['key']) and sha(dest/'upload'/(a['key']+'.webp'))==a['sha256']
  public=SITE/'media'/APP
  if public.exists():
   assert public.is_dir() and not public.is_symlink()
   for a in m['assets']:
    p=public/(a['key']+'.webp');assert not p.exists() or sha(p)==a['sha256']
  phase='backup'
  backup=ROOT/'backups'/m['release'];backup.mkdir(mode=0o700)
  dump=backup/'before-content.dump'
  with open(dump,'xb') as output:
   subprocess.run(['runuser','-u','thwkbpg','--',str(ROOT/'pgsql/bin/pg_dump'),'-Fc','-h',str(ROOT/'postgres-socket'),'-p','55426','-U','thwkbpg','-d','thwkb_zh_huawei'],stdout=output,stderr=subprocess.PIPE,timeout=60,check=True)
  assert dump.read_bytes().startswith(b'PGDMP')
  shutil.copy2(current/'db/seeds/001_content.json',backup/'previous-content.json')
  phase='additive-public-content-transaction'
  sql=(dest/'upload/seed.sql').read_text()
  assert sql.count('BEGIN;')==1 and sql.count('COMMIT;')==1 and 'DELETE ' not in sql and 'UPDATE ' not in sql and 'CREATE ' not in sql and 'ALTER ' not in sql
  query(sql.replace('BEGIN;','BEGIN;\nSET LOCAL ROLE thwkb_app;\nSELECT pg_advisory_xact_lock(hashtext(\'thwkb.zh.huawei\'));',1))
  status['databaseCommitted']=True
  phase='publish-verified-app-assets'
  public.mkdir(parents=True,exist_ok=True)
  for a in m['assets']:
   p=public/(a['key']+'.webp')
   if not p.exists():
    pending=public/(a['key']+'.webp.pending');shutil.copyfile(dest/'upload'/(a['key']+'.webp'),pending);os.chmod(pending,0o644);os.replace(pending,p)
   assert sha(p)==a['sha256']
  shutil.copyfile(dest/'upload/content.json',dest/'db/seeds/001_content.json')
  phase='activate-application-release'
  env=dict(os.environ,THWKB_APP_ROOT=str(dest));changed=True
  subprocess.run(['pm2','restart',NAME,'--update-env'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=40,check=True)
  def home():
   req=urllib.request.Request('http://127.0.0.1:3126/api/v1/biz/'+APP+'/home',headers={'X-Tenant-Id':APP})
   with urllib.request.urlopen(req,timeout=5) as r: return json.load(r)
  value=None
  for _ in range(20):
   try:
    value=home()
    if value.get('code')==0: break
   except Exception: pass
   time.sleep(1)
  assert value and value['code']==0 and len(value['data']['banners'])==4 and len(value['data']['characters'])==8
  assert len(value['data']['artworks'])==6 and len(value['data']['knowledge'])==3
  after=processes()
  assert all(any(q['name']==p['name'] and q['pid']==p['pid'] and q['pm2_env'].get('restart_time')==p['pm2_env'].get('restart_time') for q in after) for p in before if p['name']!=NAME)
  subprocess.run(['pm2','save'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15,check=True)
  status.update(passed=True,assetFiles=91,publicContentRecords=sum(len(v) for v in seed['entities'].values()),privateSeedRows=0,otherProcessesUnchanged=True,backup=str(backup),databaseBackupSha256=sha(dump),appRoot=str(dest),homeCounts={k:len(v) for k,v in value['data'].items() if isinstance(v,list)},schemaChanged=False,gateBPassed=False)
 except Exception as error:
  status.update(failedStage=phase,errorType=type(error).__name__,details='No private rows deleted, no schema changed; raw diagnostics suppressed')
  if changed:
   try:
    subprocess.run(['pm2','restart',NAME,'--update-env'],env=dict(os.environ,THWKB_APP_ROOT=str(current)),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=40,check=True);status['apiRestoredOnFailure']=True
   except Exception: pass
 (ROOT/('content-deploy-status.json')).write_text(json.dumps(status))
 return status
