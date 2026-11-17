import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const sharp = require('sharp');
import { command, pause, layout, clickText, clickBounds, screenshot, assertForeground, scrollTo } from './device-driver.mjs';

const reportFile = new URL('../docs/validation/device-four-fixes-20261114.json', import.meta.url);
const report = fs.existsSync(reportFile) ? JSON.parse(fs.readFileSync(reportFile, 'utf8')) : {
  target: process.env.ZXZNH_HDC_TARGET || '127.0.0.1:5555',
  artifactSha256: 'db565ded9aee6bbfbda867f5a95db913d5883e4524a4d70a3ca56068baa7cde9',
  checks: [], status: 'in-progress'
};
export function record(name, details) {
  report.checks.push({ name, checkedAt: new Date().toISOString(), details });
  fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
  console.log('PASS ' + name + ': ' + JSON.stringify(details));
}
export async function tab(name) {
  const nodes = (await layout()).filter((x) => x.text === name);
  const bottom = nodes.sort((a, b) => Number(b.bounds.match(/\d+/g)[1]) - Number(a.bounds.match(/\d+/g)[1]))[0];
  assert.ok(bottom, 'Missing tab ' + name);
  await clickBounds(bottom.bounds);
}
export async function stats() {
  const nodes = await layout();
  return Object.fromEntries(['收藏', '创作', '游戏', '学习'].map((key) => {
    const node = nodes.find((x) => x.id === 'mine-stat-' + key);
    assert.ok(node, 'Missing metric ' + key);
    return [key, Number(node.text)];
  }));
}
async function query(text) {
  if ((await layout()).some((x) => x.text === '收起')) await clickText('收起');
  await clickText('搜索');
  const input = (await layout()).find((x) => x.id === 'home-search-input');
  const b = input.bounds.match(/\d+/g).map(Number);
  command('shell', 'uitest', 'uiInput', 'inputText', String((b[0] + b[2]) / 2), String((b[1] + b[3]) / 2), text);
  await pause(300);
  return layout();
}
async function search() {
  assertForeground();
  await tab('我的');
  const before = await stats();
  record('statistics-baseline', before);
  await tab('首页');
  let nodes = await query('秦小将');
  assert.ok(nodes.some((x) => x.text === '找到 2 项内容'));
  await clickBounds(nodes.find((x) => x.text === '秦小将' && x.id !== 'home-search-input').bounds);
  assert.ok((await layout()).some((x) => x.text === '收藏'));
  await screenshot('regression-20261114-character-opened');
  await clickText('收藏');
  assert.ok((await layout()).some((x) => x.text === '已收藏'));
  await clickText('‹');
  await clickText('收起');
  await tab('我的');
  const after = await stats();
  assert.equal(after['收藏'], before['收藏'] + 1);
  assert.ok((await layout()).some((x) => x.text === `${after['收藏']} 项已收藏`));
  await screenshot('regression-20261114-favorite-increased');
  record('favorite-real-ui-write-refresh', { before, after });
  await tab('首页');
  for (const [term, expected] of [['木版', '一刀一线：木版雕刻'], ['工艺', '木版年画制作工艺展']]) {
    nodes = await query(term);
    const count = nodes.find((x) => x.id === 'home-search-count')?.text;
    assert.ok(count && !count.includes('找到 0 '));
    // Find the requested card by scrolling the actual result container if needed.
    let result = nodes.find((x) => x.text === expected);
    for (let i = 0; !result && i < 5; i++) {
      command('shell', 'uitest', 'uiInput', 'swipe', '540', '1450', '540', '700', '1000');
      result = (await layout()).find((x) => x.text === expected);
    }
    assert.ok(result, 'Search result missing: ' + expected);
    await screenshot('regression-20261114-search-' + (term === '木版' ? 'article' : 'exhibition'));
    await clickBounds(result.bounds);
    const detail = await layout();
    assert.ok(detail.some((x) => x.text === '‹'));
    await screenshot('regression-20261114-search-' + (term === '木版' ? 'article-detail' : 'exhibition-detail'));
    record('search-' + term, { count, opened: expected });
    await clickText('‹');
    if (term === '工艺') await tab('首页');
  }
  nodes = await query('不存在的年画xyz');
  assert.ok(nodes.some((x) => x.text === '找到 0 项内容'));
  assert.ok(nodes.some((x) => x.text.includes('暂未找到相关内容')));
  await screenshot('regression-20261114-search-empty');
  await clickText('收起');
  await clickText('搜索');
  assert.ok((await layout()).some((x) => x.text === '输入关键词，即时查找角色、知识和专题'));
  // The first system Back may only dismiss a focused input/keyboard.
  for (let i = 0; i < 3 && !(await layout()).some((x) => x.text === '搜索'); i++) {
    command('shell', 'uitest', 'uiInput', 'keyEvent', 'Back');
    await pause(500);
  }
  assert.ok((await layout()).some((x) => x.text === '搜索'));
  record('search-empty-clear-native-back', { status: 'pass' });
}

