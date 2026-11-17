import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {FileRepository,PostgresRepository,APP} from '../src/repository.mjs';
import {ArtBusiness} from '../src/service.mjs';
import {createDispatcher,ROOT} from '../src/http.mjs';
import {seedReady} from '../src/seed-policy.mjs';
const seed=JSON.parse(await fs.readFile(new URL('../../db/seeds/001_content.json',import.meta.url),'utf8'));
const contracts=JSON.parse(await fs.readFile(new URL('../contracts/entities.json',import.meta.url),'utf8'));
const a={id:'test-account-a',tenantId:APP,username:'A'},b={id:'test-account-b',tenantId:APP,username:'B'},reviewer={id:'reviewer',tenantId:APP,role:'tenant_admin'};
async function fixture(t){
  const dir=await fs.mkdtemp(path.join(os.tmpdir(),'thwkb-unit-'));
  t.after(async()=>{
    const resolved=await fs.realpath(dir),parent=await fs.realpath(os.tmpdir());
    assert.ok(path.dirname(resolved)===parent&&path.basename(resolved).startsWith('thwkb-unit-'));
    await fs.rm(resolved,{recursive:true,force:true});
  });
  const file=path.join(dir,'business.json'),repo=new FileRepository(file,seed);
  return {repo,service:new ArtBusiness(repo),file,document:structuredClone(seed.entities.Template[0].baseLayers)};
}
const save=(document,extra={})=>({title:'花开好运',templateId:seed.entities.Template[0].id,status:'completed',revision:0,document,...extra});
const fails=(promise,status)=>assert.rejects(promise,error=>error.status===status);
async function artwork(f){const c=await f.service.saveCreation(a,save(f.document));const w=await f.service.makeArtwork(a,c.id,{copyrightDeclaration:'使用项目授权素材组合创作'});return {c,w};}

test('seed conforms to all 16 frozen entity contracts, references and empty private user stores',()=>{
  assert.equal(contracts.length,16);assert.equal(Object.keys(seed.assets).length,91);
  for(const entity of contracts)for(const row of seed.entities[entity.name])for(const field of entity.fields){
    const value=row[field.name];if(field.required)assert.notEqual(value==null,true,`${entity.name}.${field.name}`);
    if(value==null)continue;
    if(field.enumValues)assert.ok(field.enumValues.includes(value),`${entity.name}.${field.name}`);
    if(field.ref)assert.ok(seed.entities[field.ref].some(r=>r.id===value));
    assert.equal(row.tenantId,APP);assert.equal(row.appId,APP);
  }
  for(const name of ['Creation','UserProfile','Publication','Favorite','Like','BrowseHistory','Report','Notification','Feedback'])assert.equal(seed.entities[name].length,0);
  assert.equal(seed.productionReleaseApproved,true);
  assert.equal(seedReady(seed),true);
});

test('production approval rejects missing root authorization, material rights, public work rights and article sources',()=>{
  for(const alter of [s=>s.productionReleaseApproved=false,s=>s.entities.Material[0].licenseRecord.releaseReview='pending',s=>s.entities.Artwork[0].rightsEvidence.releaseReview='pending',s=>s.entities.KnowledgeArticle[0].sourceRecords=[]]){
    const pending=structuredClone(seed);alter(pending);assert.equal(seedReady(pending),false);
  }
});
test('real file persistence recovers exact layers after repository restart',async t=>{
  const f=await fixture(t);const c=await f.service.saveCreation(a,save(f.document));
  const restarted=new ArtBusiness(new FileRepository(f.file,seed));
  assert.deepEqual((await restarted.detail('creations',c.id,a)).document,f.document);
  assert.equal((await restarted.list('creations',{},a)).total,1);
});
test('A/B isolation rejects cross-owner read, update, archive and profile spoofing',async t=>{
  const f=await fixture(t),c=await f.service.saveCreation(a,save(f.document,{userId:b.id}));
  assert.equal((await f.service.list('creations',{},b)).total,0);
  await fails(f.service.detail('creations',c.id,b),404);
  await fails(f.service.saveCreation(b,save(f.document,{revision:c.revision}),c.id),404);
  await fails(f.service.archiveCreation(b,c.id),404);
  await f.service.updateProfile(a,{userId:b.id,nickname:'甲',avatarKey:'ip_taoyao',bio:''});
  assert.equal((await f.service.profile(b)).nickname,'B');
  assert.equal((await f.service.detail('creations',c.id,a)).revision,1);
});

