import fs from 'node:fs';
import assert from 'node:assert/strict';
import { clickText, clickId, clickBounds, assertText, layout, screenshot, scrollTo, pause } from './device-driver.mjs';
const reportUrl = new URL('../docs/validation/device-games.json', import.meta.url);
const results = (process.argv.includes('--match-only') || process.argv.includes('--finish-match')) && fs.existsSync(reportUrl) ? JSON.parse(fs.readFileSync(reportUrl, 'utf8')).results.filter((item) => item.game !== 'match') : [];
async function start(name) {
  await clickText('乐园');
  await scrollTo(name);
  await clickText(name);
  await scrollTo('开始游戏');
  await clickText('开始游戏');
  await clickText('暂停');
  await assertText('游戏已暂停');
  await clickText('继续');
}
async function finish(name) {
  await assertText('挑战结束');
  await pause(400);
  await assertText('记录已保存');
  await screenshot(`game-${name}-result`);
  results.push({ game: name, status: 'pass', saved: true, pauseResume: true });
  fs.writeFileSync(new URL('../docs/validation/device-games.json', import.meta.url), JSON.stringify({ checkedAt: new Date().toISOString(), results }, null, 2));
  await clickText('返回乐园');
  console.log(`PASS emulator game completion and persistence: ${name}`);
}

if (process.argv.includes('--finish-match')) { await finish('match'); process.exit(0); }

if (!process.argv.includes('--match-only')) {
await start('年画知识问答');
for (const [index, option] of ['雕刻木版', '朱砂红', '不同色版依次印制', '守护家宅', '结合地域与语境'].entries()) {
  await clickText(option);
  await assertText('回答正确');
  await clickText(index === 4 ? '查看成绩' : '下一题');
}
await assertText('得分 1000');
await finish('quiz');

await start('年画拼图');
for (let index = 0; index < 9; index++) {
  const nodes = (await layout()).filter((node) => /^[1-9]$/.test(node.text || '') && node.type === 'Text');
  if (nodes.length !== 9) break;
  const sorted = nodes.sort((a, b) => {
    const aa = a.bounds.match(/\d+/g).map(Number), bb = b.bounds.match(/\d+/g).map(Number);
    return aa[1] - bb[1] || aa[0] - bb[0];
  });
  if (sorted[index].text === `${index + 1}`) continue;
  const desired = sorted.find((node) => node.text === `${index + 1}`);
  await clickBounds(sorted[index].bounds);
  await clickBounds(desired.bounds);
}
await finish('puzzle');

await start('火眼金睛');
await screenshot('game-difference-playing');
for (let index = 0; index < 3; index++) await clickId(`difference-hit-${index}`);
await finish('difference');

await start('纹样寻宝');
await screenshot('game-treasure-playing');
for (let index = 0; index < 4; index++) await clickId(`treasure-hit-${index}`);
await finish('treasure');
}

await start('福气配对');
const cards = (await layout()).filter((node) => /^match-card-\d+$/.test(node.id || node.key || '')).sort((a, b) => {
  const aa = a.bounds.match(/\d+/g).map(Number), bb = b.bounds.match(/\d+/g).map(Number);
  return aa[1] - bb[1] || aa[0] - bb[0];
});
assert.equal(cards.length, 12);
const seen = new Map(), matched = new Set();
async function reveal(index) {
  await clickId(`match-card-${index}`);
  const nodes = await layout();
  const card = nodes.find((node) => node.id === `match-card-${index}` || node.key === `match-card-${index}`);
  if (!card && nodes.some((node) => node.text === '挑战结束')) return 'finished';
  const [x1, y1, x2, y2] = card.bounds.match(/\d+/g).map(Number);
  const shown = nodes.find((node) => {
    if (!['福', '云', '花', '狮', '吉', '春'].includes(node.text)) return false;
    const [left, top, right, bottom] = node.bounds.match(/\d+/g).map(Number);
    return left >= x1 && right <= x2 && top >= y1 && bottom <= y2;
  });
  if (shown) seen.set(index, shown.text);
  return shown?.text;
}
for (let turn = 0; turn < 40 && matched.size < 12; turn++) {
  let first = -1, second = -1;
  for (const [i, value] of seen) {
    if (matched.has(i)) continue;
    const pair = [...seen].find(([j, other]) => j !== i && !matched.has(j) && other === value);
    if (pair) { first = i; second = pair[0]; break; }
  }
  if (first < 0) first = cards.findIndex((_card, index) => !matched.has(index) && !seen.has(index));
  assert.ok(first >= 0, 'No available card');
  const a = await reveal(first);
  if (second < 0) {
    const pair = [...seen].find(([j, value]) => j !== first && !matched.has(j) && value === a);
    second = pair ? pair[0] : cards.findIndex((_card, index) => index !== first && !matched.has(index) && !seen.has(index));
  }
  assert.ok(second >= 0);
  const b = await reveal(second);
  if (a === b || (matched.size === 10 && (await layout()).some((node) => node.text === '挑战结束'))) { matched.add(first); matched.add(second); }
  else await pause(1700);
}
await finish('match');
fs.writeFileSync(new URL('../docs/validation/device-games.json', import.meta.url), JSON.stringify({ checkedAt: new Date().toISOString(), results }, null, 2));
