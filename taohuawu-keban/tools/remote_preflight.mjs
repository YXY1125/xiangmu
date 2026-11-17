import fs from 'node:fs/promises';
import path from 'node:path';
import {appRoot,connect,runPython} from './remote_support.mjs';
const script=String.raw`
import os,json,shutil,subprocess,glob,hashlib,platform,socket
root='/www/wwwroot/saas26.qianqi.online'
def fingerprint(file):
  return hashlib.sha256(open(file,'rb').read()).hexdigest() if os.path.isfile(file) else None
def available(command):
  try: return subprocess.run(command,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=8).returncode==0
  except Exception: return False
pm2=[]
try:
  for p in json.loads(subprocess.check_output(['pm2','jlist'],stderr=subprocess.DEVNULL,timeout=10)):
    if p.get('name')=='harmonyos-saas26-api':
      e=p.get('pm2_env',{})
      pm2.append({k:e.get(k) for k in ['status','pm_cwd','pm_exec_path','node_version']})
      pm2[-1]['appDatabaseConfigured']=bool(e.get('THWKB_DATABASE_URL'))
except Exception: pass
pg=sorted(set(glob.glob('/www/server/pgsql*/bin/psql')+glob.glob('/usr/lib/postgresql/*/bin/psql')+glob.glob('/usr/pgsql*/bin/psql')))
if shutil.which('psql'):pg.append(shutil.which('psql'))
sock=socket.socket();sock.settimeout(2)
try: sock.connect(('127.0.0.1',5432));listening=True
except Exception: listening=False
finally: sock.close()
files={}
for relative in ['server/dist/app.module.js','server/dist/modules/auth/auth.service.js','server/dist/tenant/tenant.interceptor.js','server/dist/modules/privacy/privacy.controller.js','server/dist/modules/thwkb/thwkb.module.js','server/package.json','platform/server/dist/app.module.js','platform/tenants/thwkb.zh.huawei.json','tenants/thwkb.zh.huawei.json']:
  files[relative]=fingerprint(os.path.join(root,relative))
result={'target':'saas26','root':root,'architecture':platform.machine(),'libc':platform.libc_ver(),'topLevelNames':sorted(os.listdir(root)) if os.path.isdir(root) else [],'pm2':pm2,'postgresClients':pg,'postgresPort5432Listening':listening,'dockerAvailable':available(['docker','version','--format','{{.Server.Version}}']),'files':files,'diskFreeBytes':shutil.disk_usage(root).free,'mutations':False}
print(json.dumps(result))
`;
let client;
try{
  client=await connect();const report={at:new Date().toISOString(),...(JSON.parse(await runPython(client.connection,script))),sshHostFingerprint:client.hostFingerprint};
  await fs.mkdir(path.join(appRoot,'docs/validation/deploy'),{recursive:true});
  await fs.writeFile(path.join(appRoot,'docs/validation/deploy/remote-preflight.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}catch{console.error('Read-only remote preflight failed; no remote writes performed; credentials and raw diagnostics suppressed.');process.exitCode=1;}
finally{client?.connection.end();}
