import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {seedReady} from '../server/src/seed-policy.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const seed=JSON.parse(await fs.readFile(path.join(root,'db/seeds/001_content.json'),'utf8'));
const contracts=JSON.parse(await fs.readFile(path.join(root,'server/contracts/entities.json'),'utf8'));
const privateKinds=['UserProfile','Creation','Publication','Favorite','Like','BrowseHistory','Report','Notification','Feedback'];
if(privateKinds.some(kind=>seed.entities[kind].length>0)||seed.entities.Artwork.some(row=>row.ownerUserId))throw new Error('Private user data must never be included in a release seed');
const quote=name=>{if(!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(name))throw new Error('Unsafe identifier');return `"${name}"`;};
const approved=seedReady(seed);
let sql='-- Generated from reviewed JSON content. No user activity or credentials.\n-- Production import is blocked until root approval and every rights record are approved.\nBEGIN;\n';
if(!approved)sql+="DO $thwkb_guard$ BEGIN RAISE EXCEPTION 'THWKB content release approval is pending; no seed was imported'; END $thwkb_guard$;\n";
let records=0;
for(const entity of contracts)for(const row of seed.entities[entity.name]){
  if(row.tenantId!=='thwkb.zh.huawei'||row.appId!=='thwkb.zh.huawei')throw new Error('Foreign seed rejected');
  const fields=entity.fields.map(f=>quote(f.name)).join(',');
  const json=JSON.stringify(row).replaceAll("'","''");
  sql+=`INSERT INTO ${quote(entity.table)} (${fields}) SELECT ${fields} FROM jsonb_populate_record(NULL::${quote(entity.table)},'${json}'::jsonb) ON CONFLICT ("tenantId","appId",id) DO NOTHING;\n`;
  records++;
}
sql+='COMMIT;\n';await fs.writeFile(path.join(root,'db/seeds/001_seed.sql'),sql);
console.log(JSON.stringify({records,releaseApproval:approved?'approved':'blocked',executed:false}));
