import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {appRoot,connect,runPython} from './remote_support.mjs';
import {seedReady} from '../server/src/seed-policy.mjs';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=async p=>fs.readFile(path.join(appRoot,p));
const seedBytes=await read('db/seeds/001_content.json'),seed=JSON.parse(seedBytes),approvalBytes=await read('docs/validation/content-release-approval.json'),approval=JSON.parse(approvalBytes);
if(!seedReady(seed)||approval.seedSha256!==hash(seedBytes)||approval.assets.length!==91)throw Error('Explicit verified content approval is required');
const initial=JSON.parse(await read('.runtime/deploy/release-manifest.json'));
const manifest={release:'content-'+new Date().toISOString().replace(/[-:.]/g,''),previousRelease:initial.release,beforeSeedSha256:initial.files.find(f=>f.name==='db/seeds/001_content.json').sha256,documents:{},assets:[]};
const documents={'content.json':seedBytes,'seed.sql':await read('db/seeds/001_seed.sql'),'approval.json':approvalBytes,'authorization.md':await read(approval.authorizationRecord)};
for(const [name,bytes] of Object.entries(documents))manifest.documents[name]=hash(bytes);
for(const asset of approval.assets){const bytes=await read(asset.webp);if(hash(bytes)!==asset.webpSha256)throw Error('Approved asset changed');manifest.assets.push({key:asset.key,sha256:asset.webpSha256,file:asset.webp});}
const program=(await read('tools/production_content_deploy.py')).toString();
const payload=Buffer.from(JSON.stringify(manifest)).toString('base64');
const invoke=operation=>program+`\nimport base64\nprint(json.dumps(${operation}(json.loads(base64.b64decode('${payload}')))))`;
let client;
try {
 client=await connect();const staging=JSON.parse(await runPython(client.connection,invoke('stage')));
 if(!staging.staged)throw Error('Content release staging failed');
 const sftp=await new Promise((resolve,reject)=>client.connection.sftp((e,s)=>e?reject(e):resolve(s)));
 const put=(bytes,name)=>new Promise((resolve,reject)=>{const stream=sftp.createWriteStream(staging.directory+'/upload/'+name,{mode:0o600});stream.on('error',reject).on('close',resolve);stream.end(bytes);});
 for(const [name,bytes] of Object.entries(documents))await put(bytes,name);
 for(let i=0;i<manifest.assets.length;i+=4){await Promise.all(manifest.assets.slice(i,i+4).map(async a=>put(await read(a.file),a.key+'.webp')));console.log(JSON.stringify({event:'verified-assets-staged',completed:Math.min(i+4,91),total:91}));}
 const result=JSON.parse(await runPython(client.connection,invoke('promote'))),report={at:new Date().toISOString(),...result};
 await fs.appendFile(path.join(appRoot,'docs/validation/deploy/content-deploy-attempts.jsonl'),JSON.stringify(report)+'\n');
 await fs.writeFile(path.join(appRoot,'docs/validation/deploy/content-deploy.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));if(!report.passed)process.exitCode=1;
}catch{console.error('Content release incomplete; credentials and raw diagnostics suppressed. No shared schema changes requested.');process.exitCode=1;}
finally{client?.connection.end();}
