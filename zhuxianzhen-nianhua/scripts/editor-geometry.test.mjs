import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const ts = require('typescript');
const source = fs.readFileSync(new URL('../app/entry/src/main/ets/editor/EditorGeometry.ets', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } }).outputText;
const { EditorGeometry } = await import(`data:text/javascript;base64,${Buffer.from(compiled).toString('base64')}`);

test('all supported ratios have exact model dimensions', () => {
  assert.equal(EditorGeometry.heightForRatio('1:1'), 900);
  assert.equal(EditorGeometry.heightForRatio('3:4'), 1200);
  assert.equal(EditorGeometry.heightForRatio('9:16'), 1600);
});
test('canvas fits both narrow screens and tall artwork without clipping', () => {
  for (const width of [280, 320, 600]) for (const height of [240, 480]) for (const ratio of ['1:1', '3:4', '9:16']) {
    const canvasHeight = EditorGeometry.heightForRatio(ratio);
    const scale = EditorGeometry.fitScale(900, canvasHeight, width, height, 1);
    assert.ok(900 * scale <= width - 24 + 0.00001);
    assert.ok(canvasHeight * scale <= height - 24 + 0.00001);
  }
});
test('touch deltas convert through current zoom and clamp to real canvas bounds', () => {
  assert.equal(EditorGeometry.boundedPosition(100, 20, 0.2, 200, 900), 200);
  assert.equal(EditorGeometry.boundedPosition(100, 20, 0.1, 200, 900), 300);
  assert.equal(EditorGeometry.boundedPosition(1400, 100, 0.2, 200, 1600), 1400);
  assert.equal(EditorGeometry.boundedPosition(0, -50, 0.2, 200, 900), 0);
  assert.equal(EditorGeometry.boundedPosition(50, 10, 0.2, 1200, 900), 0);
});
