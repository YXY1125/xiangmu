import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(process.argv[2]||'apps/thwkb.zh.huawei');
const spec=JSON.parse(fs.readFileSync(path.join(root,'AppSpec.json'),'utf8'));
const lines=["/** Generated from the verified AppSpec image registry. */",'export class MediaCatalog {','  static image(key: string): Resource | undefined {'];
for(const asset of spec.brand.visualAssets){
  if(!/^[a-z][a-z0-9_]*$/.test(asset.key))throw new Error('Invalid resource key');
  lines.push(`    if (key === '${asset.key}') return $r('app.media.${asset.key}')`);
}
lines.push('    return undefined','  }','}');
fs.writeFileSync(path.join(root,'app/entry/src/main/ets/models/MediaCatalog.ets'),lines.join('\n')+'\n');
console.log(`Generated ${spec.brand.visualAssets.length} explicit resource mappings`);
