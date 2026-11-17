import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../runtimes/package.json', import.meta.url));
const { Client } = require('ssh2');
const env = Object.fromEntries(fs.readFileSync(new URL('../../../runtimes/colleague/saas26.env.deploy', import.meta.url), 'utf8')
  .split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('#') && line.includes('='))
  .map((line) => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1)]));
if (env.SAAS_REMOTE_ROOT !== '/www/wwwroot/saas26.qianqi.online' || env.SAAS_MYSQL_DATABASE !== 'saas26_qianqi') throw new Error('Wrong target environment');
const remoteCode = `
const fs=require('fs'),mysql=require('mysql2/promise');
let input='';process.stdin.on('data',d=>input+=d);process.stdin.on('end',async()=>{
let c;try{
const p=JSON.parse(input),id='zxznh.xcl.huawei';
c=await mysql.createConnection({host:'127.0.0.1',user:p.dbUser,password:p.dbPassword,database:'saas26_qianqi'});
const [rows]=await c.execute('SELECT tenant_id,slug,config,created_at,updated_at,submitted_at FROM platform_tenants WHERE tenant_id=? OR slug=?',[id,id]);
const safe=t=>({tenantId:t.tenantId,slug:t.slug,appName:t.appName||t.displayName,company:t.company,bundleId:t.bundleId,industryPack:t.industryPack,createdAt:t.createdAt,featureMenuEnabled:(t.featureModules||[]).includes('zhuxianzhenArt')});
const file='../tenants/'+id+'.json',disk=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):null;
const source=fs.readFileSync('dist/tenant/tenant-registry.service.js','utf8');
const section=(source.split('async listAppRecords()')[1]||'').split('buildAppStats(')[0];
console.log(JSON.stringify({checkedAt:new Date().toISOString(),tenantId:id,disk:disk?safe(disk):null,database:rows.map(r=>({tenantId:r.tenant_id,slug:r.slug,config:safe(typeof r.config==='string'?JSON.parse(r.config):r.config),createdAt:r.created_at,updatedAt:r.updated_at,submittedAt:r.submitted_at})),deployedListImplementation:{usesMemoryRegistry:section.includes('this.list()'),hasMysqlMetadata:section.includes('listTenantsWithMeta'),body:p.showImplementation?section:undefined}}));
}catch(e){console.error('Inspection failed: '+(e.code||'UNKNOWN'));process.exitCode=1;}finally{if(c)await c.end();}});
`;
const command = "cd /www/wwwroot/saas26.qianqi.online/server && node -e '" + remoteCode.replace(/'/g, "'\"'\"'") + "'";
const conn = new Client();
try {
  await new Promise((resolve, reject) => conn.on('ready', resolve).on('error', () => reject(new Error('SSH connection failed'))).connect({
    host: env.SAAS_SSH_HOST, port: Number(env.SAAS_SSH_PORT || 22), username: env.SAAS_SSH_USER, password: env.SAAS_SSH_PASS, readyTimeout: 30000
  }));
  const output = await new Promise((resolve, reject) => conn.exec(command, (error, stream) => {
    if (error) return reject(new Error('Remote inspection could not start'));
    let text = '';
    stream.on('data', (data) => { text += data.toString(); });
    stream.on('close', (code) => code === 0 ? resolve(text) : reject(new Error('Remote inspection failed; raw output suppressed')));
    stream.end(JSON.stringify({ dbUser: env.SAAS_MYSQL_USER, dbPassword: env.SAAS_MYSQL_PASSWORD, showImplementation: process.argv.includes('--show-implementation') }));
  }));
  const report = JSON.parse(output);
  fs.writeFileSync(new URL('../docs/validation/platform-registration-inspection.json', import.meta.url), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
} finally { conn.end(); }
