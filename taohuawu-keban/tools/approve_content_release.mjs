import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {seedReady} from '../server/src/seed-policy.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const record='docs/product/content-release-authorization.md';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=async p=>JSON.parse(await fs.readFile(path.join(root,p),'utf8'));
const authorization=await fs.readFile(path.join(root,record));
if(!authorization.toString().includes('所有素材都是你生成的呀，你保存到哪里了，就从哪里上传'))throw Error('Explicit project production-use authorization required');
const images=await read('docs/validation/engineering-images.json'), integrity=await read('docs/validation/image-integrity.json');
if(images.status!=='pass'||integrity.status!=='pass'||images.total!==91||integrity.total!==91)throw Error('Verified existing image inventory required');
const assets=[];
for(const asset of images.assets){
  const original=integrity.assets.find(a=>a.key===asset.key);
  if(!original||asset.source!==original.file||asset.sourceSha256!==original.sha256)throw Error('Image provenance differs');
  for(const [file,sha] of [[asset.source,asset.sourceSha256],[asset.file,asset.sha256]])if(hash(await fs.readFile(path.join(root,file)))!==sha)throw Error('Actual image differs from reviewed inventory');
  assets.push({key:asset.key,png:asset.source,pngSha256:asset.sourceSha256,webp:asset.file,webpSha256:asset.sha256});
}
const seed=await read('db/seeds/001_content.json');
if(Object.values(seed.entities).flat().some(r=>r.tenantId!=='thwkb.zh.huawei'||r.appId!=='thwkb.zh.huawei'))throw Error('Foreign seed rejected');
const allowed=['Category','Character','Topic','KnowledgeArticle','Material','Template','Artwork'];
if(Object.entries(seed.entities).some(([kind,rows])=>!allowed.includes(kind)&&rows.length)||seed.entities.Artwork.some(r=>r.ownerUserId))throw Error('Private user data must not be released');
for(const material of seed.entities.Material){
  const asset=seed.assets[material.assetId], verified=assets.find(a=>a.key===asset?.key);
  if(!verified||verified.pngSha256!==material.licenseRecord?.sha256)throw Error('Material source is not verified');
  material.copyrightOwner='黑龙江省众富信息科技有限公司（本项目生成素材使用管理主体，非权利登记证明）';
  material.licenseRecord={...material.licenseRecord,releaseReview:'approved',releaseRecord:record,permissionBasis:'项目用户于2026-11-11明确授权将本项目生成素材上传用于本应用'};
}
for(const artwork of seed.entities.Artwork){
  if(!artwork.rightsEvidence?.canvasState)throw Error('Official work requires a recoverable snapshot');
  artwork.rightsEvidence={...artwork.rightsEvidence,releaseReview:'approved',releaseRecord:record};
  artwork.copyrightDeclaration='本项目 imagegen 生成的现代原创视觉组合；项目用户已授权用于本应用，来源与使用记录见图片台账及生产使用授权。非传统年画原作、非著作权登记证明。';
}
seed.mode='authorized-production-content';seed.productionReleaseApproved=true;
if(!seedReady(seed))throw Error('Content release policy rejected the source, rights or fact records');
const bytes=JSON.stringify(seed,null,2)+'\n';
await fs.writeFile(path.join(root,'db/seeds/001_content.json'),bytes);
const report={at:new Date().toISOString(),app:'thwkb.zh.huawei',decision:'approved-for-project-production-use',basis:'explicit-project-user-instruction',authorizationRecord:record,authorizationSha256:hash(authorization),externalLegalReviewClaim:false,legalRegistrationClaim:false,assets,seedSha256:hash(bytes),publicCounts:Object.fromEntries(allowed.map(k=>[k,seed.entities[k].length])),privateSeedRows:0,productionImportExecuted:false};
await fs.writeFile(path.join(root,'docs/validation/content-release-approval.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({decision:report.decision,verifiedAssets:assets.length,publicCounts:report.publicCounts,privateSeedRows:0,productionImportExecuted:false}));
