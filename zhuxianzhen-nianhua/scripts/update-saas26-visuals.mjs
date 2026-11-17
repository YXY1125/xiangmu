import assert from 'node:assert/strict';
import fs from 'node:fs';
const tenantId = 'zxznh.xcl.huawei';
const base = 'https://saas26.qianqi.online/api/v1';
const password = process.env.SAAS_TENANT_ADMIN_PASSWORD;
assert.ok(password, 'Required secure password unavailable');
async function api(path, token, body, method = 'GET') {
  const response = await fetch(base + path, { method, headers: { 'X-Tenant-Id': tenantId, 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) }, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(20000) });
  const result = await response.json();
  assert.ok(response.ok && result.code === 0, path + ': update failed');
  return result.data;
}
const auth = await api('/admin/auth/login', '', { tenantId, username: 'admin@' + tenantId + '.local', password }, 'POST');
const token = auth.accessToken;
const backup = [];
try {
  for (const module of ['articles', 'exhibitions', 'templates', 'assets']) {
    const rows = JSON.parse(fs.readFileSync(new URL('../../../platform/data/runtime/' + tenantId + '/zxznh-' + module + '.json', import.meta.url), 'utf8')).items;
    const existing = await api('/admin/zhuxianzhen-art/' + module, token);
    backup.push({ module, items: existing.items });
    fs.writeFileSync(new URL('../docs/validation/public-visuals-backup.json', import.meta.url), JSON.stringify({ tenantId, backup }, null, 2));
    for (const row of rows) {
      assert.ok(existing.items.some((item) => item.id === row.id), 'Missing target public record');
      const patch = module === 'assets' ? { title: row.title, assetCount: row.assetCount, rasterCount: row.rasterCount, vectorCount: row.vectorCount, backgroundCount: row.backgroundCount, exhibitionCoverCount: row.exhibitionCoverCount, sourceNote: row.sourceNote } :
        module === 'articles' ? { body: row.body, sourceNote: row.sourceNote, editorialVersion: row.editorialVersion, reviewedAt: row.reviewedAt } :
        module === 'exhibitions' ? { coverKey: row.coverKey } : { background: row.background, defaultAsset: row.defaultAsset };
      await api('/admin/zhuxianzhen-art/' + module + '/' + encodeURIComponent(row.id), token, patch, 'PUT');
    }
    const verify = await api('/admin/zhuxianzhen-art/' + module, token);
    for (const row of rows) {
      const current = verify.items.find((item) => item.id === row.id);
      const field = module === 'assets' ? 'assetCount' : module === 'articles' ? 'body' : module === 'exhibitions' ? 'coverKey' : 'background';
      assert.equal(current[field], row[field]);
    }
    console.log('PASS target public visuals updated and verified: ' + module);
  }
} finally {
  await api('/admin/auth/logout', '', { token }, 'POST');
}
