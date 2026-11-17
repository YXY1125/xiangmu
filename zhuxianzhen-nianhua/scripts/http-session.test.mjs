import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const ts = require('typescript');
const read = (file) => fs.readFileSync(new URL('../app/entry/src/main/ets/' + file, import.meta.url), 'utf8').replace(/^import .*$/gm, '');
test('late 401 from account A does not clear the new account B session', async () => {
  const state = new Map([['apiBaseUrl', 'https://example.test'], ['tenantId', 'zxznh.xcl.huawei'], ['accessToken', 'token-a']]);
  let respond;
  let started;
  const sent = new Promise((resolve) => { started = resolve; });
  let cleared = 0;
  globalThis.AppStorage = { get: (key) => state.get(key), setOrCreate: (key, value) => state.set(key, value) };
  globalThis.httpTestDeps = {
    http: { RequestMethod: { GET: 'GET', POST: 'POST' }, HttpDataType: { STRING: 'STRING' }, createHttp: () => ({ request: async () => { started(); return new Promise((resolve) => { respond = resolve; }); }, destroy: () => {} }) },
    SessionStore: { clearSession: async () => { cleared++; state.set('accessToken', ''); } }
  };
  const code = ts.transpileModule('const {http, SessionStore} = globalThis.httpTestDeps;\n' + read('models/ApiModels.ets') + '\n' + read('services/HttpClient.ets'), { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } }).outputText;
  const { HttpClient } = await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));
  const pending = HttpClient.get('/private');
  await sent;
  state.set('accessToken', 'token-b');
  respond({ responseCode: 401 });
  await pending;
  assert.equal(cleared, 0);
  assert.equal(state.get('accessToken'), 'token-b');
});
