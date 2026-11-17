import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { createCoffeeService } from './core.mjs';

const port = Number(process.env.PORT || 3108);
function createDefaultService() {
  return createCoffeeService({
    file: fileURLToPath(new URL('../data/runtime.json', import.meta.url)),
    publicFile: fileURLToPath(new URL('../data/public-content.json', import.meta.url)),
    mediaDir: fileURLToPath(new URL('../data/media', import.meta.url)),
    secret: process.env.SESSION_SECRET,
  });
}

function send(response, status, data) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  response.end(JSON.stringify(data));
}

function sendBinary(response, status, result) {
  response.writeHead(status, {
    'Content-Type': result.mimeType,
    'Content-Length': result.bytes.length,
    'Cache-Control': 'private, max-age=300',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(result.bytes);
}

async function readJson(request, maxBytes = 1024 * 1024) {
  let raw = '';
  for await (const chunk of request) {
    raw += chunk;
    if (raw.length > maxBytes) throw new Error('payload too large');
  }
  return raw.length > 0 ? JSON.parse(raw) : {};
}

function auth(service, request, tenantId) {
  const header = String(request.headers.authorization || '');
  return service.authenticate(header.startsWith('Bearer ') ? header.slice(7) : '', tenantId);
}

export function createCoffeeHttpServer(service) {
  service = service ?? createDefaultService();
  return http.createServer(async (request, response) => {
  const url = new URL(request.url || '/', 'http://localhost');
  const tenantId = String(request.headers['x-tenant-id'] || '');
  if (tenantId !== 'kafyj.zy.huawei') return send(response, 400, { code: 40001, message: '无效租户' });
  try {
    if (request.method === 'POST' && url.pathname === '/api/v1/auth/register') {
      const result = service.register(await readJson(request), tenantId);
      return send(response, result.ok ? 200 : 400, result.ok ? { code: 0, message: 'ok', data: result } : { code: 40001, message: result.message });
    }
    if (request.method === 'POST' && url.pathname === '/api/v1/auth/login') {
      const result = service.login(await readJson(request), tenantId);
      return send(response, result.ok ? 200 : 401, result.ok ? { code: 0, message: 'ok', data: result } : { code: 40101, message: result.message });
    }
    const publicPrefix = '/api/v1/biz/kafyj.zy.huawei/';
    const publicMatch = url.pathname.slice(publicPrefix.length).match(/^(knowledge|origins|beans|brewing-guides|equipment|recipes)(?:\/([^/]+))?$/);
    if (request.method === 'GET' && url.pathname.startsWith(publicPrefix) && publicMatch && !publicMatch[1].startsWith('me')) {
      const result = service.publicItems(publicMatch[1], publicMatch[2] || '');
      if (publicMatch[2] && !result) return send(response, 404, { code: 40401, message: '内容不存在' });
      return send(response, 200, { code: 0, message: 'ok', data: publicMatch[2] ? result : { items: result } });
    }
    const session = auth(service, request, tenantId);
    if (!session) return send(response, 401, { code: 40101, message: '登录已失效' });
    if (request.method === 'POST' && url.pathname === '/api/v1/privacy/account-close') {
      const result = service.closeAccount(session);
      return send(response, result.ok ? 200 : 400, result.ok ? { code: 0, message: 'ok', data: result } : { code: 40001, message: result.message });
    }
    const prefix = '/api/v1/biz/kafyj.zy.huawei/me/';
    if (url.pathname === `${prefix}profile` && request.method === 'GET') {
      return send(response, 200, { code: 0, message: 'ok', data: service.getProfile(session) });
    }
    if (url.pathname === `${prefix}profile` && request.method === 'PUT') {
      const result = service.updateProfile(session, await readJson(request));
      return send(response, 200, { code: 0, message: 'ok', data: result.profile });
    }
    if (url.pathname === `${prefix}evaluations/stats` && request.method === 'GET') {
      return send(response, 200, { code: 0, message: 'ok', data: service.evaluationStats(session) });
    }
    if (url.pathname === `${prefix}achievements` && request.method === 'GET') {
      return send(response, 200, { code: 0, message: 'ok', data: { items: service.achievements(session) } });
    }
    if (url.pathname === '/api/v1/biz/kafyj.zy.huawei/media/images' && request.method === 'POST') {
      const result = service.saveImage(session, await readJson(request, 7 * 1024 * 1024));
      return send(response, result.ok ? 200 : 400, result.ok ? { code: 0, message: 'ok', data: result } : { code: 40001, message: result.message });
    }
    const mediaMatch = url.pathname.match(/^\/api\/v1\/biz\/kafyj\.zy\.huawei\/media\/images\/([^/]+)$/);
    if (mediaMatch && request.method === 'GET') {
      const result = service.readImage(session, mediaMatch[1]);
      if (!result) return send(response, 404, { code: 40401, message: '图片不存在' });
      return sendBinary(response, 200, result);
    }
    const recordMatch = url.pathname.slice(prefix.length).match(/^(recipes|brewing-records|favorites)\/([^/]+)(?:\/(archive))?$/);
    if (request.method === 'PUT' && url.pathname.startsWith(prefix) && recordMatch) {
      const result = recordMatch[3]
        ? service.archiveRecord(session, recordMatch[2])
        : service.versionRecord(session, recordMatch[2], await readJson(request));
      return send(response, result.ok ? 200 : 404, result.ok ? { code: 0, message: 'ok', data: result.record } : { code: 40401, message: result.message });
    }
    if (request.method === 'POST' && url.pathname.startsWith(prefix)) {
      const resource = url.pathname.slice(prefix.length);
      const map = { 'brewing-records': 'brew', recipes: 'recipe', evaluations: 'evaluation', favorites: 'favorite', learning: 'learning', checkins: 'checkin' };
      const kind = map[resource];
      const result = service.createRecord(session, kind, await readJson(request));
      return send(response, result.ok ? 200 : 400, result.ok ? { code: 0, message: 'ok', data: result.record } : { code: 40001, message: result.message });
    }
    if (request.method === 'GET' && url.pathname === `${prefix}growth`) {
      return send(response, 200, { code: 0, message: 'ok', data: service.growth(session) });
    }
    if (request.method === 'GET' && url.pathname === `${prefix}activity-stats`) {
      return send(response, 200, { code: 0, message: 'ok', data: service.activityStats(session) });
    }
    if (request.method === 'GET' && url.pathname.startsWith(prefix)) {
      const resource = url.pathname.slice(prefix.length);
      const map = { 'brewing-records': 'brew', recipes: 'recipe', evaluations: 'evaluation', favorites: 'favorite', learning: 'learning' };
      return send(response, 200, { code: 0, message: 'ok', data: { items: service.listRecords(session, map[resource]) } });
    }
    return send(response, 404, { code: 40401, message: '接口不存在' });
  } catch (error) {
    return send(response, 500, { code: 50001, message: '服务处理失败' });
  }
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  createCoffeeHttpServer().listen(port, '127.0.0.1', () => console.log(`COFFEE LAB API listening on http://127.0.0.1:${port}/api/v1`));
}
