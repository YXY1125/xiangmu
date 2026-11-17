import fs from 'node:fs/promises';
import path from 'node:path';
import {appRoot,connect,runPython} from './remote_support.mjs';
const manifest=JSON.parse(await fs.readFile(path.join(appRoot,'.runtime/deploy/release-manifest.json'),'utf8'));
const program=await fs.readFile(path.join(appRoot,'tools/production_api_deploy.py'),'utf8');
let client;
try {
 client=await connect();
 const encoded=Buffer.from(JSON.stringify(manifest)).toString('base64');
 const result=JSON.parse(await runPython(client.connection,program+`\nprint(json.dumps(deploy(json.loads(base64.b64decode('${encoded}')))))`));
 const report={at:new Date().toISOString(),...result};
 await fs.appendFile(path.join(appRoot,'docs/validation/deploy/api-deploy-attempts.jsonl'),JSON.stringify(report)+'\n');
 await fs.writeFile(path.join(appRoot,'docs/validation/deploy/api-deploy.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));if(!result.passed)process.exitCode=1;
} catch {console.error('API deployment command failed; inspect sanitized application deployment status. Credentials suppressed.');process.exitCode=1;}finally {client?.connection.end();}
