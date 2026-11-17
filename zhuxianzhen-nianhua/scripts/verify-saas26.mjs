import assert from 'node:assert/strict';

const base = 'https://saas26.qianqi.online/api/v1';
const tenantId = 'zxznh.xcl.huawei';
const headers = { 'X-Tenant-Id': tenantId };

async function request(path, init = {}) {
  const response = await fetch(`${base}${path}`, {
    ...init,
    headers: { ...headers, ...init.headers },
    signal: AbortSignal.timeout(20000)
  });
  const json = await response.json();
  assert.ok(response.ok, `${path}: HTTP ${response.status}`);
  assert.equal(json.code, 0, `${path}: unsuccessful business response`);
  return json.data;
}

await request('/platform/health');
console.log('PASS saas26 platform health');
for (const [path, count] of [
  ['characters', 12], ['articles', 7], ['exhibitions', 6],
  ['creative/templates', 20], ['games/configs', 5]
]) {
  const data = await request(`/biz/${tenantId}/${path}`);
  assert.equal(data.items.length, count, path);
  console.log(`PASS public ${path}: ${count}`);
}

if (process.env.SAAS_TENANT_ADMIN_PASSWORD) {
  const auth = await request('/admin/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ tenantId, username: `admin@${tenantId}.local`, password: process.env.SAAS_TENANT_ADMIN_PASSWORD })
  });
  const token = auth.accessToken || auth.token;
  assert.ok(token, 'admin token missing');
  try {
    const data = await request('/admin/zhuxianzhen-art/characters', { headers: { Authorization: `Bearer ${token}` } });
    assert.equal(data.items.length, 12);
    console.log('PASS tenant admin reads the same character catalog');
    if (process.argv.includes('--content-roundtrip')) {
      const record = data.items[0];
      const marker = `${record.name}（同步验证）`;
      try {
        await request(`/admin/zhuxianzhen-art/characters/${encodeURIComponent(record.id)}`, {
          method: 'PUT', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: marker })
        });
        const updated = await request(`/biz/${tenantId}/characters/${encodeURIComponent(record.id)}`);
        assert.equal(updated.name, marker);
      } finally {
        await request(`/admin/zhuxianzhen-art/characters/${encodeURIComponent(record.id)}`, {
          method: 'PUT', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: record.name })
        });
      }
      const restored = await request(`/biz/${tenantId}/characters/${encodeURIComponent(record.id)}`);
      assert.equal(restored.name, record.name);
      console.log('PASS admin content update is visible through App API; original name restored');
    }
    for (const module of ['favorites', 'artworks', 'game-records', 'learning-records', 'browsing-records']) {
      const records = await request(`/admin/zhuxianzhen-art/${module}`, { headers: { Authorization: `Bearer ${token}` } });
      assert.equal(records.items.length, 0);
      console.log(`PASS new tenant ${module}: empty`);
    }
  } finally {
    await request('/admin/auth/logout', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ token }) });
  }
}
