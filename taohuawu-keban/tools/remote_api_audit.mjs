import fs from 'node:fs/promises';
import path from 'node:path';
import {appRoot,connect,runPython} from './remote_support.mjs';
const script=String.raw`
import os,json,hashlib,base64,subprocess
root='/www/wwwroot/saas26.qianqi.online'
names=['app.module.js','tenant/tenant.interceptor.js','modules/privacy/privacy.module.js','modules/privacy/privacy.controller.js','modules/auth/auth.service.js']
files=[]
for name in names:
 p=os.path.join(root,'server/dist',name);b=open(p,'rb').read()
 files.append({'name':name,'sha256':hashlib.sha256(b).hexdigest(),'base64':base64.b64encode(b).decode()})
checks={}
for name,methods in {'modules/auth/auth.service.js':['resolveAppSession','findAppUserIdByUsername','removeAppUser','register','login'], 'modules/admin/admin-auth.service.js':['getSession'], 'modules/auth/user-activity.service.js':['purgeUser']}.items():
 text=open(os.path.join(root,'server/dist',name)).read()
 checks[name]={method:method+'(' in text for method in methods}
script="const p=require('./package.json');console.log(JSON.stringify({pg:!!require.resolve('pg'),nest:!!require.resolve('@nestjs/common'),node:process.version}))"
deps=json.loads(subprocess.check_output(['node','-e',script],cwd=root+'/server',stderr=subprocess.DEVNULL,timeout=10))
registry=open(root+'/server/dist/tenant/tenant-registry.service.js').read()
print(json.dumps({'files':files,'interfaces':checks,'dependencies':deps,'diskTenantsMergedAfterMysql':'this.loadFromJsonFiles();' in registry[registry.find('async hydrateFromMysql'):], 'tenantExists':os.path.isfile(root+'/tenants/thwkb.zh.huawei.json')}))
`;
let client;
try {
 client=await connect();const result=JSON.parse(await runPython(client.connection,script));
 const directory=path.join(appRoot,'.runtime/deploy/baseline');await fs.mkdir(directory,{recursive:true});
 for(const file of result.files){const target=path.join(directory,file.name);await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,Buffer.from(file.base64,'base64'));delete file.base64;}
 const report={at:new Date().toISOString(),...result,mutations:false};
 await fs.writeFile(path.join(appRoot,'docs/validation/deploy/api-baseline.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));
} catch {console.error('API baseline audit failed; raw diagnostics suppressed.');process.exitCode=1;} finally {client?.connection.end();}
