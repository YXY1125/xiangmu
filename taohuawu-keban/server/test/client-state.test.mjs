import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const require=createRequire(path.resolve(root,'../../platform/server/package.json')),ts=require('typescript');
// Native API test doubles are confined to this unit test. App/network code has no fallback.
function client(httpOverrides={}){
  const storage=new Map(),disk=new Map(),cache=new Map();
  const temporaryFiles=new Set(),removedFiles=[];
  const snapshots=[],released=[];
  const nativeRequests=[];
  const fileIo={listFile:async()=>[...temporaryFiles],stat:async()=>({isFile:()=>true}),unlink:async filename=>{removedFiles.push(filename);temporaryFiles.delete(filename.split('/').pop());}};
  const preference={get:async(k,d)=>disk.has(k)?disk.get(k):d,put:async(k,v)=>{disk.set(k,v);},flush:async()=>{}};
  const AppStorage={get:k=>storage.get(k),setOrCreate:(k,v)=>storage.set(k,v)};
  const http={getToken:()=>storage.get('accessToken')||'',tenantId:()=> 'thwkb.zh.huawei',get:async()=>{throw new Error('Unit test forbids network');},...httpOverrides};
  const stubs={
    '@kit.ArkData':{preferences:{getPreferences:async()=>preference}},
    '@kit.PerformanceAnalysisKit':{hilog:{info(){},error(){}}},
    '@kit.AbilityKit':{},
    'BuildProfile':{default:{DEBUG:true}},
    '@kit.NetworkKit':{http:{RequestMethod:{GET:'GET',POST:'POST',PUT:'PUT',DELETE:'DELETE'},HttpDataType:{STRING:'STRING'},createHttp:()=>({request:async(url,config)=>{nativeRequests.push({url,config});return {responseCode:200,result:JSON.stringify({code:0,data:{}})};},destroy(){}})}},
    '@kit.ArkUI':{componentSnapshot:{get:async(id,options)=>{snapshots.push({id,options});return {release:()=>released.push('pixels')};}}},
    '@kit.ImageKit':{image:{createImagePacker:()=>({packing:async()=>new ArrayBuffer(8),release:()=>released.push('packer')})}},
    '@kit.CoreFileKit':{fileIo,picker:{DocumentSaveOptions:class{},DocumentViewPicker:class{async save(){return [];}}}},'@kit.ShareKit':{},
  };
  function load(relative){
    const filename=path.join(root,'app/entry/src/main/ets',relative+'.ets');
    if(cache.has(filename))return cache.get(filename).exports;
    const module={exports:{}};cache.set(filename,module);
    const js=ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS},fileName:filename}).outputText;
    const localRequire=specifier=>{
      if(stubs[specifier])return stubs[specifier];
      if(specifier.endsWith('/HttpClient'))return {HttpClient:http};
      if(specifier.startsWith('.'))return load(path.relative(path.join(root,'app/entry/src/main/ets'),path.resolve(path.dirname(filename),specifier)));
      throw new Error('Unapproved unit dependency');
    };
    const execute=vm.runInNewContext('(function(require,module,exports){'+js+'\n})',{AppStorage,console:undefined});
    execute(localRequire,module,module.exports);return module.exports;
  }
  return {load,storage,disk,preference,temporaryFiles,removedFiles,snapshots,released,nativeRequests};
}
test('actual ArkTS session code stores token and subject atomically and restores them',async()=>{
  const f=client(),{SessionStore}=f.load('services/SessionStore');await SessionStore.init({});
  await SessionStore.saveSession('unit-only-not-a-server-session','fixture','unit-subject');
  const envelope=JSON.parse(f.disk.get('trustedSessionV1'));assert.equal(envelope.userId,'unit-subject');assert.equal(f.disk.has('accessToken'),false);
  f.storage.clear();await SessionStore.init({});assert.equal(SessionStore.userId(),'unit-subject');
  await SessionStore.clearSession();assert.equal(f.storage.get('accessToken'),'');assert.equal(f.disk.get('trustedSessionV1'),'');
});
test('actual ArkTS concurrent session saves cannot persist mismatched account/token pairs',async()=>{
  const f=client(),{SessionStore}=f.load('services/SessionStore');await SessionStore.init({});
  const results=await Promise.allSettled([SessionStore.saveSession('unit-A','a','subject-a'),SessionStore.saveSession('unit-B','b','subject-b')]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const envelope=JSON.parse(f.disk.get('trustedSessionV1'));assert.equal(envelope.userId,f.storage.get('currentUserId'));assert.equal(envelope.token,f.storage.get('accessToken'));
});
test('actual ArkTS invalid or partial legacy session never restores a user',async()=>{
  const f=client();f.disk.set('accessToken','legacy-unit');f.disk.set('currentUserId','legacy-subject');
  const {SessionStore}=f.load('services/SessionStore');await SessionStore.init({});assert.equal(f.storage.get('accessToken'),'');
  f.disk.set('trustedSessionV1','{malformed');await SessionStore.init({});assert.equal(f.storage.get('currentUserId'),'');
});
test('actual ArkTS consent is not accepted in memory when persistence fails',async()=>{
  const f=client(),{SessionStore}=f.load('services/SessionStore');await SessionStore.init({});
  f.preference.flush=async()=>{throw new Error('Unit I/O failure');};
  await assert.rejects(SessionStore.savePrivacyAccepted(true));assert.equal(f.storage.get('privacyAccepted'),false);
});
test('actual ArkTS content normalizers handle null/missing fields and enforce document version',()=>{
  const f=client(),{ArtService}=f.load('services/ArtService');
  assert.equal(ArtService.character(null).id,'');assert.equal(ArtService.article(undefined).sources.length,0);assert.equal(ArtService.artwork({id:'x'}).likeCount,0);
  const character=ArtService.character({id:'one',sources:null,relatedArtworkIds:null});assert.equal(character.sources.length,0);assert.equal(character.relatedArtworkIds.length,0);
  const document=ArtService.document({schemaVersion:1,layers:[null,{id:'layer',kind:'text',x:4,y:-1,scale:99,color:'bad',text:'祝福'}]});
  assert.equal(document.layers.length,1);assert.equal(document.layers[0].x,1);assert.equal(document.layers[0].y,0);assert.equal(document.layers[0].scale,1.5);
  assert.throws(()=>ArtService.document({schemaVersion:2}),/版本/);
  assert.throws(()=>ArtService.document({schemaVersion:1,width:1200,height:800,layers:[]}),/尺寸/);
});

test('actual ArkTS editor transforms replace only the selected layer and retain wire fields',()=>{
  const f=client(),{CanvasDocument,CanvasLayer}=f.load('models/ArtModels'),{CanvasEditing}=f.load('models/CanvasEditing');
  const original=new CanvasDocument(),selected=new CanvasLayer(),other=new CanvasLayer();
  selected.id='selected';selected.materialId='material';selected.imageKey='character_koi';selected.text='好运';selected.color='#D95C52';other.id='other';
  original.layers=[selected,other];
  const rotated=CanvasEditing.rotate(original,'selected');
  assert.equal(rotated.layers[0].rotation,15);assert.equal(original.layers[0].rotation,0);
  assert.equal(rotated.layers[1],other);assert.notEqual(rotated.layers[0],selected);
  const scaled=CanvasEditing.resize(rotated,'selected',.83),moved=CanvasEditing.move(scaled,'selected',.24,.71);
  assert.equal(moved.layers[0].scale,.83);assert.equal(moved.layers[0].x,.24);assert.equal(moved.layers[0].y,.71);
  assert.equal(moved.layers[0].rotation,15);assert.equal(moved.layers[0].materialId,'material');
  assert.equal(moved.layers[0].text,'好运');assert.equal(moved.layers[0].color,'#D95C52');
  assert.equal(moved.width,800);assert.equal(moved.height,1000);assert.equal(moved.backgroundKey,original.backgroundKey);
  assert.deepEqual(JSON.parse(JSON.stringify(original)).layers[0].rotation,0);
});

test('actual ArkTS editor clamps transforms, rejects invalid/no selection and supports snapshot undo',()=>{
  const f=client(),{CanvasDocument,CanvasLayer}=f.load('models/ArtModels'),{CanvasEditing}=f.load('models/CanvasEditing'),{ArtService}=f.load('services/ArtService');
  let document=new CanvasDocument();const layer=new CanvasLayer();layer.id='layer';document.layers=[layer];
  assert.equal(CanvasEditing.rotate(document,''),document);assert.equal(CanvasEditing.resize(document,'missing',1),document);
  assert.equal(CanvasEditing.move(document,'layer',NaN,0),document);assert.equal(CanvasEditing.resize(document,'layer',Infinity),document);
  const snapshot=JSON.stringify(document);
  document=CanvasEditing.move(document,'layer',-10,10);assert.equal(document.layers[0].x,0);assert.equal(document.layers[0].y,1);
  assert.equal(CanvasEditing.resize(document,'layer',0).layers[0].scale,.08);assert.equal(CanvasEditing.resize(document,'layer',100).layers[0].scale,1.5);
  for(let i=0;i<24;i++)document=CanvasEditing.rotate(document,'layer');assert.equal(document.layers[0].rotation,0);
  const restored=ArtService.document(JSON.parse(snapshot));assert.equal(restored.layers[0].x,.5);assert.equal(restored.layers[0].scale,.6);
});
test('actual ArkTS home empty-state distinguishes each real feed section without inventing content',()=>{
  const f=client(),models=f.load('models/ArtModels'),{HomeFeed}=models;
  assert.equal(new HomeFeed().hasContent(),false);
  for(const [key,Type] of [['banners','Banner'],['categories','Category'],['characters','Character'],['artworks','Artwork'],['ranking','Artwork'],['knowledge','KnowledgeArticle'],['recent','Relation']]){
    const feed=new HomeFeed();feed[key]=[new models[Type]()];assert.equal(feed.hasContent(),true,key);feed[key]=[];assert.equal(feed.hasContent(),false,key);
  }
});

test('actual ArkTS maps article navigation to frozen knowledge relations and back',()=>{
  const {ArtService}=client().load('services/ArtService');
  assert.equal(ArtService.relationTypeForApi('article'),'knowledge');
  assert.equal(ArtService.relationTypeForPage('knowledge'),'article');
  for(const kind of ['character','artwork']){assert.equal(ArtService.relationTypeForApi(kind),kind);assert.equal(ArtService.relationTypeForPage(kind),kind);}
});

test('actual ArkTS completed shelf and profile count the same saved creations, not publication versions',async()=>{
  const rows=[{id:'old',status:'completed',updatedAt:'2026-11-01'},{id:'draft',status:'draft'},{id:'latest',status:'completed',updatedAt:'2026-11-12'},{id:'archived',status:'archived'}];
  const f=client({get:async url=>({code:0,data:url.endsWith('/profile')?{userId:'a',nickname:'A',workCount:7,draftCount:99,favoriteCount:1}:{items:rows}})});
  const {ArtService}=f.load('services/ArtService'),profile=await ArtService.personalProfile();
  assert.equal(profile.workCount,2);assert.equal(profile.draftCount,1);assert.equal(profile.favoriteCount,1);
  assert.equal((await ArtService.savedCreations()).map(row=>row.id).join(','),'latest,old');
  assert.equal((await ArtService.draftCreations()).map(row=>row.id).join(','),'draft');
  rows[1].status='completed';assert.equal((await ArtService.personalProfile()).workCount,3);assert.equal((await ArtService.personalProfile()).draftCount,0);
  assert.equal(rows[0].id,'old'); // Sorting/filtering never mutates the API response array.
});

test('actual ArkTS failed personal statistics never silently turn into zero counts or mix account responses',async()=>{
  const f=client({get:async url=>url.endsWith('/profile')?{code:0,data:{userId:'a',workCount:7}}:{code:50001,message:'Fixture failure'}});
  const {ArtService}=f.load('services/ArtService');await assert.rejects(ArtService.personalProfile(),/Fixture failure/);
  let finish;const other=client({get:async()=>new Promise(resolve=>{finish=resolve;})}),service=other.load('services/ArtService').ArtService;
  const pending=service.personalProfile();other.storage.set('sessionRevision',1);finish({code:0,data:{userId:'a'}});
  await assert.rejects(pending,/账号已变化/);
});

test('actual ArkTS save invalidates dependent pages only after confirmed writes in the current account',async()=>{
  let mode='ok',resolveOld;
  const f=client({post:async()=>{
    if(mode==='network')throw new Error('Fixture transport failure');
    if(mode==='failed')return {code:40901,message:'Fixture conflict'};
    if(mode==='pending')return new Promise(resolve=>{resolveOld=resolve;});
    return {code:0,data:{id:'saved',status:'completed',document:{schemaVersion:1}}};
  }});
  f.storage.set('currentUserId','a');f.storage.set('sessionRevision',10);
  const {ArtService}=f.load('services/ArtService'),{Creation}=f.load('models/ArtModels');
  await ArtService.saveCreation(new Creation());assert.equal(f.storage.get('artDataRevision'),1);
  mode='failed';await assert.rejects(ArtService.saveCreation(new Creation()));assert.equal(f.storage.get('artDataRevision'),1);
  mode='network';await assert.rejects(ArtService.saveCreation(new Creation()));assert.equal(f.storage.get('artDataRevision'),1);
  mode='pending';const pending=ArtService.saveCreation(new Creation());f.storage.set('sessionRevision',11);f.storage.set('currentUserId','b');
  resolveOld({code:0,data:{id:'old-account',document:{schemaVersion:1}}});await pending;assert.equal(f.storage.get('artDataRevision'),1);
});

test('actual ArkTS profile changes, favorites, versions and archive share confirmed data invalidation without changing auth revision',async()=>{
  const f=client({post:async()=>({code:0,data:{id:'version',document:{schemaVersion:1}}}),put:async()=>({code:0}),delete:async()=>({code:0})});
  f.storage.set('currentUserId','a');f.storage.set('sessionRevision',2);
  const {ArtService}=f.load('services/ArtService'),{ArtworkVersionRequest,UserProfile}=f.load('models/ArtModels');
  await ArtService.favorite('character','id',true);await ArtService.favorite('character','id',false);
  await ArtService.updateProfile(new UserProfile());await ArtService.createArtwork('saved',new ArtworkVersionRequest());
  await ArtService.submitArtwork('version');await ArtService.archiveCreation('saved');
  assert.equal(f.storage.get('artDataRevision'),6);assert.equal(f.storage.get('sessionRevision'),2);
});

test('actual native HTTP adapter bypasses NetworkKit cache for mutable authenticated API data',async()=>{
  const f=client(),{HttpClient}=f.load('services/HttpClient');
  f.storage.set('tenantId','thwkb.zh.huawei');
  await HttpClient.get('/biz/thwkb.zh.huawei/profile');
  await HttpClient.get('/biz/thwkb.zh.huawei/creations');
  assert.equal(f.nativeRequests.length,2);
  for(const request of f.nativeRequests){assert.equal(request.config.usingCache,false);assert.ok(request.url.startsWith('https://saas26.qianqi.online/api/v1/'));}
});
test('actual ArkTS navigation returns through detail/author and resets all history for a new session',()=>{
  const f=client(),{NavigationHistory}=f.load('models/NavigationHistory'),history=new NavigationHistory();
  history.push('', '', 3);history.push('artwork','public-artwork',3);history.push('author','public-author',3);
  assert.equal(history.pop().kind,'author');assert.equal(history.pop().id,'public-artwork');assert.equal(history.pop().tab,3);assert.equal(history.hasEntries(),false);
  history.push('creations','private-id',4);history.clear();assert.equal(history.pop(),undefined);
});

test('actual ArkTS cache cleanup only removes named temporary share exports, never drafts or other files',async()=>{
  const f=client(),{ExportService}=f.load('services/ExportService');
  for(const file of ['thwkb_export_123.png','draft.json','trustedSessionV1','other.png','../thwkb_export_456.png','thwkb_export_invalid.png'])f.temporaryFiles.add(file);
  assert.equal(await ExportService.clearTemporaryExports({cacheDir:'/private-test-cache'}),1);
  assert.deepEqual(f.removedFiles,['/private-test-cache/thwkb_export_123.png']);
  assert.ok(f.temporaryFiles.has('draft.json'));assert.ok(f.temporaryFiles.has('trustedSessionV1'));
});

test('actual ArkTS export requests full-resolution rendered snapshot and releases resources when picker is cancelled',async()=>{
  const f=client(),{ExportService}=f.load('services/ExportService');
  assert.equal(await ExportService.save({},'creationExportCanvas','作品',2),false);
  assert.equal(f.snapshots.length,1);assert.equal(f.snapshots[0].id,'creationExportCanvas');
  assert.equal(f.snapshots[0].options.scale,2);assert.equal(f.snapshots[0].options.waitUntilRenderFinished,true);
  assert.deepEqual(f.released,['packer','pixels']);assert.deepEqual(f.removedFiles,[]);
});

test('all four actual ArkTS legal bodies match their app-owned source documents without a false release approval',()=>{
  const f=client(),{LegalDocs}=f.load('models/LegalDocs');
  for(const [method,file] of [['privacy','privacy-policy.md'],['agreement','user-agreement.md'],['personalInfo','personal-info-list.md'],['thirdParty','third-party-list.md']]){
    const expected=fs.readFileSync(path.join(root,'store',file),'utf8').replace(/^#{1,6}\s+/gm,'').replace(/\[([^\]]+)\]\(([^)]+)\)/g,'$1（$2）').trim();
    assert.equal(LegalDocs[method+'Body'](),expected);
  }
  assert.equal(LegalDocs.developmentDraft,true);
});