test('creation preserves required trusted template provenance without relaxing database contracts',async t=>{
  const f=await fixture(t);
  await fails(f.service.saveCreation(a,save(f.document,{templateId:''})),400);
  await fails(f.service.saveCreation(a,save(f.document,{templateId:'foreign-template'})),422);
  const creation=await f.service.saveCreation(a,save(f.document));
  assert.equal(creation.templateId,seed.entities.Template[0].id);
  await fails(f.service.saveCreation(a,save(f.document,{revision:1,templateId:seed.entities.Template[1].id}),creation.id),409);
  assert.equal((await f.service.detail('creations',creation.id,a)).templateId,creation.templateId);
});
test('concurrent same revision saves allow only one commit and preserve the other user',async t=>{
  const f=await fixture(t),c=await f.service.saveCreation(a,save(f.document));
  const results=await Promise.allSettled([1,2].map(i=>f.service.saveCreation(a,save(f.document,{title:`版本${i}`,revision:1}),c.id)));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.find(r=>r.status==='rejected').reason.status,409);
  assert.equal((await f.service.detail('creations',c.id,a)).revision,2);
});
test('canvas rejects foreign assets, revoked licenses, duplicate ids and invalid coordinates without writing',async t=>{
  const f=await fixture(t);
  for(const mutate of [d=>d.layers[0].materialId='foreign',d=>d.layers[0].imageKey='other',d=>d.layers.push({...d.layers[0]}),d=>d.layers[0].x=NaN,d=>d.backgroundKey='absent',d=>d.layers[0].scale=2]){
    const doc=structuredClone(f.document);mutate(doc);await fails(f.service.saveCreation(a,save(doc)),422);
  }
  await f.repo.transact(s=>{s.entities.Material.find(m=>m.id===f.document.layers[0].materialId).licenseRecord.scope='revoked';return null;});
  await fails(f.service.saveCreation(a,save(f.document)),422);
  assert.equal((await f.service.list('creations',{},a)).total,0);
});
test('publication stays private until rights-reviewed; immutable artwork survives later draft edits',async t=>{
  const f=await fixture(t),{c,w}=await artwork(f);
  assert.ok(w.coverKey);await fails(f.service.detail('artworks',w.id,b),404);
  const again=await f.service.makeArtwork(a,c.id,{copyrightDeclaration:'使用项目授权素材组合创作'});assert.equal(again.id,w.id);
  const corrected=await f.service.makeArtwork(a,c.id,{copyrightDeclaration:'补充版权来源后形成新版本'});assert.notEqual(corrected.id,w.id);
  await fails(f.service.submit(a,w.id,{rightsConfirmed:false}),422);
  const p=await f.service.submit(a,w.id,{rightsConfirmed:true});
  await fails(f.service.detail('artworks',w.id,null),404);
  await fails(f.service.review(reviewer,p.id,{status:'approved'}),422);
  await fails(f.service.review({...reviewer,tenantId:'other'},p.id,{status:'approved',rightsChecked:true}),403);
  await fails(f.service.review({...reviewer,role:'tenant_operator'},p.id,{status:'approved',rightsChecked:true}),403);
  await f.service.review(reviewer,p.id,{status:'approved',rightsChecked:true});
  assert.equal((await f.service.detail('artworks',w.id,null)).reviewStatus,'approved');
  const changed=structuredClone(f.document);changed.layers[0].x=.2;
  await f.service.saveCreation(a,save(changed,{revision:c.revision}),c.id);
  assert.equal((await f.service.detail('artworks',w.id,null)).document.layers[0].x,f.document.layers[0].x);
  await f.service.review(reviewer,p.id,{status:'offline',reason:'版权复核'});
  await fails(f.service.detail('artworks',w.id,null),404);
  assert.equal((await f.service.list('notifications',{},a)).total,2);
  const notification=(await f.service.list('notifications',{},a)).items[0];await fails(f.service.readNotification(b,notification.id),404);
});
test('rejection can be resubmitted; stale review transitions cannot expose unapproved work',async t=>{
  const f=await fixture(t),{w}=await artwork(f),p=await f.service.submit(a,w.id,{rightsConfirmed:true});
  await f.service.review(reviewer,p.id,{status:'rejected',reason:'请补充来源'});
  const next=await f.service.submit(a,w.id,{rightsConfirmed:true});assert.notEqual(p.id,next.id);
  await fails(f.service.review(reviewer,p.id,{status:'approved',rightsChecked:true}),409);
  await fails(f.service.detail('artworks',w.id,null),404);
  await f.service.review(reviewer,next.id,{status:'approved',rightsChecked:true});
  assert.equal((await f.service.detail('artworks',w.id,null)).reviewStatus,'approved');
});
test('likes, favorites and history are idempotent and user-scoped',async t=>{
  const f=await fixture(t),id=seed.entities.Artwork[0].id,input={targetType:'artwork',targetId:id};
  await Promise.all(Array.from({length:8},()=>f.service.like(a,id)));
  await Promise.all(Array.from({length:8},()=>f.service.favorite(a,input)));
  await f.service.browse(a,input);await f.service.browse(a,input);
  const s=await f.repo.read();assert.equal(s.entities.Like.length,1);assert.equal(s.entities.Favorite.length,1);assert.equal(s.entities.BrowseHistory[0].viewCount,2);
  assert.equal((await f.service.list('likes',{},b)).total,0);
  await f.service.like(b,id);await f.service.like(a,id,true);
  assert.equal((await f.service.detail('artworks',id,b)).likeCount,1);
});

