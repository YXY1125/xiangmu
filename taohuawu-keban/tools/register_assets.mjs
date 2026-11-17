import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root = path.resolve(process.argv[2] || 'apps/thwkb.zh.huawei');
const audit = JSON.parse(fs.readFileSync(path.join(root, 'docs/validation/image-integrity.json'), 'utf8'));
if (audit.status !== 'pass' || audit.total !== 91) throw new Error('Verified 91-image audit required');
const specPath = path.join(root, 'AppSpec.json');
const freezePath = path.join(root, 'APPSPEC_FREEZE.json');
const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));
const freeze = JSON.parse(fs.readFileSync(freezePath, 'utf8'));
const labels = {
  fan: '折扇', seal: '花印', scroll: '空白卷轴', roller: '滚筒', ink_bowl: '朱砂碗', woodblock: '桃花木版',
  baren: '拓印垫', pigment: '颜料瓶', brush: '画笔', butterfly: '蝴蝶', koi: '锦鲤', swallow: '燕子',
  ginkgo: '银杏叶', ribbon: '丝带', bell: '花铃', envelope: '祝福信封', peach_blossoms: '桃花簇',
  petals: '花瓣', peony: '牡丹', lotus: '莲花', osmanthus: '桂花', plum_snow: '梅雪', cloud: '祥云',
  wave: '水浪', moon: '月亮', sun: '太阳', stars: '星簇', lantern: '桃灯', knot: '花结', tassel: '流苏',
  search: '搜索无结果', favorites: '收藏为空', drafts: '草稿为空', notifications: '通知为空', network: '网络异常'
};
const existing = new Map(spec.brand.visualAssets.map(a => [a.key, a]));
function usage(a) {
  if (existing.has(a.key)) return existing.get(a.key).usage;
  if (a.key.startsWith('sticker_')) return `工坊透明贴纸：${labels[a.key.slice(8)]}`;
  if (a.key.startsWith('empty_')) return `空状态插画：${labels[a.key.slice(6)]}`;
  if (a.key.startsWith('zodiac_')) return `生肖图鉴与工坊角色：${a.key}`;
  if (a.key.startsWith('beast_')) return `祥瑞图鉴与工坊角色：${a.key}`;
  if (a.key.startsWith('festival_')) return `节日主题现代原创场景：${a.key}`;
  if (a.key.startsWith('cover_')) return `图鉴分类封面：${a.key}`;
  return `工坊可组合背景：${a.key}`;
}
spec.brand.visualAssets = audit.assets.map(a => ({key:a.key, file:a.file, usage:usage(a), source:'OpenAI imagegen 原创生成', status:'active'}));
const contents = JSON.stringify(spec, null, 2) + '\n';
const before = fs.readFileSync(specPath, 'utf8');
if (before !== contents) {
  const previous = {...freeze};
  fs.mkdirSync(path.join(root, 'docs/validation/history'), {recursive:true});
  fs.writeFileSync(path.join(root, 'docs/validation/history/APPSPEC_FREEZE-before-assets.json'), JSON.stringify(previous,null,2)+'\n');
  fs.writeFileSync(specPath, contents);
  freeze.version = '1.2';
  freeze.previousChecksum = previous.checksum;
  freeze.checksum = crypto.createHash('sha256').update(contents).digest('hex');
  freeze.changeRecord = 'docs/product/change-request-002-complete-assets.md';
  freeze.assetRegistrationAt = new Date().toISOString();
  fs.writeFileSync(freezePath, JSON.stringify(freeze,null,2)+'\n');
}
let manifest = fs.readFileSync(path.join(root,'docs/ImageManifest.md'),'utf8');
manifest = manifest.split('## 待继续生产')[0].split('## 透明贴纸与空状态补充台账')[0].trimEnd();
manifest += '\n\n## 透明贴纸与空状态补充台账\n\n';
manifest += '| 文件名 | 模块/用途 | 来源与权利记录 | 尺寸 | 格式 | SHA-256 | 状态 |\n|---|---|---|---|---|---|---|\n';
for (const a of audit.assets.filter(a=>a.group==='sticker'||a.group==='empty')) {
  manifest += `| ${a.key}.png | ${usage(a)} | OpenAI imagegen 原创生成；项目归档使用，发布归属见版权记录 | ${a.width}×${a.height} | PNG RGBA | ${a.sha256} | active |\n`;
}
manifest += '\n## 数量与检查结果\n\n';
manifest += '已落盘 91 个独立文件：Banner 4、核心 IP 6、生肖新增 11（团团兼任生肖兔，合计 12）、祥瑞新增 7（霁麟计入总数，合计 8）、节日插画 8、图鉴封面 8、工坊背景 12、透明贴纸 30、空状态 5。未重复复制兼任角色凑数。\n\n';
manifest += '完整机器台账与文件检查见 docs/validation/image-integrity.json，含尺寸、字节数、哈希、Alpha 极值与比例、工程副本校验。图片生成采用内置 imagegen，每个独立素材单独调用。核心提示词：现代原创萌系国潮、轻木刻纸纹、项目色板、指定主体、无文字/水印/他人作品复刻；角色/贴纸/空状态要求真实透明 Alpha，背景保留画布中央安全区。完整批次主体清单由本台账和 AppSpec.brand.visualAssets 保存。\n';
fs.writeFileSync(path.join(root,'docs/ImageManifest.md'),manifest);
console.log(JSON.stringify({registered:spec.brand.visualAssets.length,freezeChecksum:freeze.checksum}));
