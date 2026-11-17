import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import assert from 'node:assert/strict';
const root = new URL('../', import.meta.url);
const require = createRequire(new URL('../../../platform/server/package.json', import.meta.url));
const sharp = require('sharp');
const media = new URL('app/entry/src/main/resources/base/media/', root);
const names = fs.readdirSync(media).filter((name) => name.startsWith('bg_') || /^exhibition_(doorgods|auspicious|mythology|craft|spring)\.png$/.test(name)).sort();
assert.equal(names.length, 25);
const hashes = new Set();
const rows = [];
const thumbs = [];
for (const [index, name] of names.entries()) {
  const bytes = fs.readFileSync(new URL(name, media));
  const hash = createHash('sha256').update(bytes).digest('hex');
  assert.ok(!hashes.has(hash), 'Duplicate asset bytes: ' + name);
  hashes.add(hash);
  const meta = await sharp(bytes).metadata();
  assert.ok(meta.width >= 1024 && meta.height >= 1024);
  const sourceMirror = new URL('assets/images/content/' + name, root);
  assert.equal(createHash('sha256').update(fs.readFileSync(sourceMirror)).digest('hex'), hash);
  rows.push({ name, path: 'app/entry/src/main/resources/base/media/' + name, width: meta.width, height: meta.height, format: meta.format, sha256: hash, category: name.startsWith('bg_') ? 'creative-background' : 'exhibition-cover', source: 'project-original-imagegen-built-in', historicalArtifact: false, integrated: true });
  thumbs.push({ input: await sharp(bytes).resize(200, 160, { fit: 'contain', background: '#F7EEDB' }).png().toBuffer(), left: index % 5 * 200, top: Math.floor(index / 5) * 160 });
}
await sharp({ create: { width: 1000, height: 800, channels: 3, background: '#F7EEDB' } }).composite(thumbs).png().toFile(new URL('docs/validation/creative-assets-contact-sheet.png', root).pathname.replace(/^\/(\w:)/, '$1'));
fs.writeFileSync(new URL('docs/validation/creative-assets.json', root), JSON.stringify({ checkedAt: new Date().toISOString(), status: 'pass', assets: rows }, null, 2));
console.log('PASS 25 unique original assets, dimensions and mirrored source hashes');