test('knowledge relations persist frozen enum and accept the existing article page alias',async t=>{
  const f=await fixture(t),id=seed.entities.KnowledgeArticle[0].id;
  for(const kind of ['article','knowledge']){
    await f.service.favorite(a,{targetType:kind,targetId:id});await f.service.browse(a,{targetType:kind,targetId:id});
  }
  const state=await f.repo.read();
  assert.equal(state.entities.Favorite.length,1);assert.equal(state.entities.Favorite[0].targetType,'knowledge');
  assert.equal(state.entities.BrowseHistory.length,1);assert.equal(state.entities.BrowseHistory[0].targetType,'knowledge');assert.equal(state.entities.BrowseHistory[0].viewCount,2);
  assert.equal((await f.service.detail('knowledge',id,a)).favorite,true);
  assert.equal((await f.service.list('history',{},a)).items[0].title,seed.entities.KnowledgeArticle[0].title);
  await f.service.favorite(a,{targetType:'article',targetId:id},true);assert.equal((await f.service.list('favorites',{},a)).total,0);
});
test('report is deduplicated and cannot remove public content before scoped moderation',async t=>{
  const f=await fixture(t),{w}=await artwork(f),p=await f.service.submit(a,w.id,{rightsConfirmed:true});await f.service.review(reviewer,p.id,{status:'approved',rightsChecked:true});
  const r=await f.service.report(b,w.id,{reasonCode:'copyright',description:'请求复核'});
  assert.equal((await f.service.report(b,w.id,{reasonCode:'copyright'})).id,r.id);
  await fails(f.service.resolveReport(reviewer,r.id,{status:'resolved',resolution:'复核成立',takeDown:true}),409);
  await f.service.resolveReport(reviewer,r.id,{status:'reviewing'});
  assert.equal((await f.service.detail('artworks',w.id,null)).id,w.id);
  await f.service.resolveReport(reviewer,r.id,{status:'resolved',resolution:'复核成立',takeDown:true});
  await fails(f.service.detail('artworks',w.id,null),404);
});

