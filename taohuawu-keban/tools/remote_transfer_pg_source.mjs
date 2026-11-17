import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {appRoot,connect,runPython} from './remote_support.mjs';
const file=path.join(appRoot,'.runtime/downloads/postgresql-17.11-source.tar.gz');
const expected='5367f6fb2ec97efe1eb2e0c7926bb33438e51b0bd3a9733b88498056a7dc9a7e';
const bytes=await fs.readFile(file);if(crypto.createHash('sha256').update(bytes).digest('hex')!==expected)throw new Error('Verified official source hash mismatch');
const remote='/www/server/thwkb.zh.huawei/build/source-transfer-'+crypto.randomUUID()+'.tar.gz';
let client;
try{
  client=await connect();
  const pause=String.raw`import pathlib,json,os,signal,time
r=pathlib.Path('/www/server/thwkb.zh.huawei');p=r/'postgres-build-status.json'
s=json.loads(p.read_text());assert s['phase']=='downloading','Build progressed; do not replace active source'
matched=[]
for pid in os.listdir('/proc'):
 if pid.isdigit():
  try:
   args=(pathlib.Path('/proc')/pid/'cmdline').read_bytes().split(b'\0')
   if b'/www/server/thwkb.zh.huawei/build-postgres.py' in args:matched.append(int(pid))
  except OSError:pass
assert len(matched)==1
os.kill(matched[0],signal.SIGTERM);time.sleep(1)
a=r/'build/postgresql-17.11.tar.gz'
if a.exists():a.rename(a.with_name(a.name+'.interrupted-'+str(int(time.time()))))
p.write_text(json.dumps({'app':'thwkb.zh.huawei','phase':'failed','reason':'Slow download replaced with hash-verified transfer','time':time.time()}))
print(json.dumps({'pausedOwnDownload':True,'partialPreserved':True}))`;
  await runPython(client.connection,pause);
  const sftp=await new Promise((resolve,reject)=>client.connection.sftp((error,s)=>error?reject(error):resolve(s)));
  await new Promise((resolve,reject)=>sftp.fastPut(file,remote,{concurrency:8,mode:0o644},error=>error?reject(error):resolve()));
  const verify=`import pathlib,hashlib,json\np=pathlib.Path(${JSON.stringify(remote)})\nassert hashlib.sha256(p.read_bytes()).hexdigest()==${JSON.stringify(expected)}\nt=p.parent/'postgresql-17.11.tar.gz'\nassert not t.exists()\np.rename(t)\nprint(json.dumps({'sourceVerified':True,'bytes':t.stat().st_size,'sha256':${JSON.stringify(expected)},'scope':'application-owned build source only'}))`;
  const report={at:new Date().toISOString(),...JSON.parse(await runPython(client.connection,verify))};
  await fs.writeFile(path.join(appRoot,'docs/validation/deploy/source-transfer.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
}catch{console.error('Source transfer incomplete; shared services untouched; no unverified source executed.');process.exitCode=1;}
finally{client?.connection.end();}
