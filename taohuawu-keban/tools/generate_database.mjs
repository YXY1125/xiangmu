import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(process.argv[2]||'apps/thwkb.zh.huawei');
const spec=JSON.parse(fs.readFileSync(path.join(root,'AppSpec.json'),'utf8'));
if(fs.existsSync(path.join(root,'db/migrations/001_init.sql')))throw new Error('Migration001 already exists. Preserve history; new entities require an incremental migration.');
const quote=value=>{if(!/^[A-Za-z][A-Za-z0-9_]*$/.test(value))throw new Error('Invalid identifier');return `"${value}"`;};
const types={uuid:'uuid',string:'text',text:'text',enum:'text',json:'jsonb',int:'integer',number:'numeric',float:'double precision',boolean:'boolean',datetime:'timestamptz',date:'date'};
let sql='-- App-owned PostgreSQL migration derived from frozen AppSpec. Never modifies platform tables.\nBEGIN;\n';
for(const entity of spec.entities){
  const columns=entity.fields.map(field=>{
    const type=types[field.type];if(!type)throw new Error(`Unknown type ${field.type}`);
    let definition=`  ${quote(field.name)} ${type}${field.required?' NOT NULL':''}`;
    if(field.enumValues?.length)definition+=` CHECK (${quote(field.name)} IN (${field.enumValues.map(v=>`'${v.replaceAll("'","''")}'`).join(', ')}))`;
    return definition;
  });
  columns.push('  PRIMARY KEY ("tenantId", "appId", "id")');
  sql+=`CREATE TABLE IF NOT EXISTS ${quote(entity.table)} (\n${columns.join(',\n')}\n);\n`;
  for(let i=0;i<(entity.indexes||[]).length;i++){
    sql+=`CREATE INDEX IF NOT EXISTS ${quote(`${entity.table}_q${i}`)} ON ${quote(entity.table)} (${entity.indexes[i].map(quote).join(', ')});\n`;
  }
}
for(const entity of spec.entities){
  for(const field of entity.fields.filter(f=>f.ref)){
    const target=spec.entities.find(e=>e.name===field.ref);if(!target)throw new Error('Missing referenced entity');
    sql+=`ALTER TABLE ${quote(entity.table)} ADD CONSTRAINT ${quote(`${entity.table}_${field.name}_fk`)} FOREIGN KEY ("tenantId", "appId", ${quote(field.name)}) REFERENCES ${quote(target.table)} ("tenantId", "appId", "id") DEFERRABLE INITIALLY DEFERRED;\n`;
  }
}
for(const [table,fields] of [
  ['thwkb_user_profiles',['tenantId','appId','userId']],
  ['thwkb_favorites',['tenantId','appId','userId','targetType','targetId']],
  ['thwkb_likes',['tenantId','appId','userId','artworkId']],
  ['thwkb_browse_history',['tenantId','appId','userId','targetType','targetId']]
])sql+=`CREATE UNIQUE INDEX IF NOT EXISTS ${quote(`${table}_business_unique`)} ON ${quote(table)} (${fields.map(quote).join(', ')});\n`;
sql+='CREATE TABLE IF NOT EXISTS thwkb_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());\nINSERT INTO thwkb_migrations(version) VALUES (\'001\');\nCOMMIT;\n';
fs.mkdirSync(path.join(root,'db/migrations'),{recursive:true});
fs.writeFileSync(path.join(root,'db/migrations/001_init.sql'),sql);
fs.mkdirSync(path.join(root,'server/contracts'),{recursive:true});
fs.writeFileSync(path.join(root,'server/contracts/entities.json'),JSON.stringify(spec.entities,null,2)+'\n');
console.log(`Generated ${spec.entities.length} PostgreSQL business tables with constraints; not yet applied`);
