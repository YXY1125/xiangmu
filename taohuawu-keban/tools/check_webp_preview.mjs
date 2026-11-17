import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(path.resolve(root,'../../platform/server/package.json')),sharp=require('sharp');
const registry=JSON.parse(await fs.readFile(path.join(root,'docs/validation/engineering-images.json'),'utf8'));
const output=path.join(root,'.runtime/encoding-qa');await fs.mkdir(output,{recursive:true});
for(const key of ['ip_taoyao','banner_taohua_print_studio','sticker_seal']){
  const row=registry.assets.find(a=>a.key===key);
  // QA-only opaque composites avoid viewer-specific rendering of invisible RGB under alpha=0.
  // They are never artwork assets or included in the application.
  await sharp(path.join(root,row.source)).flatten({background:'#FFF8F0'}).png().toFile(path.join(output,`${key}-original.png`));
  await sharp(path.join(root,row.file)).flatten({background:'#FFF8F0'}).png().toFile(path.join(output,`${key}-webp.png`));
}
console.log('Three original/derived QA composites generated in ignored .runtime/encoding-qa.');
