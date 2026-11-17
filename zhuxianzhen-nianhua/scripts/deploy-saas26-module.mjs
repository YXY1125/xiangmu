import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../runtimes/package.json', import.meta.url));
const { Client } = require('ssh2');
const env = Object.fromEntries(fs.readFileSync(new URL('../../../runtimes/colleague/saas26.env.deploy', import.meta.url), 'utf8')
  .split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('#') && line.includes('='))
  .map((line) => [line.slice(0, line.indexOf('=')).trim(), line.slice(line.indexOf('=') + 1).trim()]));
if (env.SAAS_REMOTE_ROOT !== '/www/wwwroot/saas26.qianqi.online') throw new Error('Wrong deployment target');
const root = env.SAAS_REMOTE_ROOT;
const remote = `${root}/server/dist/modules/zhuxianzhen-art`;
const backup = `${root}/.backup-zxznh-module-${new Date().toISOString().replace(/[:.]/g, '-')}`;
const names = ['zhuxianzhen-art.controller.js', 'zhuxianzhen-art-admin.controller.js', 'zhuxianzhen-art.store.js', 'zhuxianzhen-art.module.js'];
const exec = (conn, command) => new Promise((resolve, reject) => conn.exec(command, (error, stream) => {
  if (error) return reject(error);
  let output = '';
  stream.on('data', (data) => { output += data.toString(); });
  stream.on('close', (code) => code === 0 ? resolve(output) : reject(new Error('Remote command failed; output suppressed')));
}));
const conn = new Client();
try {
  await new Promise((resolve, reject) => conn.on('ready', resolve).on('error', () => reject(new Error('SSH connection failed'))).connect({
    host: env.SAAS_SSH_HOST, port: Number(env.SAAS_SSH_PORT || 22), username: env.SAAS_SSH_USER, password: env.SAAS_SSH_PASS, readyTimeout: 30000
  }));
  await exec(conn, `test -d '${remote}' && mkdir '${backup}' && cp -a '${remote}' '${backup}/zhuxianzhen-art'`);
  console.log(`Rollback backup: ${backup}/zhuxianzhen-art`);
  const sftp = await new Promise((resolve, reject) => conn.sftp((error, value) => error ? reject(error) : resolve(value)));
  for (const name of names) {
    const local = new URL(`../../../platform/server/dist/modules/zhuxianzhen-art/${name}`, import.meta.url);
    await new Promise((resolve, reject) => sftp.fastPut(fs.realpathSync(local), `${remote}/${name}`, (error) => error ? reject(error) : resolve()));
    const hash = createHash('sha256').update(fs.readFileSync(local)).digest('hex');
    const verified = await exec(conn, `sha256sum '${remote}/${name}'`);
    if (verified.split(/\s/)[0] !== hash) throw new Error('Module hash mismatch');
    console.log(`Verified target module: ${name}`);
  }
  await exec(conn, 'pm2 restart harmonyos-saas26-api --silent');
  console.log('Target module deployed; shared files, other modules, tenant records and schemas untouched');
} finally {
  conn.end();
}
