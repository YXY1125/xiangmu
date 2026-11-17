import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const hdc = 'D:/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const target = process.env.ZXZNH_HDC_TARGET || '127.0.0.1:5555';
if (!['127.0.0.1:5555', '127.0.0.1:10001'].includes(target)) throw new Error('Unexpected emulator target');
const appDir = fileURLToPath(new URL('..', import.meta.url));
export function command(...args) {
  if (args[0] === 'shell' && args[1] === 'uitest' && args[2] === 'uiInput') assertForeground();
  const result = spawnSync(hdc, ['-t', target, ...args], { encoding: 'utf8', windowsHide: true, timeout: 30000 });
  if (result.status !== 0 || /\[Fail\]|error:|Error:/i.test(result.stdout || '')) throw new Error(`Device command failed: ${args.slice(0, 3).join(' ')}`);
  return result.stdout;
}
export function assertForeground() {
  const result = spawnSync(hdc, ['-t', target, 'shell', 'aa', 'dump', '-a'], { encoding: 'utf8', windowsHide: true, timeout: 10000 });
  if (result.status !== 0) throw new Error('Cannot confirm foreground ownership');
  const foreground = (result.stdout || '').split(/AbilityRecord ID/).filter((block) =>
    /app name \[/.test(block) && /state #FOREGROUND/.test(block));
  if (foreground.length !== 1 || !foreground[0].includes('app name [zxznh.xcl.huawei]')) {
    throw new Error('Emulator is no longer owned by this app; all input stopped');
  }
}
export const pause = (ms = 350) => new Promise((resolve) => setTimeout(resolve, ms));
export async function layout() {
  assertForeground();
  command('shell', 'uitest', 'dumpLayout', '-p', '/data/local/tmp/zxznh-smoke-layout.json');
  const local = `${appDir}/docs/validation/device-current-layout.json`;
  command('file', 'recv', '/data/local/tmp/zxznh-smoke-layout.json', local);
  const root = JSON.parse(fs.readFileSync(local, 'utf8'));
  const nodes = [];
  function walk(node) { if (node.attributes) nodes.push(node.attributes); for (const child of node.children || []) walk(child); }
  walk(root);
  return nodes;
}
export async function clickText(text, occurrence = 0) {
  const all = await layout();
  const nodes = all.filter((node) => node.text === text);
  let node = nodes[occurrence];
  if (!node) throw new Error(`UI text not found: ${text}`);
  // Text can overflow a clipped material card; tap its real clickable owner, not the overflow.
  if (node.clickable !== 'true') {
    node = all.filter((owner) => owner.clickable === 'true' &&
      node.hierarchy.startsWith(owner.hierarchy + ','))
      .sort((a, b) => b.hierarchy.length - a.hierarchy.length)[0] || node;
  }
  const coordinates = node.bounds.match(/\d+/g).map(Number);
  command('shell', 'uitest', 'uiInput', 'click', `${Math.round((coordinates[0] + coordinates[2]) / 2)}`, `${Math.round((coordinates[1] + coordinates[3]) / 2)}`);
  await pause();
}
export async function clickId(id) {
  const node = (await layout()).find((item) => item.id === id || item.key === id);
  if (!node) throw new Error(`UI ID not found: ${id}`);
  const [left, top, right, bottom] = node.bounds.match(/\d+/g).map(Number);
  command('shell', 'uitest', 'uiInput', 'click', `${Math.round((left + right) / 2)}`, `${Math.round((top + bottom) / 2)}`);
  await pause();
}
export async function clickBounds(bounds) {
  const [left, top, right, bottom] = bounds.match(/\d+/g).map(Number);
  command('shell', 'uitest', 'uiInput', 'click', `${Math.round((left + right) / 2)}`, `${Math.round((top + bottom) / 2)}`);
  await pause();
}
export async function scrollTo(text, maxSwipes = 8) {
  for (let index = 0; index < maxSwipes * 2; index++) {
    const nodes = await layout();
    if (nodes.some((node) => node.text === text)) return;
    const upward = index < maxSwipes;
    const scroll = nodes.filter((node) => node.type === 'Scroll' && node.scrollable === 'true' &&
      Number(node.bounds.match(/-?\d+/g)[3]) - Number(node.bounds.match(/-?\d+/g)[1]) > 350).at(-1);
    if (!scroll) throw new Error('No visible vertical scroll container');
    const [left, top, right, bottom] = scroll.bounds.match(/-?\d+/g).map(Number);
    const x = String(Math.round((left + right) / 2));
    const high = String(Math.round(top + (bottom - top) * 0.16));
    const low = String(Math.round(top + (bottom - top) * 0.84));
    command('shell', 'uitest', 'uiInput', 'swipe', x, upward ? low : high, x, upward ? high : low, '1600');
    await pause();
  }
  throw new Error(`Unable to scroll to: ${text}`);
}
export async function screenshot(name) {
  assertForeground();
  command('shell', 'snapshot_display', '-f', `/data/local/tmp/zxznh-${name}.jpeg`);
  assertForeground();
  command('file', 'recv', `/data/local/tmp/zxznh-${name}.jpeg`, `${appDir}/screenshots/${name}-emulator.jpeg`);
}
export async function assertText(text) {
  if (!(await layout()).some((node) => node.text?.includes(text))) throw new Error(`Expected UI text missing: ${text}`);
}
