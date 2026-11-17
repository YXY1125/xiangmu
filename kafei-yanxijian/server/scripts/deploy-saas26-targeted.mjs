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

const envFile = path.join(root, 'runtimes', 'colleague', 'saas26.env.deploy');
dotenv.config({ path: envFile, override: true });

const config = {
  host: process.env.SAAS_SSH_HOST || '',
  port: Number(process.env.SAAS_SSH_PORT || 22),
  username: process.env.SAAS_SSH_USER || '',
  password: process.env.SAAS_SSH_PASS || '',
  remoteRoot: process.env.SAAS_REMOTE_ROOT || '/www/wwwroot/saas26.qianqi.online',
  pm2Name: process.env.SAAS_PM2_NAME || 'harmonyos-saas26-api',
  publicHost: process.env.SAAS_PUBLIC_HOST || 'saas26.qianqi.online',
};

const tenantId = 'kafyj.zy.huawei';
const localModule = path.join(root, 'platform', 'server', 'dist', 'modules', 'coffee-culture');
const localTenant = path.join(root, 'platform', 'tenants', `${tenantId}.json`);
const localContent = path.join(root, 'apps', tenantId, 'server', 'data', 'public-content.json');
const remoteAppModule = `${config.remoteRoot}/server/dist/app.module.js`;
const remoteModule = `${config.remoteRoot}/server/dist/modules/coffee-culture`;
const remoteTenant = `${config.remoteRoot}/tenants/${tenantId}.json`;
const remoteRuntime = `${config.remoteRoot}/data/runtime/${tenantId}`;
const remoteContent = `${remoteRuntime}/coffee-public-content.json`;

function assertConfiguration() {
  if (!fs.existsSync(envFile)) throw new Error('saas26 部署环境文件不存在');
  if (!config.host || !config.username || !config.password) throw new Error('saas26 SSH 配置不完整');
}

function connect() {
  return new Promise((resolve, reject) => {
    const client = new Client();
    client.once('ready', () => resolve(client));
    client.once('error', reject);
    client.connect({
      host: config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      readyTimeout: 20000,
    });
  });
}

function execute(client, command, allowFailure = false) {
  return new Promise((resolve, reject) => {
    client.exec(command, (error, stream) => {
      if (error) return reject(error);
      let stdout = '';
      let stderr = '';
      stream.on('data', (chunk) => { stdout += chunk.toString(); });
      stream.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
      stream.on('close', (code) => {
        if (code !== 0 && !allowFailure) return reject(new Error(`远端命令失败 (${code}): ${stderr.trim() || command}`));
        resolve({ code, stdout, stderr });
      });
    });
  });
}

function openSftp(client) {
  return new Promise((resolve, reject) => client.sftp((error, value) => error ? reject(error) : resolve(value)));
}

function readRemote(sftp, file) {
  return new Promise((resolve, reject) => {
    sftp.readFile(file, (error, data) => error ? reject(error) : resolve(data.toString('utf8')));
  });
}

function writeRemote(sftp, file, value) {
  return new Promise((resolve, reject) => {
    sftp.writeFile(file, value, { mode: 0o644 }, (error) => error ? reject(error) : resolve());
  });
}

function upload(sftp, localFile, remoteFile) {
  return new Promise((resolve, reject) => {
    sftp.fastPut(localFile, remoteFile, (error) => error ? reject(error) : resolve());
  });
}

