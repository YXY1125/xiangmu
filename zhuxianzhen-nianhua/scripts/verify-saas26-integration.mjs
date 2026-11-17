import assert from 'node:assert/strict';
import fs from 'node:fs';

const origin = 'https://saas26.qianqi.online';
const base = origin + '/api/v1';
const tenantId = 'zxznh.xcl.huawei';
const username = 'admin@' + tenantId + '.local';
const appRoot = new URL('../', import.meta.url);
const spec = JSON.parse(fs.readFileSync(new URL('AppSpec.json', appRoot), 'utf8'));
assert.equal(spec.identity.bundleId, tenantId);
assert.equal(spec.identity.appName, '朱仙镇年画');
assert.equal(spec.identity.company, '黑龙江省众富信息科技有限公司');
assert.equal(JSON.parse(fs.readFileSync(new URL('GATE_A_VALIDATION.json', appRoot), 'utf8')).status, 'pass');
const password = process.env.SAAS_TENANT_ADMIN_PASSWORD;
assert.ok(password, 'Secure admin password unavailable');
async function api(path, token = '', body, method = 'GET', includeTenant = true) {
  const response = await fetch(base + path, {
    method, headers: { 'Content-Type': 'application/json', ...(includeTenant ? { 'X-Tenant-Id': tenantId } : {}), ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(20000)
  });
  const result = await response.json();
  assert.ok(response.ok && result.code === 0, path + ': HTTP or business request failed');
  return result.data;
}
const checks = [];
await api('/platform/health'); checks.push('live platform health');
const page = await fetch(origin + '/login', { signal: AbortSignal.timeout(20000) });
assert.equal(page.status, 200);
const html = await page.text();
const assets = [...html.matchAll(/src="([^"]+\.js)"/g)].map((match) => match[1]);
assert.ok(assets.length > 0, 'Admin entry JavaScript missing');
let chunk = '';
for (const entry of assets) {
  const response = await fetch(new URL(entry, origin), { signal: AbortSignal.timeout(20000) });
  assert.equal(response.status, 200);
  const script = await response.text();
  if (script.includes('/zxznh-art')) {
    const match = script.match(/assets\/ZhuxianzhenArtView-[A-Za-z0-9_-]+\.js/);
    assert.ok(match, 'Tenant operator view chunk missing');
    chunk = match[0];
  }
}
assert.ok(chunk, 'Deployed tenant navigation entry missing');
const view = await fetch(new URL(chunk, origin), { signal: AbortSignal.timeout(20000) });
assert.equal(view.status, 200);
assert.ok((await view.text()).includes('/admin/zhuxianzhen-art/'), 'Operator view not connected to target API');
const directRoute = await fetch(origin + '/zxznh-art', { signal: AbortSignal.timeout(20000) });
assert.equal(directRoute.status, 200);
checks.push('deployed admin menu, lazy view chunk and direct route');
let token = '';
let role = '';
const counts = {};
try {
  // Match the actual login page: only username/password, no tenant hint or stale local session.
  const auth = await api('/admin/auth/login', '', { username, password }, 'POST', false);
  token = auth.accessToken || auth.token;
  assert.ok(token, 'Administrator session missing');
  assert.equal(auth.tenantId, tenantId);
  assert.equal(auth.appName, spec.identity.appName);
  assert.ok(auth.featureModules.includes('zhuxianzhenArt'));
  assert.notEqual(auth.role, 'platform_super');
  role = auth.role;
  checks.push('login without tenant hint resolves the correct tenant and feature menu');
  const session = await api('/admin/auth/session', token);
  assert.equal(session.tenantId, tenantId);
  assert.ok(session.featureModules.includes('zhuxianzhenArt'));
  const tenants = await api('/admin/auth/tenants', token);
  assert.ok(tenants.list.length === 1 && tenants.list.every((tenant) => tenant.tenantId === tenantId));
  assert.equal(tenants.list[0].company, spec.identity.company);
  checks.push('administrator tenant list contains only this app and confirmed company');
  for (const [module, appPath] of [
    ['pictures', 'pictures'], ['articles', 'articles'], ['characters', 'characters'],
    ['exhibitions', 'exhibitions'], ['templates', 'creative/templates'],
    ['assets', 'creative/assets'], ['game-configs', 'games/configs']
  ]) {
    const admin = await api('/admin/zhuxianzhen-art/' + module, token);
    const app = await api('/biz/' + tenantId + '/' + appPath);
    const published = admin.items.filter((item) => item.status !== 'hidden');
    assert.deepEqual(published.map((item) => item.id).sort(), app.items.map((item) => item.id).sort());
    counts[module] = app.items.length;
  }
  checks.push('seven public catalogs match between admin and App API');
  const clientConfig = fs.readFileSync(new URL('app/entry/src/main/ets/entryability/EntryAbility.ets', appRoot), 'utf8');
  assert.ok(clientConfig.includes(base) && clientConfig.includes(tenantId));
  checks.push('native App points to SaaS26 and the correct tenant');
} finally {
  if (token) await api('/admin/auth/logout', '', { token }, 'POST');
}
const report = {
  checkedAt: new Date().toISOString(), status: 'pass', tenantId, appName: spec.identity.appName,
  company: spec.identity.company, username, role,
  registration: 'existing tenant reused; no duplicate created',
  adminLoginUrl: origin + '/login', adminOperationsUrl: origin + '/zxznh-art',
  apiBaseUrl: base, frontendChunk: chunk, catalogCounts: counts, checks,
  scope: 'live HTTP/API/static frontend verification, not browser-click acceptance',
  mutations: 'verification login/logout only; no content writes, user-data overwrites, deployment or schema changes',
  secretsIncluded: false
};
fs.writeFileSync(new URL('docs/validation/saas26-integration.json', appRoot), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
