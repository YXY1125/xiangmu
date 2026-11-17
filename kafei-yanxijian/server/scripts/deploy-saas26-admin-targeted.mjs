#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, '../../../../');
const runtimeRequire = createRequire(path.join(root, 'runtimes', 'deploy-platform-saas.mjs'));
const { Client } = runtimeRequire('ssh2');
const dotenv = runtimeRequire('dotenv');
dotenv.config({ path: path.join(root, 'runtimes', 'colleague', 'saas26.env.deploy'), override: true });

const config = {
  host: process.env.SAAS_SSH_HOST || '', port: Number(process.env.SAAS_SSH_PORT || 22),
  username: process.env.SAAS_SSH_USER || '', password: process.env.SAAS_SSH_PASS || '',
  remoteRoot: process.env.SAAS_REMOTE_ROOT || '/www/wwwroot/saas26.qianqi.online',
  publicHost: process.env.SAAS_PUBLIC_HOST || 'saas26.qianqi.online',
};

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : '';
}
function sha256(value) { return crypto.createHash('sha256').update(value).digest('hex'); }
function connect() { return new Promise((resolve, reject) => { const client = new Client(); client.once('ready', () => resolve(client)); client.once('error', reject); client.connect({ host: config.host, port: config.port, username: config.username, password: config.password, readyTimeout: 20000 }); }); }
function execute(client, command, allowFailure = false) { return new Promise((resolve, reject) => client.exec(command, (error, stream) => { if (error) return reject(error); let stdout = '', stderr = ''; stream.on('data', (chunk) => { stdout += chunk.toString(); }); stream.stderr.on('data', (chunk) => { stderr += chunk.toString(); }); stream.on('close', (code) => code !== 0 && !allowFailure ? reject(new Error(stderr.trim() || `远端命令失败: ${command}`)) : resolve({ code, stdout, stderr })); })); }
function openSftp(client) { return new Promise((resolve, reject) => client.sftp((error, value) => error ? reject(error) : resolve(value))); }
function readRemote(sftp, file) { return new Promise((resolve, reject) => sftp.readFile(file, (error, data) => error ? reject(error) : resolve(data.toString('utf8')))); }
function upload(sftp, local, remote) { return new Promise((resolve, reject) => sftp.fastPut(local, remote, (error) => error ? reject(error) : resolve())); }

function filesUnder(directory) {
  const output = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) output.push(...filesUnder(full));
    else if (entry.isFile()) output.push(full);
  }
  return output;
}

async function audit(client, sftp) {
  const remoteIndex = await readRemote(sftp, `${config.remoteRoot}/index.html`);
  const script = remoteIndex.match(/src="([^"]+\.js)"/)?.[1] || '';
  console.log(JSON.stringify({
    site: config.publicHost,
    remoteIndexSha256: sha256(remoteIndex),
    activeScript: script || null,
    coffeeAdminReferenced: script ? (await readRemote(sftp, `${config.remoteRoot}${script}`)).includes('CoffeeAdminView') : false,
  }, null, 2));
}

async function deploy(client, sftp, dist) {
  const resolved = path.resolve(dist);
  const localIndex = path.join(resolved, 'index.html');
  if (!resolved.startsWith(root + path.sep) || !fs.existsSync(localIndex)) throw new Error('管理端 dist 必须位于当前工作区且包含 index.html');
  const indexText = fs.readFileSync(localIndex, 'utf8');
  if (!indexText.includes('/assets/') || !filesUnder(resolved).some((file) => path.basename(file).startsWith('CoffeeAdminView-'))) {
    throw new Error('构建产物未包含咖啡管理页面');
  }
  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14);
  const backup = `${config.remoteRoot}/index.html.bak-coffee-admin-${stamp}`;
  const stagedIndex = `${config.remoteRoot}/index.html.new-coffee-admin-${stamp}`;
  await execute(client, `cp '${config.remoteRoot}/index.html' '${backup}'`);
  try {
    const files = filesUnder(resolved).filter((file) => path.resolve(file) !== path.resolve(localIndex));
    const directories = new Set(files.map((file) => path.posix.dirname(path.relative(resolved, file).replace(/\\/g, '/'))).filter((value) => value !== '.'));
    for (const directory of directories) await execute(client, `mkdir -p '${config.remoteRoot}/${directory}'`);
    for (const file of files) {
      const relative = path.relative(resolved, file).replace(/\\/g, '/');
      await upload(sftp, file, `${config.remoteRoot}/${relative}`);
    }
    await upload(sftp, localIndex, stagedIndex);
    await execute(client, `mv '${stagedIndex}' '${config.remoteRoot}/index.html'`);

    const response = await fetch(`https://${config.publicHost}/?coffee_admin_deploy=${stamp}`, { headers: { 'Cache-Control': 'no-cache' }, signal: AbortSignal.timeout(20000) });
    const liveIndex = await response.text();
    const script = liveIndex.match(/src="([^"]+\.js)"/)?.[1] || '';
    const scriptResponse = script ? await fetch(`https://${config.publicHost}${script}`, { headers: { 'Cache-Control': 'no-cache' }, signal: AbortSignal.timeout(20000) }) : null;
    const scriptBody = scriptResponse ? await scriptResponse.text() : '';
    if (!response.ok || sha256(liveIndex) !== sha256(indexText) || !scriptResponse?.ok || !scriptBody.includes('CoffeeAdminView')) {
      throw new Error('线上管理端资源校验失败');
    }
    console.log(JSON.stringify({ deployed: true, backup, indexSha256: sha256(indexText), activeScript: script, coffeeAdminReferenced: true, deletedRemoteFiles: 0 }, null, 2));
  } catch (error) {
    await execute(client, `cp '${backup}' '${config.remoteRoot}/index.html'`, true);
    throw error;
  }
}

async function main() {
  if (!config.host || !config.username || !config.password) throw new Error('saas26 SSH 配置不完整');
  const client = await connect();
  try {
    const sftp = await openSftp(client);
    if (process.argv.includes('--deploy')) await deploy(client, sftp, argument('--dist'));
    else await audit(client, sftp);
  } finally { client.end(); }
}
main().catch((error) => { console.error(error instanceof Error ? error.message : String(error)); process.exitCode = 1; });