if (process.argv[2] === 'search') await search();

async function more(title) {
  await scrollTo(title);
  const nodes = await layout();
  const heading = nodes.find((x) => x.text === title);
  const y = Number(heading.bounds.match(/\d+/g)[1]);
  const links = nodes.filter((x) => x.text === '查看全部').sort((a, b) =>
    Math.abs(Number(a.bounds.match(/\d+/g)[1]) - y) - Math.abs(Number(b.bounds.match(/\d+/g)[1]) - y));
  assert.ok(links.length > 0, 'Missing view all: ' + title);
  assert.ok(Math.abs(Number(links[0].bounds.match(/\d+/g)[1]) - y) < 160);
  await clickBounds(links[0].bounds);
}
async function navigation() {
  for (const [title, expected, name] of [
    ['原创角色', '门神守护团', 'characters'],
    ['精选专题', '专题 01', 'exhibitions'],
    ['热门年画知识', '朱仙镇木版年画', 'culture']
  ]) {
    await tab('首页');
    await more(title);
    assert.ok((await layout()).some((x) => x.text === expected), 'Wrong destination: ' + title);
    await screenshot('regression-20261114-viewall-' + name);
    record('viewall-' + title, { opened: expected });
  }
  await tab('首页');
  await scrollTo('朱仙镇年画经典作品展');
  await clickText('朱仙镇年画经典作品展');
  assert.ok((await layout()).some((x) => x.text === '数字专题展'));
  await screenshot('regression-20261114-home-exhibition-card');
  await clickText('‹');
  record('home-exhibition-main-card', { opened: 'classic exhibition detail' });
}
if (process.argv[2] === 'navigation') await navigation();

async function gameRecord() {
  await tab('我的');
  const before = await stats();
  await tab('乐园');
  await scrollTo('年画知识问答');
  await clickText('年画知识问答');
  await scrollTo('开始游戏');
  await clickText('开始游戏');
  await clickText('暂停');
  assert.ok((await layout()).some((x) => x.text === '游戏已暂停'));
  await clickText('继续');
  for (const [i, answer] of ['雕刻木版', '朱砂红', '不同色版依次印制', '守护家宅', '结合地域与语境'].entries()) {
    await clickText(answer);
    assert.ok((await layout()).some((x) => x.text.includes('回答正确')));
    await clickText(i === 4 ? '查看成绩' : '下一题');
  }
  const result = await layout();
  assert.ok(result.some((x) => x.text === '挑战结束'));
  assert.ok(result.some((x) => x.text === '得分 1000'));
  assert.ok(result.some((x) => x.text.includes('记录已保存')));
  await screenshot('regression-20261114-quiz-result');
  await clickText('返回乐园');
  await tab('我的');
  const after = await stats();
  assert.equal(after['游戏'], before['游戏'] + 1);
  await screenshot('regression-20261114-game-statistics');
  await scrollTo('我的游戏记录');
  assert.ok((await layout()).some((x) => x.text === `${after['游戏']} 条成绩`));
  await clickText('我的游戏记录');
  assert.ok((await layout()).some((x) => x.text === 'quiz · 1000 分'));
  await screenshot('regression-20261114-game-records');
  await clickText('‹');
  record('game-real-completion-and-statistics', { before, after, score: 1000, pauseResume: true, recordVisible: true });
}
if (process.argv[2] === 'game') await gameRecord();