async function remoteExists(client, file) {
  return (await execute(client, `test -f '${file}'`, true)).code === 0;
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function patchAppModule(source) {
  if (source.includes('coffee_culture_module_1.CoffeeCultureModule')) return source;
  const classMarker = source.lastIndexOf('let AppModule');
  if (classMarker < 0) throw new Error('无法在生产 app.module.js 中定位 AppModule');
  const requireLine = 'const coffee_culture_module_1 = require("./modules/coffee-culture/coffee.module");\n';
  let patched = `${source.slice(0, classMarker)}${requireLine}${source.slice(classMarker)}`;
  const matches = [...patched.matchAll(/admin_module_\d+\.AdminModule/g)];
  if (matches.length === 0) throw new Error('无法在生产 app.module.js 中定位 AdminModule');
  const last = matches[matches.length - 1];
  const insertAt = last.index;
  patched = `${patched.slice(0, insertAt)}coffee_culture_module_1.CoffeeCultureModule,\n            ${patched.slice(insertAt)}`;
  if ((patched.match(/coffee_culture_module_1\.CoffeeCultureModule/g) || []).length !== 1) {
    throw new Error('生产入口补丁校验失败');
  }
  return patched;
}

async function audit(client, sftp) {
  const appSource = await readRemote(sftp, remoteAppModule);
  const remoteStoreFile = `${remoteModule}/coffee.store.js`;
  const localStoreFile = path.join(localModule, 'coffee.store.js');
  const remoteStoreSource = await remoteExists(client, remoteStoreFile)
    ? await readRemote(sftp, remoteStoreFile)
    : '';
  const localStoreSource = fs.existsSync(localStoreFile) ? fs.readFileSync(localStoreFile) : Buffer.alloc(0);
  const pid = (await execute(client, `pm2 pid '${config.pm2Name}'`, true)).stdout.trim();
  const pm2List = await execute(client, 'pm2 jlist', true);
  let processState = null;
  try {
    const processInfo = JSON.parse(pm2List.stdout).find((item) => item.name === config.pm2Name);
    if (processInfo) {
      processState = {
        status: processInfo.pm2_env?.status || null,
        restartCount: processInfo.pm2_env?.restart_time ?? null,
        unstableRestarts: processInfo.pm2_env?.unstable_restarts ?? null,
        startedAt: processInfo.pm2_env?.pm_uptime ? new Date(processInfo.pm2_env.pm_uptime).toISOString() : null,
      };
    }
  } catch {
    processState = null;
  }
  const tenantExists = await remoteExists(client, remoteTenant);
  const contentExists = await remoteExists(client, remoteContent);
  const moduleExists = await remoteExists(client, `${remoteModule}/coffee.module.js`);
  const relevant = appSource.split(/\r?\n/).filter((line) =>
    line.includes('coffee-culture') || line.includes('CoffeeCultureModule') || line.includes('ColdJokeModule') || line.includes('AdminModule'),
  ).slice(-12);
  console.log(JSON.stringify({
    site: config.publicHost,
    pm2Name: config.pm2Name,
    pm2Pid: pid || null,
    processState,
    appModuleSha256: sha256(appSource),
    coffeeEntryRegistered: appSource.includes('coffee_culture_module_1.CoffeeCultureModule'),
    coffeeModuleFilesPresent: moduleExists,
    coffeeStoreMatchesLocalBuild: remoteStoreSource.length > 0 && localStoreSource.length > 0
      ? sha256(remoteStoreSource) === sha256(localStoreSource)
      : false,
    remoteCoffeeStoreSha256: remoteStoreSource.length > 0 ? sha256(remoteStoreSource) : null,
    localCoffeeStoreSha256: localStoreSource.length > 0 ? sha256(localStoreSource) : null,
    tenantConfigPresent: tenantExists,
    publicContentPresent: contentExists,
    relevantEntryLines: relevant,
  }, null, 2));
  if (process.argv.includes('--logs')) {
    const logs = await execute(client, `pm2 logs '${config.pm2Name}' --lines 120 --nostream`, true);
    const safeLines = `${logs.stdout}\n${logs.stderr}`
      .split(/\r?\n/)
      .filter((line) => /error|exception|coffee|started|eaddr|enoent|warn|deprecated/i.test(line))
      .map((line) => line
        .replace(/Bearer\s+[A-Za-z0-9._~-]+/gi, 'Bearer [REDACTED]')
        .replace(/(password|token|secret)(["'=:\s]+)[^\s,}"]+/gi, '$1$2[REDACTED]'))
      .slice(-80);
    console.log(JSON.stringify({ recentRelevantLogs: safeLines }, null, 2));
  }
  return { tenantExists, contentExists };
}

async function uploadModule(client, sftp) {
  if (!fs.existsSync(path.join(localModule, 'coffee.module.js'))) throw new Error('本地 coffee-culture 构建产物不存在，请先运行 npm run build');
  await execute(client, `mkdir -p '${remoteModule}' '${remoteRuntime}'`);
  for (const entry of fs.readdirSync(localModule, { withFileTypes: true })) {
    if (!entry.isFile()) continue;
    await upload(sftp, path.join(localModule, entry.name), `${remoteModule}/${entry.name}`);
  }
}

async function verifyLive() {
  const base = `https://${config.publicHost}/api/v1`;
  const options = { headers: { 'X-Tenant-Id': tenantId }, signal: AbortSignal.timeout(20000) };
  let lastError;
  for (let attempt = 1; attempt <= 8; attempt += 1) {
    try {
      const healthResponse = await fetch(`${base}/platform/health`, { signal: AbortSignal.timeout(20000) });
      const health = await healthResponse.json();
      const tenantResponse = await fetch(`${base}/platform/tenants`, { signal: AbortSignal.timeout(20000) });
      const tenantPayload = await tenantResponse.json();
      const routeResponse = await fetch(`${base}/biz/${tenantId}/knowledge?keyword=${encodeURIComponent('粉水比')}`, options);
      const routePayload = await routeResponse.json();
      const tenants = tenantPayload?.data?.items || tenantPayload?.data?.list || tenantPayload?.data || [];
      const tenantRegistered = Array.isArray(tenants) && tenants.some((item) => item.tenantId === tenantId);
      const knowledgeCount = routePayload?.data?.items?.length || 0;
      if (healthResponse.ok && tenantResponse.ok && routeResponse.ok && routePayload?.code === 0 && tenantRegistered && knowledgeCount >= 1) {
        return {
          healthStatus: healthResponse.status,
          tenantStatus: tenantResponse.status,
          routeStatus: routeResponse.status,
          tenantRegistered,
          knowledgeCount,
          platformTenantCount: health?.data?.tenantCount,
        };
      }
      lastError = new Error(`线上验证未通过: health=${healthResponse.status}, tenant=${tenantRegistered}, route=${routeResponse.status}, count=${knowledgeCount}`);
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 2500));
  }
  throw lastError || new Error('线上验证失败');
}

async function deploy(client, sftp) {
  for (const file of [localTenant, localContent]) if (!fs.existsSync(file)) throw new Error(`本地部署文件缺失: ${file}`);
  const before = await audit(client, sftp);
  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14);
  const appBackup = `${remoteAppModule}.bak-coffee-${stamp}`;
  const tenantBackup = `${remoteTenant}.bak-coffee-${stamp}`;
  const contentBackup = `${remoteContent}.bak-coffee-${stamp}`;

  await execute(client, `cp '${remoteAppModule}' '${appBackup}'`);
  if (before.tenantExists) await execute(client, `cp '${remoteTenant}' '${tenantBackup}'`);
  if (before.contentExists) await execute(client, `cp '${remoteContent}' '${contentBackup}'`);

  try {
    const source = await readRemote(sftp, remoteAppModule);
    const patched = patchAppModule(source);
    await uploadModule(client, sftp);
    await upload(sftp, localTenant, remoteTenant);
    await upload(sftp, localContent, remoteContent);
    await writeRemote(sftp, remoteAppModule, patched);
    await execute(client, `pm2 restart '${config.pm2Name}' --update-env`);
    const live = await verifyLive();
    console.log(JSON.stringify({
      deployed: true,
      backup: appBackup,
      scope: ['coffee-culture module', tenantId, 'coffee public content'],
      live,
    }, null, 2));
  } catch (error) {
    console.error(`部署验证失败，执行回滚：${error instanceof Error ? error.message : String(error)}`);
    await execute(client, `cp '${appBackup}' '${remoteAppModule}'`);
    if (before.tenantExists) await execute(client, `cp '${tenantBackup}' '${remoteTenant}'`);
    else await execute(client, `rm -f '${remoteTenant}'`);
    if (before.contentExists) await execute(client, `cp '${contentBackup}' '${remoteContent}'`);
    else await execute(client, `rm -f '${remoteContent}'`);
    await execute(client, `pm2 restart '${config.pm2Name}' --update-env`, true);
    throw error;
  }
}

async function main() {
  assertConfiguration();
  const mode = process.argv.includes('--deploy') ? 'deploy' : 'audit';
  const client = await connect();
  try {
    const sftp = await openSftp(client);
    if (mode === 'deploy') await deploy(client, sftp);
    else await audit(client, sftp);
  } finally {
    client.end();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
