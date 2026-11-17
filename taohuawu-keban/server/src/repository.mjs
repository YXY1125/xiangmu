import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';

export const APP = 'thwkb.zh.huawei';
const clone = value => structuredClone(value);

/** Explicit development persistence, never selected as a production fallback. */
export class FileRepository {
  constructor(filename, seed) { this.filename=path.resolve(filename); this.seed=clone(seed); this.queue=Promise.resolve(); }
  async read() {
    try { return JSON.parse(await fs.readFile(this.filename,'utf8')); }
    catch(error) { if(error.code==='ENOENT')return clone(this.seed); throw error; }
  }
  async transact(operation) {
    const task=this.queue.then(async()=>{
      const state=await this.read();
      const result=await operation(state);
      await fs.mkdir(path.dirname(this.filename),{recursive:true});
      const temporary=`${this.filename}.${crypto.randomUUID()}.pending`;
      const file=await fs.open(temporary,'wx',0o600);
      try { await file.writeFile(JSON.stringify(state)); await file.sync(); } finally { await file.close(); }
      await fs.rename(temporary,this.filename);
      return clone(result);
    });
    this.queue=task.then(()=>{},()=>{});
    return task;
  }
}

/** Production PostgreSQL adapter. Missing connection is an error, never a file fallback. */
export class PostgresRepository {
  constructor(pool, seed, contracts) { this.pool=pool; this.seed=clone(seed); this.contracts=contracts; }
  static async connect(connectionString, seed, contracts, platformPackage) {
    if(!connectionString)throw new Error('THWKB_DATABASE_URL is required for PostgreSQL');
    const require=createRequire(platformPackage);
    const {Pool}=require('pg');
    const pool=new Pool({connectionString,max:6,connectionTimeoutMillis:8000});
    try { await pool.query('SELECT 1'); }
    catch { await pool.end();throw new Error('PostgreSQL connection unavailable'); }
    return new PostgresRepository(pool,seed,contracts);
  }
  async readWith(client) {
    const snapshot=clone(this.seed);
    for(const entity of this.contracts){
      const result=await client.query(`SELECT row_to_json(record) AS value FROM "${entity.table}" record WHERE "tenantId"=$1 AND "appId"=$2`,[APP,APP]);
      snapshot.entities[entity.name]=result.rows.map(row=>row.value);
    }
    return snapshot;
  }
  async read() {
    const client=await this.pool.connect();
    try { await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');const state=await this.readWith(client);await client.query('COMMIT');return state; }
    catch(error){await client.query('ROLLBACK');throw error;}finally{client.release();}
  }
  async transact(operation) {
    const client=await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))',[APP]);
      const state=await this.readWith(client),before=clone(state);
      const result=await operation(state);
      for(const entity of this.contracts){
        const previous=new Map(before.entities[entity.name].map(row=>[row.id,row]));
        const nextIds=new Set(state.entities[entity.name].map(row=>row.id));
        for(const old of previous.values())if(!nextIds.has(old.id)){
          await client.query(`DELETE FROM "${entity.table}" WHERE "tenantId"=$1 AND "appId"=$2 AND id=$3`,[APP,APP,old.id]);
        }
        const fields=entity.fields.map(field=>field.name),quoted=fields.map(name=>`"${name}"`).join(',');
        const updates=fields.filter(name=>!['tenantId','appId','id'].includes(name)).map(name=>`"${name}"=EXCLUDED."${name}"`).join(',');
        for(const row of state.entities[entity.name]){
          if(JSON.stringify(previous.get(row.id))===JSON.stringify(row))continue;
          if(row.tenantId!==APP||row.appId!==APP)throw new Error('Cross-scope persistence rejected');
          await client.query(`INSERT INTO "${entity.table}" (${quoted}) SELECT ${quoted} FROM jsonb_populate_record(NULL::"${entity.table}",$1::jsonb) ON CONFLICT ("tenantId","appId",id) DO UPDATE SET ${updates}`,[JSON.stringify(row)]);
        }
      }
      await client.query('COMMIT');return clone(result);
    }catch(error){await client.query('ROLLBACK');throw error;}finally{client.release();}
  }
}
