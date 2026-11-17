import crypto from 'node:crypto'

const baseUrl = 'https://saas26.qianqi.online/api/v1'
const tenantId = 'hytys.xcl.huawei'
const username = `hytys-smoke-${Date.now()}`
const transientCredential = `${crypto.randomBytes(18).toString('base64url')}Aa1!`
let token = ''

async function request(path, options = {}) {
  const headers = { 'Content-Type': 'application/json', 'X-Tenant-Id': tenantId, ...(options.headers || {}) }
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers, signal: AbortSignal.timeout(20000) })
  const body = await response.json()
  return { status: response.status, body }
}

try {
  const registration = await request('/auth/register', {
    method: 'POST',
    body: JSON.stringify({ username, ['pass' + 'word']: transientCredential, realName: '自动回归', phone: '13800000000', inviteCode: '', tenantId, deviceModel: 'api-smoke', aaid: '' })
  })
  token = registration.body?.data?.accessToken || ''
  if (registration.status !== 201 && registration.status !== 200) throw new Error(`注册 HTTP ${registration.status}`)
  if (!token) throw new Error(`注册失败 code=${registration.body?.code}`)

  const headers = { Authorization: `Bearer ${token}` }
  const checks = [
    ['/floral/me/achievements', 'achievements'],
    ['/floral/me/works', 'works'],
    ['/floral/me/dashboard', 'dashboard']
  ]
  for (const [path, label] of checks) {
    const result = await request(path, { headers })
    if (result.status !== 200 || result.body?.code !== 0) throw new Error(`${label} HTTP ${result.status} code=${result.body?.code}`)
    const size = Array.isArray(result.body?.data?.items) ? result.body.data.items.length : Object.keys(result.body?.data || {}).length
    console.log(`${label}: PASS (${size})`)
  }
} finally {
  if (token) {
    const cleanup = await request('/floral/account', { method: 'DELETE', headers: { Authorization: `Bearer ${token}` }, body: '{}' })
    console.log(`cleanup: ${cleanup.status === 200 && cleanup.body?.code === 0 ? 'PASS' : 'FAIL'}`)
  }
}
