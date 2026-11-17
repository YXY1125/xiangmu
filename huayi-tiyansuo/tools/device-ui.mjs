import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const hdc = process.env.HDC_PATH || 'D:\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe'
const target = process.env.HDC_TARGET || '127.0.0.1:5555'
const bundleName = 'hytys.xcl.huawei'
const evidenceDir = path.join(projectRoot, 'docs', 'validation', 'device')
const localLayout = path.join(evidenceDir, 'current-layout.json')
const remoteLayout = '/data/local/tmp/hytys-current-layout.json'

fs.mkdirSync(evidenceDir, { recursive: true })

function run(...args) {
  return execFileSync(hdc, ['-t', target, ...args], { encoding: 'utf8', timeout: 30000, stdio: 'pipe' })
}

function pause(milliseconds = 450) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function pauseSync(milliseconds) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds)
}

function flatten(root, result = []) {
  if (root?.attributes) result.push(root.attributes)
  for (const child of root?.children || []) flatten(child, result)
  return result
}

function rectangle(bounds) {
  const values = String(bounds || '').match(/-?\d+/g)?.map(Number) || []
  if (values.length !== 4) return null
  return { left: values[0], top: values[1], right: values[2], bottom: values[3] }
}

function visible(node) {
  const box = rectangle(node.bounds)
  return box !== null && box.right > box.left && box.bottom > box.top && box.bottom > 137 && box.top < 1822
}

function center(node) {
  const box = rectangle(node.bounds)
  if (!box) throw new Error(`节点没有有效区域：${node.text || node.hint || node.type}`)
  return [Math.round((box.left + box.right) / 2), Math.round((box.top + box.bottom) / 2)]
}

export function layout() {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const temporaryLayout = `${localLayout}.tmp`
      run('shell', 'uitest', 'dumpLayout', '-p', remoteLayout)
      run('file', 'recv', remoteLayout, temporaryLayout)
      const all = flatten(JSON.parse(fs.readFileSync(temporaryLayout, 'utf8')))
      fs.renameSync(temporaryLayout, localLayout)
      if (all.some((node) => node.bundleName === bundleName)) return all
      run('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', bundleName)
    } catch (error) {
      if (attempt === 2) throw error
    }
    pauseSync(600)
  }
  throw new Error('无法将花艺体验所恢复到前台')
}

export function findText(text) {
  const matches = layout().filter((node) => node.text === text && visible(node))
  if (matches.length === 0) throw new Error(`找不到可见文本：${text}`)
  return matches.find((node) => node.clickable === 'true') || matches.at(-1)
}

export async function tapText(text) {
  const point = center(findText(text))
  run('shell', 'uitest', 'uiInput', 'click', String(point[0]), String(point[1]))
  await pause()
}

export async function tapPoint(x, y) {
  run('shell', 'uitest', 'uiInput', 'click', String(x), String(y))
  await pause()
}

export async function replaceInput(hint, value) {
  const node = layout().find((item) => item.hint === hint && visible(item))
  if (!node) throw new Error(`找不到输入框：${hint}`)
  const point = center(node)
  run('shell', 'uitest', 'uiInput', 'click', String(point[0]), String(point[1]))
  run('shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017')
  run('shell', 'uitest', 'uiInput', 'keyEvent', '2055')
  run('shell', 'uitest', 'uiInput', 'text', value)
  await pause()
}

export async function swipeUp() {
  run('shell', 'uitest', 'uiInput', 'swipe', '940', '1500', '940', '520', '800')
  await pause()
}

export async function swipeDown() {
  run('shell', 'uitest', 'uiInput', 'swipe', '540', '520', '540', '1500', '800')
  await pause()
}

export function snapshot(name) {
  if (!/^[a-z0-9-]+$/.test(name)) throw new Error('截图名称只能包含小写字母、数字和连字符')
  const remote = `/data/local/tmp/hytys-${name}.jpeg`
  const local = path.join(evidenceDir, `${name}.jpeg`)
  run('shell', 'snapshot_display', '-f', remote)
  run('file', 'recv', remote, local)
  return local
}

export function textSnapshot() {
  return layout().filter((node) => visible(node) && node.text).map((node) => node.text)
}

const [action, ...args] = process.argv.slice(2)
if (action === 'inspect') console.log(JSON.stringify(textSnapshot(), null, 2))
else if (action === 'tap') await tapText(args.join(' '))
else if (action === 'point') await tapPoint(Number(args[0]), Number(args[1]))
else if (action === 'input') await replaceInput(args[0], args.slice(1).join(' '))
else if (action === 'up') await swipeUp()
else if (action === 'down') await swipeDown()
else if (action === 'shot') console.log(snapshot(args[0]))
else if (action) throw new Error(`未知操作：${action}`)
