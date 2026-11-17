import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {appRoot,connect,runPython} from './remote_support.mjs';
const authorization=JSON.parse(await fs.readFile(path.join(appRoot,'docs/validation/deploy/authorization.json'),'utf8'));
const spec=JSON.parse(await fs.readFile(path.join(appRoot,'AppSpec.json'),'utf8'));
if(!authorization.productionDatabaseProvisioning||spec.identity.bundleId!=='thwkb.zh.huawei')throw new Error('Application database authorization/identity mismatch');
const migrations=[];
for(const file of ['001_init.sql','002_feedback.sql']){
  const bytes=await fs.readFile(path.join(appRoot,'db/migrations',file));migrations.push({version:file.slice(0,3),file,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),sqlBase64:bytes.toString('base64')});
}
const input={migrations,tables:spec.entities.map(entity=>entity.table)};
const worker=await fs.readFile(path.join(appRoot,'tools/production_pg_provision.py'),'utf8');
let client;
try{
  client=await connect();
  const script=`import json\nINPUT=json.loads(${JSON.stringify(JSON.stringify(input))})\n`+worker;
  const result={at:new Date().toISOString(),...JSON.parse(await runPython(client.connection,script))};
  await fs.writeFile(path.join(appRoot,'docs/validation/deploy/postgres-provision.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result,null,2));
}catch{
  if(client)try{
    const report={at:new Date().toISOString(),...JSON.parse(await runPython(client.connection,"import pathlib,json\np=pathlib.Path('/www/server/thwkb.zh.huawei/postgres-provision-status.json')\nprint(p.read_text() if p.exists() else json.dumps({'phase':'unknown'}))"))};
    await fs.writeFile(path.join(appRoot,'docs/validation/deploy/postgres-provision.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
  }catch{}
  console.error('Application database provisioning did not complete. Check sanitized remote status; do not assume migration success.');process.exitCode=1;
}
finally{client?.connection.end();}