const rect = (node) => {
  const [left, top, right, bottom] = node.bounds.match(/-?\d+/g).map(Number);
  return { left, top, width: right - left, height: bottom - top };
};
export async function canvasState(name, layerId) {
  const nodes = await layout();
  const canvas = rect(nodes.find((x) => x.id === 'artworkCanvas'));
  const node = nodes.find((x) => layerId ? x.id === layerId : x.id?.startsWith('editor-layer-'));
  assert.ok(node, 'Missing live layer');
  const box = rect(node);
  const state = { id: node.id, canvas, box,
    x: (box.left - canvas.left) / canvas.width, y: (box.top - canvas.top) / canvas.height,
    w: box.width / canvas.width, h: box.height / canvas.height };
  await screenshot('regression-20261114-' + name);
  return state;
}
async function pixelDifference(a, b, canvas) {
  const file = (name) => new URL('../screenshots/regression-20261114-' + name + '-emulator.jpeg', import.meta.url);
  const pixels = async (name) => sharp(fs.readFileSync(file(name))).extract(canvas).removeAlpha().raw().toBuffer();
  const first = await pixels(a), second = await pixels(b);
  let changed = 0;
  for (let i = 0; i < first.length; i++) if (Math.abs(first[i] - second[i]) > 15) changed++;
  return changed / first.length;
}
async function transform(kind, layerId) {
  const prefix = 'editor-' + kind;
  const before = await canvasState(prefix + '-before', layerId);
  await clickText('缩小');
  const small = await canvasState(prefix + '-small', before.id);
  assert.ok(small.w < before.w - 0.01);
  await clickText('放大');
  const large = await canvasState(prefix + '-large', before.id);
  assert.ok(Math.abs(large.w - before.w) < 0.01);
  await clickText('旋转');
  const rotated = await canvasState(prefix + '-rotated', before.id);
  assert.deepEqual(large.canvas, rotated.canvas);
  const difference = await pixelDifference(prefix + '-large', prefix + '-rotated', rotated.canvas);
  assert.ok(difference > 0.001, 'Rotation did not render in the canvas immediately');
  const start = { x: Math.round(rotated.box.left + rotated.box.width / 2), y: Math.round(rotated.box.top + rotated.box.height / 2) };
  command('shell', 'uitest', 'uiInput', 'swipe', String(start.x), String(start.y), String(start.x + 32), String(start.y + 22), '600');
  await pause(350);
  const dragged = await canvasState(prefix + '-dragged', before.id);
  assert.ok(dragged.x > rotated.x + 0.025 && dragged.y > rotated.y + 0.015, 'Drag not rendered immediately');
  await clickText('撤销');
  const undone = await canvasState(prefix + '-undo', before.id);
  assert.ok(Math.abs(undone.x - rotated.x) < 0.015 && Math.abs(undone.y - rotated.y) < 0.015);
  await clickText('恢复');
  const redone = await canvasState(prefix + '-redo', before.id);
  assert.ok(Math.abs(redone.x - dragged.x) < 0.015 && Math.abs(redone.y - dragged.y) < 0.015);
  await clickBounds('[' + redone.box.left + ',' + redone.box.top + '][' + (redone.box.left + redone.box.width) + ',' + (redone.box.top + redone.box.height) + ']');
  const selected = await canvasState(prefix + '-reselected', before.id);
  const x = Math.round(selected.box.left + selected.box.width / 2), y = Math.round(selected.box.top + selected.box.height / 2);
  command('shell', 'uitest', 'uiInput', 'swipe', String(x), String(y), String(x + 22), String(y + 18), '600');
  await pause(350);
  const continued = await canvasState(prefix + '-continued-drag', before.id);
  assert.ok(continued.x > selected.x + 0.015);
  record('immediate-transform-' + kind, { before, small, large, rotated, canvasPixelDifference: difference, dragged, undone, redone, continued });
}
if (process.argv[2] === 'transform-character') await transform('character');
if (process.argv[2] === 'transform-text') {
  const layers = (await layout()).filter((x) => x.id?.startsWith('editor-layer-'));
  await transform('text', layers.at(-1)?.id);
}

