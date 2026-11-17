import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../runtimes/package.json', import.meta.url));
const { Client } = require('ssh2');
const env = Object.fromEntries(fs.readFileSync(new URL('../../../runtimes/colleague/saas26.env.deploy', import.meta.url), 'utf8')
  .split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('#') && line.includes('='))
  .map((line) => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1)]));
if (env.SAAS_REMOTE_ROOT !== '/www/wwwroot/saas26.qianqi.online' || env.SAAS_MYSQL_DATABASE !== 'saas26_qianqi') throw new Error('Target environment mismatch');
const remoteCode = `
const fs=require('fs'),mysql=require('mysql2/promise');
let input='';process.stdin.on('data',d=>input+=d);process.stdin.on('end',async()=>{
let c;try{
const p=JSON.parse(input),id='zxznh.xcl.huawei',root='/www/wwwroot/saas26.qianqi.online';
const cfg=JSON.parse(fs.readFileSync(root+'/tenants/'+id+'.json','utf8'));
if(cfg.tenantId!==id||cfg.slug!==id||cfg.bundleId!==id||(cfg.appName||cfg.displayName)!=='朱仙镇年画'||cfg.company!=='黑龙江省众富信息科技有限公司')throw Object.assign(Error(),{code:'TENANT_IDENTITY_MISMATCH'});
if(!cfg.featureModules.includes('zhuxianzhenArt'))throw Object.assign(Error(),{code:'TENANT_FEATURE_MISSING'});
c=await mysql.createConnection({host:'127.0.0.1',user:p.dbUser,password:p.dbPassword,database:'saas26_qianqi'});
await c.beginTransaction();
const [before]=await c.execute('SELECT tenant_id,slug,config,created_at,updated_at,submitted_at FROM platform_tenants WHERE tenant_id=? OR slug=? FOR UPDATE',[id,id]);
let action='already-registered-preserved',backup=null;
if(before.length===0){
backup=root+'/.backup-zxznh-platform-registration-'+new Date().toISOString().replace(/[:.]/g,'-')+'.json';
fs.writeFileSync(backup,JSON.stringify({tenantId:id,table:'platform_tenants',before:null,action:'insert-only',createdAt:new Date().toISOString(),rollback:'Transaction rolls back on verification failure; any post-commit removal requires explicit approval.'},null,2),{mode:0o600,flag:'wx'});
const created=new Date(cfg.createdAt);if(Number.isNaN(created.getTime()))throw Object.assign(Error(),{code:'REGISTRATION_DATE_INVALID'});
await c.execute('INSERT INTO platform_tenants (tenant_id,slug,config,created_at,submitted_at) VALUES (?,?,?,?,NULL)',[id,id,JSON.stringify(cfg),created]);
action='inserted-missing-platform-registration';
}else{
if(before.length!==1||before[0].tenant_id!==id||before[0].slug!==id)throw Object.assign(Error(),{code:'TENANT_CONFLICT'});
const old=typeof before[0].config==='string'?JSON.parse(before[0].config):before[0].config;
if(old.bundleId!==id||old.company!==cfg.company)throw Object.assign(Error(),{code:'EXISTING_IDENTITY_CONFLICT'});
}
const [after]=await c.execute('SELECT tenant_id,slug,config,created_at,submitted_at FROM platform_tenants WHERE tenant_id=?',[id]);
if(after.length!==1)throw Object.assign(Error(),{code:'REGISTRATION_VERIFICATION_FAILED'});
const result=typeof after[0].config==='string'?JSON.parse(after[0].config):after[0].config;
if(result.bundleId!==id||result.company!==cfg.company||(result.appName||result.displayName)!=='朱仙镇年画')throw Object.assign(Error(),{code:'REGISTRATION_IDENTITY_INVALID'});
await c.commit();
console.log(JSON.stringify({checkedAt:new Date().toISOString(),status:'pass',action,tenantId:id,appName:result.appName||result.displayName,company:result.company,bundleId:result.bundleId,createdAt:after[0].created_at,submittedAt:after[0].submitted_at,backup,scope:'one platform_tenants row only; no schema changes, no credentials changed, no user records touched, no service restart'}));
}catch(e){if(c)await c.rollback();console.error('Target registration failed: '+(e.code||'UNKNOWN'));process.exitCode=1;}finally{if(c)await c.end();}});
`;
const command = "cd /www/wwwroot/saas26.qianqi.online/server && node -e '" + remoteCode.replace(/'/g, "'\"'\"'") + "'";
const conn = new Client();
try {
  await new Promise((resolve, reject) => conn.on('ready', resolve).on('error', () => reject(new Error('SSH connection failed'))).connect({
    host: env.SAAS_SSH_HOST, port: Number(env.SAAS_SSH_PORT || 22), username: env.SAAS_SSH_USER, password: env.SAAS_SSH_PASS, readyTimeout: 30000
  }));
  const output = await new Promise((resolve, reject) => conn.exec(command, (error, stream) => {
    if (error) return reject(new Error('Target registration could not start'));
    let result = '';
    stream.on('data', (data) => { result += data.toString(); });
    stream.on('close', (code) => code === 0 ? resolve(result) : reject(new Error('Target registration failed; raw output suppressed')));
    stream.end(JSON.stringify({ dbUser: env.SAAS_MYSQL_USER, dbPassword: env.SAAS_MYSQL_PASSWORD }));
  }));
  const report = JSON.parse(output);
  fs.writeFileSync(new URL('../docs/validation/platform-app-registration.json', import.meta.url), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report, null, 2));
} finally { conn.end(); }
