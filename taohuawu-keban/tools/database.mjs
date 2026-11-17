import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import crypto from 'node:crypto';
import {seedReady} from '../server/src/seed-policy.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const command=process.argv[2];
if(!['check','migrate','seed-approved'].includes(command))throw new Error('Usage: database.mjs check|migrate|seed-approved');
if(!process.env.THWKB_DATABASE_URL){console.error('BLOCKED: THWKB_DATABASE_URL is not configured; no database action performed.');process.exit(2);}
const require=createRequire(path.resolve(root,'../../platform/server/package.json'));
const {Pool}=require('pg');
const pool=new Pool({connectionString:process.env.THWKB_DATABASE_URL,connectionTimeoutMillis:8000,max:1});
const contracts=JSON.parse(await fs.readFile(path.join(root,'server/contracts/entities.json'),'utf8'));
const client=await pool.connect().catch(()=>null);
if(!client){await pool.end();console.error('BLOCKED: PostgreSQL connection unavailable; connection details suppressed.');process.exit(2);}
try {
  if(command==='check'){
    const result=await client.query('SELECT current_setting(\'server_version_num\') AS version');
    console.log(JSON.stringify({database:'PostgreSQL',connected:true,version:result.rows[0].version}));
  }else if(command==='migrate'){
    await client.query('SELECT pg_advisory_lock(hashtext($1))',['thwkb.zh.huawei:migrations']);
    try {
      const existing=await client.query("SELECT to_regclass('thwkb_migrations') AS registry");
      const versions=existing.rows[0].registry?(await client.query('SELECT version FROM thwkb_migrations')).rows.map(r=>r.version):[];
      const files=(await fs.readdir(path.join(root,'db/migrations'))).filter(f=>/^\d{3}_[a-z_]+\.sql$/.test(f)).sort();
      for(const file of files){
        const version=file.slice(0,3);if(versions.includes(version)){console.log(`Migration ${version}: already applied`);continue;}
        const sql=await fs.readFile(path.join(root,'db/migrations',file),'utf8');
        await client.query(sql);console.log(`Migration ${version}: applied, sha256 ${crypto.createHash('sha256').update(sql).digest('hex')}`);
      }
    }finally{await client.query('SELECT pg_advisory_unlock(hashtext($1))',['thwkb.zh.huawei:migrations']);}
  }else{
    const seed=JSON.parse(await fs.readFile(path.join(root,'db/seeds/001_content.json'),'utf8'));
    if(!seedReady(seed))throw new Error('Unapproved content seed');
    await client.query('BEGIN');
    for(const entity of contracts)for(const row of seed.entities[entity.name]){
      if(row.tenantId!=='thwkb.zh.huawei'||row.appId!=='thwkb.zh.huawei')throw new Error('Cross-scope seed');
      const columns=entity.fields.map(f=>`"${f.name}"`).join(',');
      await client.query(`INSERT INTO "${entity.table}" (${columns}) SELECT ${columns} FROM jsonb_populate_record(NULL::"${entity.table}",$1::jsonb) ON CONFLICT ("tenantId","appId",id) DO NOTHING`,[JSON.stringify(row)]);
    }
    await client.query('COMMIT');console.log('Approved public content imported; existing records never overwritten.');
  }
}catch{
  await client.query('ROLLBACK').catch(()=>{});
  console.error('FAILED: Database action did not complete. Verify migration/schema/content approval; sensitive diagnostics suppressed.');process.exitCode=1;
}finally{client.release();await pool.end();}
