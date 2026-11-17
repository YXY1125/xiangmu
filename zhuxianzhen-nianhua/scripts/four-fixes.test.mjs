import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const ts = require('typescript');
const read = (file) => fs.readFileSync(new URL('../app/entry/src/main/ets/' + file, import.meta.url), 'utf8');
const source = (file) => read(file).replace(/^import .*$/gm, '');
const page = read('pages/DashboardPage.ets');
const methods = page.slice(page.indexOf('  private canvasScale()'), page.indexOf('  private async save()'));
const extra = page.slice(page.indexOf('  private changeRatio('), page.indexOf('  private async exportImage('));
const code = ts.transpileModule(`const Observed = (type) => type;
${source('models/CultureModels.ets')}
${source('data/CultureCatalog.ets')}
${source('services/CultureSearch.ets')}
${source('editor/EditorGeometry.ets')}
${source('editor/EditorLayer.ets')}
const MODEL_WIDTH = 900;
class EditorSnapshot { title = ''; layers = []; backgroundId = ''; canvasHeight = 900; }
export class TestEditor {
 title = '测试'; layers = []; backgroundId = 'paper-cream'; canvasHeight = 900;
 workspaceWidth = 360; workspaceHeight = 450; zoom = 1; selectedId = '';
 history = []; future = []; panX = 0; panY = 0; textDraft = ''; message = '';
 artworkId = ''; createdAt = 0; currentExportPath = ''; currentThumbnailPath = '';
 ${methods}
 ${extra}
}`, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext, experimentalDecorators: true } }).outputText;
const { CultureSearch, CultureCatalog, EditorLayer, TestEditor } = await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));

test('live search matches real characters, article bodies and exhibition introductions', () => {
  assert.ok(CultureSearch.characters('秦小将', CultureCatalog.characters()).some((x) => x.name === '秦小将'));
  assert.ok(CultureSearch.characters('门神', CultureCatalog.characters()).length > 0);
  assert.ok(CultureSearch.articles('木版', CultureCatalog.articles()).length > 0);
  assert.ok(CultureSearch.exhibitions('工艺', CultureCatalog.exhibitions()).length > 0);
});
test('search handles blank, unmatched, case-insensitive and multi-term queries', () => {
  assert.deepEqual(CultureSearch.articles('   ', CultureCatalog.articles()), []);
  assert.deepEqual(CultureSearch.characters('不存在的角色xyz', CultureCatalog.characters()), []);
  assert.equal(CultureSearch.matches('  WOOD  print ', ['Woodblock', 'Printing']), true);
  assert.equal(CultureSearch.matches('wood silk', ['wood print']), false);
});
test('all homepage view-all buttons and search result types have explicit destinations', () => {
  const home = read('pages/HomePage.ets');
  for (const [title, segment] of [['原创角色', 1], ['精选专题', 2], ['热门年画知识', 0]]) {
    assert.match(home, new RegExp(`SectionTitle\\(\\{ title: '${title}'[^\\n]*onMore: \\(\\) => this.onOpenGallery\\(${segment}\\)`));
  }
  assert.match(home, /onChange\(\(value: string\) => this.query = value\)/);
  assert.match(home, /CultureSearch\.characters\(this.query/);
  assert.match(home, /onClick\(\(\) => this.onOpenExhibition\(item.id\)\)/);
  assert.match(read('pages/MainTabPage.ets'), /initialSegment: this.gallerySegment/);
  assert.match(read('pages/CoreBizPage.ets'), /this.segment = this.initialSegment/);
});
test('personal statistics, menu descriptions and retained list cells use reference-bound Builders', () => {
  const mine = read('pages/MinePage.ets');
  for (const method of ['Stat', 'Menu', 'Info', 'ContentRow']) {
    assert.match(mine, new RegExp(`${method}\\(data: \\w+Binding\\)`));
    assert.doesNotMatch(mine, new RegExp(`this\\.${method}\\((?!\\{)`));
  }
  assert.equal((mine.match(/this.Stat\(\{ value:/g) ?? []).length, 4);
  assert.match(mine, /Text\(data.value\)/);
  assert.match(mine, /Text\(data.desc\)/);
});
test('selected layer changes immediately in the observed object without changing gesture identity', () => {
  const editor = new TestEditor();
  editor.addLayer('char_qin', 'character', '');
  const layer = editor.layers[0];
  assert.ok(layer instanceof EditorLayer);
  const id = layer.layerId;
  const width = layer.width;
  editor.alterSelected(40, 0);
  assert.ok(layer.width > width);
  editor.alterSelected(-40, 0);
  assert.ok(Math.abs(layer.width - width) < 1e-8);
  editor.alterSelected(0, 15);
  assert.equal(layer.rotation, 15);
  const x = layer.x;
  editor.dragUpdate({ offsetX: 10, offsetY: 10 });
  editor.dragUpdate({ offsetX: 20, offsetY: 15 });
  assert.ok(Math.abs(layer.x - (x + 20 / editor.canvasScale())) < 1e-8);
  assert.equal(editor.layers[0], layer);
  assert.equal(layer.layerId, id);
  assert.match(page, /\}, \(layer: EditorLayer\) => layer.layerId\)/);
  assert.match(read('editor/ArtworkLayerView.ets'), /@ObjectLink layer: EditorLayer/);
});
test('undo, redo and JSON reopen restore observed instances and full layer configuration', () => {
  const editor = new TestEditor();
  editor.addLayer('', 'text', '新春');
  const originalLayer = editor.layers[0];
  editor.alterSelected(40, 15);
  const state = editor.serializedState();
  editor.undo();
  assert.equal(editor.layers[0], originalLayer, 'retained ForEach child must keep its observed object');
  assert.ok(editor.layers[0] instanceof EditorLayer);
  assert.equal(editor.layers[0].rotation, 0);
  editor.redo();
  assert.equal(editor.layers[0], originalLayer);
  assert.ok(editor.layers[0] instanceof EditorLayer);
  assert.equal(editor.layers[0].rotation, 15);
  assert.equal(editor.serializedState(), state);
  const reopened = new TestEditor();
  reopened.restoreState(state);
  reopened.selectedId = reopened.layers[0].layerId;
  reopened.textDraft = '吉祥如意';
  reopened.updateText();
  reopened.alterSelected(0, 15);
  assert.equal(reopened.layers[0].text, '吉祥如意');
  assert.equal(reopened.layers[0].rotation, 30);
  const work = reopened.buildArtwork();
  assert.equal(work.textObjects[0].text, '吉祥如意');
  assert.equal(work.layers.length, 0);
  assert.match(page, /work.layers.concat\(work.textObjects\).map\(\(layer: ArtworkLayer\) => EditorLayer.from\(layer\)\)/);
});