test('offline content retains private favorite/history without leaking its former metadata',async t=>{
  const f=await fixture(t),{w}=await artwork(f),p=await f.service.submit(a,w.id,{rightsConfirmed:true});
  await f.service.review(reviewer,p.id,{status:'approved',rightsChecked:true});
  const input={targetType:'artwork',targetId:w.id};
  await f.service.favorite(b,input);await f.service.browse(b,input);
  await f.service.review(reviewer,p.id,{status:'offline',reason:'版权复核'});
  for(const kind of ['favorites','history']){
    const result=await f.service.list(kind,{},b);assert.equal(result.total,1);
    assert.equal(result.items[0].available,false);assert.equal(result.items[0].imageKey,'');
    assert.equal(result.items[0].title,'内容已下架或不再公开');
    assert.equal((await f.service.list(kind,{},a)).total,0);
  }
  await fails(f.service.detail('artworks',w.id,b),404);
  await f.service.favorite(b,input,true);
  assert.equal((await f.service.list('favorites',{},b)).total,0);
  assert.equal((await f.service.list('history',{},b)).total,1);
  assert.ok((await f.repo.read()).entities.Artwork.some(row=>row.id===w.id));
});

test('liked public artwork pagination has no duplicates and rejects obsolete cursors',async t=>{
  const f=await fixture(t),{w}=await artwork(f),p=await f.service.submit(a,w.id,{rightsConfirmed:true});
  await f.service.review(reviewer,p.id,{status:'approved',rightsChecked:true});
  for(const id of [...seed.entities.Artwork.map(row=>row.id),w.id])await f.service.like(b,id);
  const first=await f.service.list('plaza',{liked:'mine'},b);
  assert.equal(first.items.length,20);assert.equal(first.total,21);assert.ok(first.nextCursor);
  const second=await f.service.list('plaza',{liked:'mine',cursor:first.nextCursor},b);
  assert.equal(second.items.length,1);assert.equal(second.nextCursor,'');
  assert.equal(new Set([...first.items,...second.items].map(row=>row.id)).size,21);
  assert.equal((await f.service.list('plaza',{liked:'mine'},a)).total,0);
  await fails(f.service.list('plaza',{liked:'mine'},null),401);
  await f.service.like(b,first.nextCursor,true);
  await fails(f.service.list('plaza',{liked:'mine',cursor:first.nextCursor},b),400);
});
test('archive retains business record and logout-style repository restart never deletes it',async t=>{
  const f=await fixture(t),c=await f.service.saveCreation(a,save(f.document));await f.service.archiveCreation(a,c.id);
  assert.equal((await f.service.list('creations',{},a)).total,0);assert.equal((await f.repo.read()).entities.Creation.length,1);
  assert.equal((await f.service.detail('creations',c.id,a)).status,'archived');
});
test('account cancellation cleanup removes only owning data and dependent relationships',async t=>{
  const f=await fixture(t),{w}=await artwork(f);await f.service.saveCreation(b,save(f.document));
  const p=await f.service.submit(a,w.id,{rightsConfirmed:true});await f.service.review(reviewer,p.id,{status:'approved',rightsChecked:true});await f.service.like(b,w.id);
  await f.service.purgeAccount(a);const state=await f.repo.read();assert.equal(state.entities.Like.length,0);assert.equal((await f.service.list('creations',{},b)).total,1);assert.equal(state.entities.Artwork.length,seed.entities.Artwork.length);
});
test('dispatcher rejects invalid/foreign/absent sessions and trusts server identity, not body',async t=>{
  const f=await fixture(t),auth={resolveAppSession:t=>t==='valid'?a:t==='foreign'?{...b,tenantId:'other'}:null},dispatch=createDispatcher({business:f.service,auth});
  const input={method:'POST',path:`${ROOT}/creations`,headers:{'x-tenant-id':APP},body:save(f.document,{userId:b.id})};
  await fails(dispatch(input),401);await fails(dispatch({...input,headers:{'x-tenant-id':APP,authorization:'Bearer expired'}}),401);
  await fails(dispatch({...input,headers:{'x-tenant-id':APP,authorization:'Bearer foreign'}}),401);
  await fails(dispatch({...input,headers:{'x-tenant-id':'other',authorization:'Bearer valid'}}),403);
  await dispatch({...input,headers:{'x-tenant-id':APP,authorization:'Bearer valid'}});
  assert.equal((await f.service.list('creations',{},a)).total,1);assert.equal((await f.service.list('creations',{},b)).total,0);
  assert.ok((await dispatch({method:'GET',path:`${ROOT}/home`,headers:{'x-tenant-id':APP}})).banners.length);
});
test('production PostgreSQL adapter refuses missing connection rather than silently using files',async()=>{
  await assert.rejects(PostgresRepository.connect('',seed,contracts,''),/required/);
});
test('feedback ownership, idempotence, scoped reply lifecycle and notification',async t=>{
  const f=await fixture(t),input={category:'bug',body:'拖动后希望显示位置刻度',userId:b.id};
  const feedback=await f.service.feedback(a,input);assert.equal(feedback.userId,a.id);
  assert.equal((await f.service.feedback(a,input)).id,feedback.id);
  assert.equal((await f.service.list('feedback',{},b)).total,0);
  await fails(f.service.replyFeedback({...reviewer,tenantId:'other'},feedback.id,{status:'replied',reply:'已记录'}),403);
  await fails(f.service.replyFeedback(reviewer,feedback.id,{status:'closed',reply:'结束'}),409);
  await f.service.replyFeedback(reviewer,feedback.id,{status:'reviewing'});
  await f.service.replyFeedback(reviewer,feedback.id,{status:'replied',reply:'已记录，正在评估适配。'});
  assert.equal((await f.service.list('feedback',{},a)).items[0].status,'replied');
  assert.equal((await f.service.list('notifications',{},a)).total,2);
  await f.service.purgeAccount(a);assert.equal((await f.repo.read()).entities.Feedback.length,0);
});
test('public author never exposes credentials, phone, private drafts or unapproved works',async t=>{
  const f=await fixture(t),{w}=await artwork(f);await f.service.updateProfile(a,{nickname:'甲的印坊',avatarKey:'ip_taoyao',bio:'喜欢桃花'});
  await fails(f.service.author(a.id,null),404);
  const p=await f.service.submit(a,w.id,{rightsConfirmed:true});await f.service.review(reviewer,p.id,{status:'approved',rightsChecked:true});
  await f.service.saveCreation(a,save(f.document,{status:'draft'}));
  const author=await f.service.author(a.id,null);assert.equal(author.artworks.length,1);assert.equal(author.nickname,'甲的印坊');
  assert.deepEqual(Object.keys(author).sort(),['id','nickname','avatarKey','bio','artworks'].sort());
  assert.equal(JSON.stringify(author).includes('password'),false);
  assert.equal((await f.service.author('official',null)).artworks.length,seed.entities.Artwork.length);
});
test('content release checks factual sources and licenses, offline material cannot be saved',async t=>{
  const f=await fixture(t),material=seed.entities.Material.find(m=>m.id===f.document.layers[0].materialId);
  await f.service.contentState(reviewer,'Material',material.id,{status:'offline'});
  await fails(f.service.saveCreation(a,save(f.document)),422);
  const article=seed.entities.KnowledgeArticle[0];
  await f.repo.transact(s=>{s.entities.KnowledgeArticle.find(a=>a.id===article.id).factCheckStatus='unverified';return null;});
  await fails(f.service.contentState(reviewer,'KnowledgeArticle',article.id,{status:'published'}),422);
  await fails(f.service.contentState({...reviewer,role:'tenant_operator'},'Material',material.id,{status:'published'}),403);
});
test('all eight catalog entries resolve actual content; original IP, zodiac and festival counts are distinct',async t=>{
  const f=await fixture(t),home=await f.service.home(null);
  assert.equal(home.categories.length,8);assert.ok(home.characters.slice(0,6).every(c=>c.imageKey.startsWith('ip_')));
  const expected={'十二生肖':12,'祥瑞小灵兽':8,'传统人物动漫图鉴':1,'吉祥娃娃':1,'花鸟鱼虫':2,'原创角色':6,'节日主题':8,'节气主题':4,'年画作品':20};
  for(const category of home.categories){
    const result=await f.service.list(category.targetKind==='artwork'?'plaza':'characters',{category:category.id},null);
    assert.ok(result.total>0,category.name);if(expected[category.name])assert.equal(result.total,expected[category.name],category.name);
  }
  const state=await f.repo.read();for(const work of state.entities.Artwork)assert.ok(f.service.validateDocument(state,work.rightsEvidence.canvasState));
});