async function waitSaved() {
  for (let i = 0; i < 20; i++) {
    const nodes = await layout();
    if (nodes.some((x) => x.text.includes('作品配置已保存'))) return;
    assert.ok(!nodes.some((x) => x.text.includes('保存失败')));
    await pause(200);
  }
  assert.fail('UI save did not finish');
}
async function saveReopen() {
  assertForeground();
  const nodes = await layout();
  const ids = nodes.filter((x) => x.id?.startsWith('editor-layer-')).map((x) => x.id);
  assert.equal(ids.length, 2);
  const before = [];
  for (let i = 0; i < ids.length; i++) before.push(await canvasState('editor-before-save-' + i, ids[i]));
  const input = nodes.find((x) => x.type === 'TextInput' && x.text === '我的年画');
  const b = input.bounds.match(/\d+/g).map(Number);
  command('shell', 'uitest', 'uiInput', 'inputText', String((b[0] + b[2]) / 2), String((b[1] + b[3]) / 2), '验收-1114-实时画布');
  const title = (await layout()).find((x) => x.type === 'TextInput' && x.text.includes('验收-1114'))?.text;
  assert.ok(title);
  await clickText('保存');
  await waitSaved();
  await screenshot('regression-20261114-editor-saved');
  await clickText('‹');
  await tab('我的');
  const afterNew = await stats();
  const baseline = report.checks.find((x) => x.name === 'statistics-baseline').details;
  assert.equal(afterNew['创作'], baseline['创作'] + 1);
  await screenshot('regression-20261114-artwork-statistics');
  await scrollTo('我的创作');
  assert.ok((await layout()).some((x) => x.text === `${afterNew['创作']} 件可再次编辑的作品`));
  await clickText('我的创作');
  await scrollTo(title);
  await clickText(title);
  assert.ok((await layout()).some((x) => x.text === '900×1200 · 100%'));
  assert.ok((await layout()).some((x) => x.text === '验收纳福'));
  const reopened = [];
  for (let i = 0; i < ids.length; i++) {
    const state = await canvasState('editor-reopened-' + i, ids[i]);
    assert.ok(Math.abs(state.x - before[i].x) < 0.015 && Math.abs(state.y - before[i].y) < 0.015);
    assert.ok(Math.abs(state.w - before[i].w) < 0.015 && Math.abs(state.h - before[i].h) < 0.015);
    reopened.push(state);
  }
  await clickBounds('[' + reopened[1].box.left + ',' + reopened[1].box.top + '][' + (reopened[1].box.left + reopened[1].box.width) + ',' + (reopened[1].box.top + reopened[1].box.height) + ']');
  const selected = await canvasState('editor-reopened-selected', ids[1]);
  await clickText('放大');
  const changed = await canvasState('editor-reopened-edited', ids[1]);
  assert.ok(changed.box.width > selected.box.width);
  await clickText('保存');
  await waitSaved();
  await clickText('‹');
  await tab('我的');
  const afterEdit = await stats();
  assert.equal(afterEdit['创作'], afterNew['创作']);
  record('artwork-save-reopen-reedit-statistics', { title, before, reopened, selected, changed, afterNew, afterEdit });
}
if (process.argv[2] === 'save-reopen') await saveReopen();

async function learningAndRestart() {
  await tab('首页');
  await tab('我的');
  const before = await stats();
  // 'carving' was read through the real search result earlier; reread must not inflate it.
  await tab('年画馆');
  await scrollTo('一刀一线：木版雕刻');
  await clickText('一刀一线：木版雕刻');
  await clickText('‹');
  await tab('我的');
  assert.equal((await stats())['学习'], before['学习']);
  await tab('年画馆');
  await scrollTo('贴年画与新春民俗');
  await clickText('贴年画与新春民俗');
  await screenshot('regression-20261114-learning-new-article');
  await clickText('‹');
  await tab('我的');
  const after = await stats();
  assert.equal(after['学习'], before['学习'] + 1);
  await screenshot('regression-20261114-learning-statistics');
  await scrollTo('我的学习记录');
  assert.ok((await layout()).some((x) => x.text === `${after['学习']} 篇已阅读`));
  await clickText('我的学习记录');
  await scrollTo('贴年画与新春民俗');
  await clickText('贴年画与新春民俗');
  await clickText('‹');
  await clickText('‹');
  await tab('首页');
  await tab('我的');
  assert.equal((await stats())['学习'], after['学习']);
  record('learning-first-read-repeat-and-list', { before, after, repeatedReadsDoNotIncrease: true });
  await tab('首页');
  await query('秦小将');
  await clickText('秦小将', 1);
  await clickText('已收藏');
  await clickText('‹');
  await clickText('收起');
  await tab('我的');
  const restoredFavorite = await stats();
  const baseline = report.checks.find((x) => x.name === 'statistics-baseline').details;
  assert.equal(restoredFavorite['收藏'], baseline['收藏']);
  record('favorite-cancel-refresh-original-state', { before: after, after: restoredFavorite });
  assertForeground();
  command('shell', 'aa', 'force-stop', 'zxznh.xcl.huawei');
  command('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'zxznh.xcl.huawei');
  await pause(1500);
  await tab('我的');
  const restarted = await stats();
  assert.deepEqual(restarted, restoredFavorite);
  await screenshot('regression-20261114-statistics-after-restart');
  record('all-four-statistics-process-restart', { before: restoredFavorite, after: restarted, originalLoginPreserved: true });
}
if (process.argv[2] === 'learning-restart') await learningAndRestart();
