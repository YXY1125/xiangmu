import fs from 'node:fs/promises';
import path from 'node:path';
import {appRoot,connect,runPython} from './remote_support.mjs';
const script=String.raw`
import os,json,hashlib,base64,re,subprocess
site='/www/wwwroot/saas26.qianqi.online'
index=open(site+'/index.html').read()
entries=re.findall(r'<script[^>]+src="([^"]+)"',index)
files=[]
for name in ['server/dist/modules/admin/admin-auth.service.js']+[x.lstrip('/') for x in entries if x.startswith('/assets/') and x.endswith('.js')]:
 p=site+'/'+name;b=open(p,'rb').read();files.append({'name':name,'sha256':hashlib.sha256(b).hexdigest(),'base64':base64.b64encode(b).decode()})
pm=next(p for p in json.loads(subprocess.check_output(['pm2','jlist'],stderr=subprocess.DEVNULL)) if p['name']=='harmonyos-saas26-api')['pm2_env']
print(json.dumps({'files':files,'mysqlConfigured':bool(pm.get('MYSQL_PASSWORD')),'mysqlEnabled':pm.get('MYSQL_ENABLED'),'entryScripts':entries,'sourceAdminAvailable':os.path.isdir(site+'/admin/src'),'adminCredentialExists':os.path.isfile('/www/server/thwkb.zh.huawei/secrets/admin.json')}))
`;
let client;
try{client=await connect();const result=JSON.parse(await runPython(client.connection,script));for(const file of result.files){const p=path.join(appRoot,'.runtime/deploy/admin-baseline',file.name);await fs.mkdir(path.dirname(p),{recursive:true});await fs.writeFile(p,Buffer.from(file.base64,'base64'));delete file.base64;}const report={at:new Date().toISOString(),...result,mutations:false};await fs.writeFile(path.join(appRoot,'docs/validation/deploy/admin-baseline.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));}catch{console.error('Admin baseline audit failed; sensitive diagnostics suppressed.');process.exitCode=1;}finally{client?.connection.end();}
