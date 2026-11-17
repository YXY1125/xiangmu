import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {APP,PostgresRepository} from '../src/repository.mjs';
import {ArtBusiness} from '../src/service.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const platformPackage=path.resolve(root,'../../platform/server/package.json'),require=createRequire(platformPackage),{Pool}=require('pg');
const url=new URL(process.env.THWKB_PG_TEST_URL||'http://invalid');
assert.ok(url.protocol==='postgresql:'&&url.hostname==='127.0.0.1'&&url.pathname==='/thwkb_qa_local','Only the isolated loopback QA database is allowed');
const seed=JSON.parse(await fs.readFile(path.join(root,'db/seeds/001_content.json'),'utf8'));
const contracts=JSON.parse(await fs.readFile(path.join(root,'server/contracts/entities.json'),'utf8'));
const a={id:'postgres-account-a',tenantId:APP,username:'甲'},b={id:'postgres-account-b',tenantId:APP,username:'乙'},admin={id:'postgres-admin',tenantId:APP,role:'tenant_admin'};
test('actual PostgreSQL migrations, constraints, transactions and business lifecycle',async t=>{
  const schema='thwkb_qa_'+crypto.randomBytes(8).toString('hex'),control=new Pool({connectionString:url.href,max:1});
  assert.match(schema,/^thwkb_qa_[a-f0-9]{16}$/);
  await control.query(`CREATE SCHEMA "${schema}"`);
  const scoped=new URL(url);scoped.searchParams.set('options',`-c search_path=${schema}`);
  const pool=new Pool({connectionString:scoped.href,max:2});
  const repository=await PostgresRepository.connect(scoped.href,seed,contracts,platformPackage),business=new ArtBusiness(repository);
  t.after(async()=>{await repository.pool.end();await pool.end();await control.query(`DROP SCHEMA "${schema}" CASCADE`);await control.end();});
  await t.test('both unchanged app migrations create all 16 entity tables',async()=>{
    for(const file of ['001_init.sql','002_feedback.sql'])await pool.query(await fs.readFile(path.join(root,'db/migrations',file),'utf8'));
    assert.equal((await pool.query('SELECT version FROM thwkb_migrations ORDER BY version')).rows.length,2);
    for(const entity of contracts)assert.ok((await pool.query('SELECT to_regclass($1) AS table_name',[`${schema}.${entity.table}`])).rows[0].table_name);
    // App-owned fixture in an isolated QA schema, never a production import.
    const client=await pool.connect();try{
      await client.query('BEGIN');
      for(const entity of contracts)for(const row of seed.entities[entity.name]){
        const fields=entity.fields.map(f=>`"${f.name}"`).join(',');
        await client.query(`INSERT INTO "${entity.table}" (${fields}) SELECT ${fields} FROM jsonb_populate_record(NULL::"${entity.table}",$1::jsonb)`,[JSON.stringify(row)]);
      }
      await client.query('COMMIT');
    }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
    assert.equal((await business.list('creations',{},a)).total,0);assert.equal((await business.list('plaza',{},null)).total,20);
  });
  let creation;
  const save=(extra={})=>({title:'数据库真实画布',templateId:seed.entities.Template[0].id,document:structuredClone(seed.entities.Template[0].baseLayers),status:'completed',revision:0,...extra});
  await t.test('save and new connection restore every original layer',async()=>{
    creation=await business.saveCreation(a,save({userId:b.id}));
    const restarted=await PostgresRepository.connect(scoped.href,seed,contracts,platformPackage);
    try{assert.deepEqual((await new ArtBusiness(restarted).detail('creations',creation.id,a)).document,creation.document);}finally{await restarted.pool.end();}
  });
  await t.test('trusted A/B identity isolation rejects cross-account reads and updates',async()=>{
    assert.equal((await business.list('creations',{},b)).total,0);
    await assert.rejects(business.detail('creations',creation.id,b),e=>e.status===404);
    await assert.rejects(business.saveCreation(b,save({revision:creation.revision}),creation.id),e=>e.status===404);
  });
  await t.test('independent database connections serialize revision writes with one winner',async()=>{
    const other=await PostgresRepository.connect(scoped.href,seed,contracts,platformPackage);
    try{
      const results=await Promise.allSettled([business.saveCreation(a,save({revision:1,title:'并发甲'}),creation.id),new ArtBusiness(other).saveCreation(a,save({revision:1,title:'并发乙'}),creation.id)]);
      assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.find(r=>r.status==='rejected').reason.status,409);
    }finally{await other.pool.end();}
  });
  await t.test('database enforces unique relations and deferred composite references',async()=>{
    const targetId=seed.entities.Artwork[0].id;await business.favorite(a,{targetType:'artwork',targetId});
    const row=(await pool.query('SELECT row_to_json(r) AS row FROM thwkb_favorites r LIMIT 1')).rows[0].row;
    await assert.rejects(pool.query('INSERT INTO thwkb_favorites SELECT * FROM jsonb_populate_record(NULL::thwkb_favorites,$1::jsonb)',[JSON.stringify({...row,id:crypto.randomUUID()})]),e=>e.code==='23505');
    const raw=(await pool.query('SELECT row_to_json(r) AS row FROM thwkb_creations r LIMIT 1')).rows[0].row;
    await assert.rejects(pool.query('INSERT INTO thwkb_creations SELECT * FROM jsonb_populate_record(NULL::thwkb_creations,$1::jsonb)',[JSON.stringify({...raw,id:crypto.randomUUID(),templateId:crypto.randomUUID()})]),e=>e.code==='23503');
  });
  await t.test('knowledge favorite and history round trip through actual enum constraints',async()=>{
    const targetId=seed.entities.KnowledgeArticle[0].id;
    await business.favorite(a,{targetType:'article',targetId});await business.favorite(a,{targetType:'knowledge',targetId});
    await business.browse(a,{targetType:'article',targetId});await business.browse(a,{targetType:'knowledge',targetId});
    const favorites=await pool.query('SELECT "targetType" FROM thwkb_favorites WHERE "targetId"=$1',[targetId]);
    const history=await pool.query('SELECT "targetType","viewCount" FROM thwkb_browse_history WHERE "targetId"=$1',[targetId]);
    assert.deepEqual(favorites.rows,[{targetType:'knowledge'}]);assert.deepEqual(history.rows,[{targetType:'knowledge',viewCount:2}]);
    assert.equal((await business.detail('knowledge',targetId,a)).favorite,true);
    assert.equal((await business.list('history',{},a)).items[0].targetType,'knowledge');
  });
  await t.test('foreign tenant rows and failed writes cannot alter current app state',async()=>{
    const raw=(await pool.query('SELECT row_to_json(r) AS row FROM thwkb_creations r LIMIT 1')).rows[0].row;
    const foreignTemplate={...seed.entities.Template[0],tenantId:'foreign.test',appId:'foreign.test'};
    await pool.query('INSERT INTO thwkb_templates SELECT * FROM jsonb_populate_record(NULL::thwkb_templates,$1::jsonb)',[JSON.stringify(foreignTemplate)]);
    await pool.query('INSERT INTO thwkb_creations SELECT * FROM jsonb_populate_record(NULL::thwkb_creations,$1::jsonb)',[JSON.stringify({...raw,tenantId:'foreign.test',appId:'foreign.test',title:'不可见记录'})]);
    assert.equal((await business.list('creations',{},a)).total,1);
    const title=(await business.detail('creations',creation.id,a)).title;
    await assert.rejects(repository.transact(s=>{s.entities.Creation[0].title='不应提交';throw new Error('test-only rollback');}));
    assert.equal((await business.detail('creations',creation.id,a)).title,title);
  });
  await t.test('approval, offline, feedback and cancellation retain exact ownership in PostgreSQL',async()=>{
    const work=await business.makeArtwork(a,creation.id,{copyrightDeclaration:'仅测试库中的授权素材夹具'}),publication=await business.submit(a,work.id,{rightsConfirmed:true});
    await assert.rejects(business.detail('artworks',work.id,b),e=>e.status===404);
    await business.review(admin,publication.id,{status:'approved',rightsChecked:true});assert.equal((await business.detail('artworks',work.id,b)).reviewStatus,'approved');
    await business.favorite(b,{targetType:'artwork',targetId:work.id});await business.review(admin,publication.id,{status:'offline',reason:'测试版权复核'});
    assert.equal((await business.list('favorites',{},b)).items[0].available,false);
    const feedback=await business.feedback(a,{category:'bug',body:'测试数据库反馈'});await business.replyFeedback(admin,feedback.id,{status:'replied',reply:'已处理'});
    assert.equal((await business.list('notifications',{},a)).total,3);
    const theirs=await business.saveCreation(b,save());await business.purgeAccount(a);
    assert.equal((await business.list('creations',{},a)).total,0);assert.equal((await business.detail('creations',theirs.id,b)).id,theirs.id);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM thwkb_creations WHERE "tenantId"=$1',['foreign.test'])).rows[0].n,1);
  });
});
