import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(path.resolve(root,'../../platform/server/package.json')),sharp=require('sharp');
sharp.concurrency(2);
const audit=JSON.parse(await fs.readFile(path.join(root,'docs/validation/image-integrity.json'),'utf8'));
if(audit.status!=='pass'||audit.total!==91)throw new Error('Verified originals required');
await fs.mkdir(path.join(root,'.runtime'),{recursive:true});
const staging=await fs.mkdtemp(path.join(root,'.runtime/webp-'));
const hash=buffer=>crypto.createHash('sha256').update(buffer).digest('hex');
const media=path.join(root,'app/entry/src/main/resources/base/media'),rows=[];
function compare(source,encoded){
  let alphaMaxDiff=0,error=0,weight=0;
  for(let i=0;i<source.length;i+=4){
    alphaMaxDiff=Math.max(alphaMaxDiff,Math.abs(source[i+3]-encoded[i+3]));
    const alpha=source[i+3]/255;
    for(let c=0;c<3;c++){error+=(source[i+c]-encoded[i+c])**2*alpha;weight+=alpha;}
  }
  const mse=error/Math.max(weight,1);return {alphaMaxDiff,psnr:mse===0?'lossless':Math.round(10*Math.log10(255**2/mse)*100)/100};
}
for(const asset of audit.assets){
  const original=await fs.readFile(path.join(root,asset.file));if(hash(original)!==asset.sha256)throw new Error('Original changed after audit');
  const source=await sharp(original).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const quality=asset.group==='sticker'?95:92;
  let encoded=await sharp(original).webp({quality,alphaQuality:100,effort:5,smartSubsample:true}).toBuffer(),lossless=false;
  let decoded=await sharp(encoded).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let metrics=compare(source.data,decoded.data);
  if(metrics.alphaMaxDiff!==0||typeof metrics.psnr==='number'&&metrics.psnr<38){
    encoded=await sharp(original).webp({lossless:true,effort:5}).toBuffer();lossless=true;
    decoded=await sharp(encoded).ensureAlpha().raw().toBuffer({resolveWithObject:true});metrics=compare(source.data,decoded.data);
  }
  if(source.info.width!==decoded.info.width||source.info.height!==decoded.info.height||metrics.alphaMaxDiff!==0)throw new Error('Dimensions or alpha changed');
  await fs.writeFile(path.join(staging,`${asset.key}.webp`),encoded);
  rows.push({key:asset.key,source:asset.file,sourceSha256:asset.sha256,sourceBytes:original.length,file:`app/entry/src/main/resources/base/media/${asset.key}.webp`,sha256:hash(encoded),bytes:encoded.length,width:decoded.info.width,height:decoded.info.height,quality:lossless?'lossless':quality,...metrics});
  if(rows.length%10===0)console.log(`Verified ${rows.length}/91 derived WebP files`);
}
// Only replace exact verified copies; preserve all originals and recoverable engineering copies.
const archive=path.join(root,'.runtime/original-media-png');await fs.mkdir(archive,{recursive:true});
for(const row of rows){
  const originalCopy=path.join(media,`${row.key}.png`),archivedCopy=path.join(archive,`${row.key}.png`);
  if(!path.resolve(originalCopy).startsWith(`${root}${path.sep}`)||!path.resolve(archivedCopy).startsWith(`${root}${path.sep}`))throw new Error('Out-of-app path');
  const png=await fs.readFile(originalCopy).catch(error=>{if(error.code==='ENOENT')return null;throw error;});
  if(png){if(hash(png)!==row.sourceSha256)throw new Error('Existing media differs; preserving user file');await fs.rename(originalCopy,archivedCopy);}
  await fs.copyFile(path.join(staging,`${row.key}.webp`),path.join(root,row.file));
}
const sourceBytes=rows.reduce((n,r)=>n+r.sourceBytes,0),bytes=rows.reduce((n,r)=>n+r.bytes,0);
const result={status:'pass',generatedAt:new Date().toISOString(),authorization:'User explicitly approved deterministic WebP engineering copies, 2026-11-11',scope:'encoding only; no redraw/crop/resize; not new original artwork or Gate C',originalsPreserved:true,total:rows.length,sourceBytes,bytes,reductionPercent:Math.round((1-bytes/sourceBytes)*10000)/100,assets:rows};
await fs.writeFile(path.join(root,'docs/validation/engineering-images.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({total:rows.length,sourceBytes,bytes,reductionPercent:result.reductionPercent}));
