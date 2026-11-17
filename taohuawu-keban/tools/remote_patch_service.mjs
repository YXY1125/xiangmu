import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {appRoot,connect,runPython} from './remote_support.mjs';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const previous=JSON.parse(await fs.readFile(path.join(appRoot,'.runtime/deploy/release-manifest.json'),'utf8'));
const content=JSON.parse(await fs.readFile(path.join(appRoot,'docs/validation/deploy/content-deploy.json'),'utf8'));
if(!content.passed)throw Error('Verified content release required');
const bytes=await fs.readFile(path.join(appRoot,'server/src/service.mjs'));
const m={root:content.appRoot,before:previous.files.find(f=>f.name==='server/src/service.mjs').sha256,after:hash(bytes),base64:bytes.toString('base64'),release:'servicefix-'+new Date().toISOString().replace(/[-:.]/g,'')};
const script=String.raw`
import os,json,pathlib,base64,hashlib,subprocess,time,shutil,urllib.request
ROOT=pathlib.Path('/www/server/thwkb.zh.huawei');NAME='harmonyos-saas26-api'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def processes():return json.loads(subprocess.check_output(['pm2','jlist'],stderr=subprocess.DEVNULL))
def apply(m):
 result={'app':'thwkb.zh.huawei','passed':False,'rolledBack':False,'schemaChanged':False,'sharedSourceChanged':False};changed=False
 stage='exact-app-baseline';p=pathlib.Path(m['root'])/'server/src/service.mjs'
 try:
  assert p.parent.parent.parent.parent==ROOT/'releases' and sha(p)==m['before']
  before=processes();api=next(a for a in before if a['name']==NAME);assert api['pm2_env']['THWKB_APP_ROOT']==m['root'] and api['pm2_env']['status']=='online'
  backup=ROOT/'backups'/m['release'];backup.mkdir(mode=0o700);shutil.copy2(p,backup/'service.mjs')
  pending=p.with_suffix('.mjs.pending');pending.write_bytes(base64.b64decode(m['base64']));assert sha(pending)==m['after']
  # Node --check requires a JavaScript extension; parse staged source over stdin instead.
  assert subprocess.run(['node','--input-type=module','--check'],input=pending.read_bytes(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
  assert sha(p)==m['before'];os.replace(pending,p);changed=True;stage='single-api-restart'
  subprocess.run(['pm2','restart',NAME],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=40,check=True)
  ready=False
  for _ in range(20):
   try:
    req=urllib.request.Request('http://127.0.0.1:3126/api/v1/biz/thwkb.zh.huawei/home',headers={'X-Tenant-Id':'thwkb.zh.huawei'})
    with urllib.request.urlopen(req,timeout=4) as r:data=json.load(r)
    if data['code']==0 and len(data['data']['banners'])==4:ready=True;break
   except Exception:pass
   time.sleep(1)
  assert ready
  after=processes();assert all(any(q['name']==a['name'] and q['pid']==a['pid'] and q['pm2_env'].get('restart_time')==a['pm2_env'].get('restart_time') for q in after) for a in before if a['name']!=NAME)
  result.update(passed=True,before=m['before'],after=m['after'],backup=str(backup),appRoot=m['root'],otherProcessesUnchanged=True)
 except Exception as e:
  result.update(failedStage=stage,errorType=type(e).__name__)
  if changed and sha(p)==m['after']:
   shutil.copy2(backup/'service.mjs',p);subprocess.run(['pm2','restart',NAME],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=40);result['rolledBack']=True
 return result
`;
let client;
try{
 client=await connect();const payload=Buffer.from(JSON.stringify(m)).toString('base64');
 const report={at:new Date().toISOString(),...JSON.parse(await runPython(client.connection,script+`\nprint(json.dumps(apply(json.loads(base64.b64decode('${payload}')))))`))};
 await fs.appendFile(path.join(appRoot,'docs/validation/deploy/service-patch-attempts.jsonl'),JSON.stringify(report)+'\n');
 await fs.writeFile(path.join(appRoot,'docs/validation/deploy/service-patch.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));process.exitCode=report.passed?0:1;
}catch{console.error('Application service patch incomplete; sensitive diagnostics suppressed.');process.exitCode=1;}finally{client?.connection.end();}
