import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const ts = require('typescript');
const code = ts.transpileModule(fs.readFileSync(new URL('../app/entry/src/main/ets/services/BackService.ets', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } }).outputText;
const { BackService } = await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));
test('native back dispatches the top detail before its underlying exhibition', () => {
  const calls = [];
  const parent = BackService.register(() => { calls.push('exhibition'); return true; });
  const child = BackService.register(() => { calls.push('article'); return true; });
  assert.equal(BackService.dispatch(), true);
  assert.deepEqual(calls, ['article']);
  BackService.remove(child);
  BackService.dispatch();
  assert.deepEqual(calls, ['article', 'exhibition']);
  BackService.remove(parent);
});
test('inactive root handlers allow system back while removed editors cannot trap it', () => {
  const root = BackService.register(() => false);
  const editor = BackService.register(() => true);
  assert.equal(BackService.dispatch(), true);
  BackService.remove(editor);
  assert.equal(BackService.dispatch(), false);
  BackService.remove(root);
});
