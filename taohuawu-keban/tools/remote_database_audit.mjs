import fs from 'node:fs/promises';
import path from 'node:path';
import {appRoot,connect,runPython} from './remote_support.mjs';
const script=String.raw`
import os,json,shutil,glob,subprocess,platform
executables={k:shutil.which(k) for k in ['gcc','cc','make','perl','bison','flex','runuser','useradd','curl','tar','nice','ionice','podman','node','pm2','pg_ctl','postgres','psql']}
postgres=[]
for pid in os.listdir('/proc'):
  if not pid.isdigit():continue
  try:
    exe=os.readlink('/proc/'+pid+'/exe')
    if os.path.basename(exe)=='postgres':postgres.append({'pid':int(pid),'executable':exe})
  except OSError:pass
users={}
import pwd
for name in ['thwkbpg','www','postgres']:
  try:
    p=pwd.getpwnam(name);users[name]={'uid':p.pw_uid,'gid':p.pw_gid}
  except KeyError:users[name]=None
server='/www/wwwroot/saas26.qianqi.online/server'
package=json.load(open(server+'/package.json'))
print(json.dumps({'atScope':'read-only','executables':executables,'postgresProcesses':postgres,'dedicatedUser':users.get('thwkbpg'),'hostMemoryAvailableBytes':os.sysconf('SC_PAGE_SIZE')*os.sysconf('SC_AVPHYS_PAGES'),'nodeDependencies':{k:(package.get('dependencies',{}).get(k) or package.get('devDependencies',{}).get(k)) for k in ['pg','typescript','@nestjs/common']},'protectedAppDirectoryExists':os.path.exists('/www/wwwroot/saas26.qianqi.online/.private/thwkb.zh.huawei'),'cpuCount':os.cpu_count()}))
`;
let client;
try{client=await connect();const report={at:new Date().toISOString(),...JSON.parse(await runPython(client.connection,script))};await fs.writeFile(path.join(appRoot,'docs/validation/deploy/database-audit.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));}
catch{console.error('Database environment audit failed; no remote writes performed.');process.exitCode=1;}finally{client?.connection.end();}
