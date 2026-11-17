import fs from 'node:fs/promises';
import path from 'node:path';
import {appRoot,connect,runPython} from './remote_support.mjs';
const spec=JSON.parse(await fs.readFile(path.join(appRoot,'AppSpec.json'),'utf8'));
const worker=await fs.readFile(path.join(appRoot,'tools/production_pg_verify.py'),'utf8');let client;
try{
  client=await connect();
  const script=`import json\nINPUT=json.loads(${JSON.stringify(JSON.stringify({tables:spec.entities.map(e=>e.table)}))})\n`+worker;
  const result={...JSON.parse(await runPython(client.connection,script)),at:new Date().toISOString()};
  await fs.writeFile(path.join(appRoot,'docs/validation/deploy/postgres-verification.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
}catch{
  if(client)try{const result={...JSON.parse(await runPython(client.connection,"import pathlib\nprint(pathlib.Path('/www/server/thwkb.zh.huawei/postgres-verification-status.json').read_text())")),at:new Date().toISOString()};await fs.writeFile(path.join(appRoot,'docs/validation/deploy/postgres-verification.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));}catch{}
  console.error('Production application database verification incomplete; no release acceptance claimed.');process.exitCode=1;
}finally{client?.connection.end();}
