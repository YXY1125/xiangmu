import assert from 'node:assert/strict';
import fs from 'node:fs';
const tenantId = 'zxznh.xcl.huawei';
const base = 'https://saas26.qianqi.online/api/v1';
const password = process.env.SAAS_TENANT_ADMIN_PASSWORD;
assert.ok(password, 'Required secure password unavailable');
async function api(path, token, body, method = 'GET') {
  const r = await fetch(base + path, { method, headers: {
    'X-Tenant-Id': tenantId, 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {})
  }, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(20000) });
  const j = await r.json();
  assert.ok(r.ok, `${path}: HTTP ${r.status}`);
  assert.equal(j.code, 0, `${path}: unsuccessful business response`);
  return j.data;
}
const auth = await api('/admin/auth/login', '', { tenantId, username: `admin@${tenantId}.local`, password }, 'POST');
const token = auth.accessToken;
assert.ok(token, 'Token missing');
try {
  for (const module of ['pictures', 'articles', 'characters', 'exhibitions', 'templates', 'assets', 'game-configs']) {
    const rows = JSON.parse(fs.readFileSync(new URL(`../../../platform/data/runtime/${tenantId}/zxznh-${module}.json`, import.meta.url), 'utf8')).items;
    const existing = await api(`/admin/zhuxianzhen-art/${module}`, token);
    const ids = new Set(existing.items.map((item) => item.id));
    let created = 0;
    for (const row of rows) {
      if (ids.has(row.id)) continue;
      await api(`/admin/zhuxianzhen-art/${module}`, token, row, 'POST');
      created++;
    }
    console.log(`Published public ${module}: ${created} created; existing records preserved`);
  }
} finally {
  await api('/admin/auth/logout', '', { token }, 'POST');
}
