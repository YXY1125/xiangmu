import fs from 'node:fs/promises';
import path from 'node:path';
import {appRoot,connect,runPython} from './remote_support.mjs';
const script=String.raw`
import os,json,subprocess
site='/www/wwwroot/saas26.qianqi.online'
program="""(async()=>{const fs=require('fs');const {Pool}=require('pg');const c=JSON.parse(fs.readFileSync('/www/server/thwkb.zh.huawei/secrets/database.json'));const p=new Pool({...c,max:1,connectionTimeoutMillis:5000});const spec=JSON.parse(fs.readFileSync(process.argv[1]+'/AppSpec.json'));let counts={};try{for(const e of spec.entities){if(!/^thwkb_[a-z_]+$/.test(e.table))throw Error();const r=await p.query('SELECT count(*)::int n FROM "'+e.table+'" WHERE "tenantId"=$1 AND "appId"=$1',['thwkb.zh.huawei']);counts[e.table]=r.rows[0].n;}const own=file=>JSON.parse(fs.readFileSync('../data/'+file)).filter(r=>r.tenantId==='thwkb.zh.huawei').length;console.log(JSON.stringify({recordCounts:counts,registeredUsers:own('registered-users.json'),appSessions:own('app-sessions.json')}));}finally{await p.end()}})().catch(()=>process.exit(1));"""
api=next(p for p in json.loads(subprocess.check_output(['pm2','jlist'],stderr=subprocess.DEVNULL)) if p['name']=='harmonyos-saas26-api')
root=api['pm2_env'].get('THWKB_APP_ROOT');assert root and root.startswith('/www/server/thwkb.zh.huawei/releases/') and '..' not in root.split('/')
r=json.loads(subprocess.check_output(['node','-e',program,root],cwd=site+'/server',stderr=subprocess.DEVNULL,timeout=20))
r['runtimeOnline']=api['pm2_env']['status']=='online';r['credentialsExported']=False;r['mutations']=False
print(json.dumps(r))
`;
let client;
try{
 client=await connect();const report={at:new Date().toISOString(),...JSON.parse(await runPython(client.connection,script))};
 const seed=JSON.parse(await fs.readFile(path.join(appRoot,'db/seeds/001_content.json'),'utf8')),spec=JSON.parse(await fs.readFile(path.join(appRoot,'AppSpec.json'),'utf8'));
 report.expectedCounts=Object.fromEntries(spec.entities.map(e=>[e.table,seed.entities[e.name].length]));
 report.testCleanupPassed=Object.entries(report.expectedCounts).every(([table,count])=>report.recordCounts[table]===count)&&report.registeredUsers===0&&report.appSessions===0;
 await fs.writeFile(path.join(appRoot,'docs/validation/deploy/api-cleanup-audit.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));if(!report.testCleanupPassed)process.exitCode=2;
}catch{console.error('Read-only cleanup audit unavailable; sensitive diagnostics suppressed.');process.exitCode=1;}finally{client?.connection.end();}
