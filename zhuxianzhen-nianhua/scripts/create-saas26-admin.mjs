import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../runtimes/package.json', import.meta.url));
const { Client } = require('ssh2');

const env = Object.fromEntries(fs.readFileSync(new URL('../../../runtimes/colleague/saas26.env.deploy', import.meta.url), 'utf8')
  .split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('#') && line.includes('='))
  .map((line) => [line.slice(0, line.indexOf('=')).trim(), line.slice(line.indexOf('=') + 1).trim()]));
const password = process.env.SAAS_TENANT_ADMIN_PASSWORD;
if (!password || password.length < 12) throw new Error('Required secure admin password is unavailable');
if (env.SAAS_REMOTE_ROOT !== '/www/wwwroot/saas26.qianqi.online' || env.SAAS_MYSQL_DATABASE !== 'saas26_qianqi') throw new Error('Target environment mismatch');

const remoteCode = `
const mysql=require('mysql2/promise');
let input='';process.stdin.on('data',d=>input+=d);process.stdin.on('end',async()=>{
let c;
try {
const p=JSON.parse(input),tid='zxznh.xcl.huawei',u='admin@'+tid+'.local';
c=await mysql.createConnection({host:'127.0.0.1',user:p.dbUser,password:p.dbPassword,database:'saas26_qianqi'});
const [rows]=await c.execute('SELECT password FROM admin_users WHERE username=? AND tenant_id=?',[u,tid]);
if(rows.length){if(rows[0].password!==p.password)throw Object.assign(Error(),{code:'EXISTING_CREDENTIAL_MISMATCH'});console.log('Target tenant admin already exists; unchanged');}
else {await c.execute('INSERT INTO admin_users (username,password,role,tenant_id) VALUES (?,?,?,?)',[u,p.password,'tenant_admin',tid]);console.log('Target tenant admin created in existing admin_users table');}
}catch(e){console.error('Target admin creation failed: '+(e.code||'UNKNOWN'));process.exitCode=1;}finally{if(c)await c.end();}
});`;
const command = `cd /www/wwwroot/saas26.qianqi.online/server && node -e '${remoteCode.replace(/'/g, `'"'"'`)}' && pm2 restart harmonyos-saas26-api --silent`;
const conn = new Client();
await new Promise((resolve, reject) => {
  conn.on('ready', () => conn.exec(command, (error, stream) => {
    if (error) return reject(error);
    stream.on('data', (data) => process.stdout.write(data));
    stream.stderr.on('data', (data) => process.stderr.write(data));
    stream.on('close', (code) => { conn.end(); code === 0 ? resolve() : reject(new Error('Target admin bootstrap failed')); });
    stream.end(JSON.stringify({ password, dbUser: env.SAAS_MYSQL_USER, dbPassword: env.SAAS_MYSQL_PASSWORD }));
  })).on('error', () => reject(new Error('SSH connection failed'))).connect({
    host: env.SAAS_SSH_HOST, port: Number(env.SAAS_SSH_PORT || 22), username: env.SAAS_SSH_USER,
    password: env.SAAS_SSH_PASS, readyTimeout: 30000
  });
}).finally(() => conn.end());
