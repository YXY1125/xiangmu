import crypto from 'node:crypto';
import { APP } from './repository.mjs';
import { check,text,user,admin,scoped,owned } from './security.mjs';

const now=()=>new Date().toISOString();
const base=()=>({id:crypto.randomUUID(),tenantId:APP,appId:APP,createdAt:now(),updatedAt:now()});
const page=items=>({items,total:items.length,nextCursor:''});
const publicRow=row=>scoped(row)&&row.status==='published';
const privateKinds=['UserProfile','Creation','Publication','Favorite','Like','BrowseHistory','Report','Notification','Feedback'];

export class ArtBusiness {
  constructor(repository){this.repository=repository;}
  latestPublication(state,id){return state.entities.Publication.filter(p=>scoped(p)&&p.artworkId===id).reverse().sort((a,b)=>b.createdAt.localeCompare(a.createdAt))[0];}
  asset(state,id){return state.assets[id]?.key||'';}
  catalog(state,kind){return state.entities[kind].filter(publicRow);}
  categoryName(state,id){return state.entities.Category.find(row=>scoped(row)&&row.id===id)?.name||'';}
  favoriteFlag(state,identity,kind,id){return !!identity&&state.entities.Favorite.some(row=>scoped(row)&&row.userId===identity.id&&row.targetType===(kind==='article'?'knowledge':kind)&&row.targetId===id);}
  character(state,row,identity){
    const materialIds=new Set(state.entities.Material.filter(m=>scoped(m)&&m.assetId===row.heroAssetId).map(m=>m.id));
    const relatedArtworkIds=state.entities.Artwork.filter(a=>this.visible(state,a,null)&&a.rightsEvidence?.materialIds?.some(id=>materialIds.has(id))).slice(0,6).map(a=>a.id);
    return {id:row.id,name:row.name,categoryId:row.categoryId,categoryName:this.categoryName(state,row.categoryId),imageKey:this.asset(state,row.heroAssetId),
      story:row.originalStory,culturalMeaning:row.culturalInspiration,inspiration:row.rolePosition,colorDescription:(row.palette||[]).join(' / '),designDescription:`${row.appearance}\n${row.costume}`,
      originalNotice:'现代原创角色设定',sources:[],relatedArtworkIds,favorite:this.favoriteFlag(state,identity,'character',row.id)};
  }
  article(state,row,identity){return {id:row.id,title:row.title,summary:row.summary,categoryId:row.categoryId,coverKey:this.asset(state,row.coverAssetId),body:row.body,
    sources:row.sourceRecords||[],verifiedAt:row.publishedAt,favorite:this.favoriteFlag(state,identity,'article',row.id)};}
  material(state,row){return {id:row.id,name:row.name,kind:row.kind,imageKey:this.asset(state,row.assetId),source:row.licenseRecord?.source||'',license:row.licenseRecord?.scope||'',copyrightOwner:row.copyrightOwner};}
  creation(row){return {id:row.id,templateId:row.templateId,title:row.title,status:row.status,revision:row.revision,document:row.canvasState,updatedAt:row.updatedAt};}
  visible(state,row,identity){
    if(!scoped(row))return false;
    if(identity&&row.ownerUserId===identity.id)return true;
    if(row.visibility!=='public')return false;
    if(row.sourceType==='official')return true;
    const latest=this.latestPublication(state,row.id);
    return latest?.status==='approved';
  }
  artwork(state,row,identity){
    const author=state.entities.UserProfile.find(p=>scoped(p)&&p.userId===row.ownerUserId);
    const publication=this.latestPublication(state,row.id);
    return {id:row.id,title:row.title,description:row.description||'',authorId:row.ownerUserId||'official',authorName:row.sourceType==='official'?'桃花坞刻版印坊':author?.nickname||'创作者',
      origin:row.sourceType,coverKey:this.asset(state,row.coverAssetId),previewUrl:'',document:row.rightsEvidence?.canvasState,
      reviewStatus:row.sourceType==='official'?'official':publication?.status||'draft',copyrightSource:row.copyrightDeclaration,
      likeCount:state.entities.Like.filter(l=>scoped(l)&&l.artworkId===row.id).length,favoriteCount:state.entities.Favorite.filter(f=>scoped(f)&&f.targetType==='artwork'&&f.targetId===row.id).length,
      liked:!!identity&&state.entities.Like.some(l=>scoped(l)&&l.artworkId===row.id&&l.userId===identity.id),favorite:this.favoriteFlag(state,identity,'artwork',row.id),createdAt:row.createdAt};
  }
  target(state,kind,id,identity){
    // article is a UI navigation alias; persisted relations use the frozen knowledge enum.
    if(kind==='article')kind='knowledge';
    check(['character','knowledge','artwork'].includes(kind),400,'内容类型不正确');
    if(kind==='artwork'){
      const row=state.entities.Artwork.find(a=>a.id===id&&this.visible(state,a,identity));check(row,404,'作品不存在');return this.artwork(state,row,identity);
    }
    const collection=kind==='character'?this.catalog(state,'Character'):this.catalog(state,'KnowledgeArticle').filter(a=>a.factCheckStatus==='verified');
    const row=collection.find(a=>a.id===id);check(row,404,'内容不存在');return kind==='character'?this.character(state,row,identity):this.article(state,row,identity);
  }
  async home(identity){
    const state=await this.repository.read();const works=state.entities.Artwork.filter(a=>this.visible(state,a,null)).map(a=>this.artwork(state,a,identity));
    const characters=this.catalog(state,'Character').sort((a,b)=>Number(this.asset(state,b.heroAssetId).startsWith('ip_'))-Number(this.asset(state,a.heroAssetId).startsWith('ip_')));
    return {banners:this.catalog(state,'Topic').map(t=>({id:t.id,title:t.title,subtitle:t.summary,imageKey:this.asset(state,t.coverAssetId),targetKind:t.contentRefs.kind,targetId:t.contentRefs.id})),
      categories:state.categories.filter(c=>this.catalog(state,'Category').some(row=>row.id===c.id)),characters:characters.slice(0,8).map(c=>this.character(state,c,identity)),artworks:works.slice(0,6),ranking:[...works].sort((a,b)=>b.likeCount-a.likeCount).slice(0,5),
      knowledge:this.catalog(state,'KnowledgeArticle').filter(a=>a.factCheckStatus==='verified').slice(0,3).map(a=>this.article(state,a,identity)),recent:identity?(await this.list('history',{},identity)).items.slice(0,6):[],
      viewer:identity?this.profileValue(state,state.entities.UserProfile.find(p=>scoped(p)&&p.userId===identity.id),identity):null};
  }
  async list(kind,query,identity){
    const state=await this.repository.read(),q=(query.q||'').toString().trim().toLocaleLowerCase().slice(0,100);
    if(kind==='characters')return page(this.catalog(state,'Character').filter(c=>(!query.category||c.categoryId===query.category||this.categoryName(state,query.category)==='原创角色'&&this.asset(state,c.heroAssetId).startsWith('ip_'))&&(!q||`${c.name}${c.series}${c.culturalInspiration}`.toLocaleLowerCase().includes(q))).map(c=>this.character(state,c,identity)));
    if(kind==='knowledge')return page(this.catalog(state,'KnowledgeArticle').filter(a=>a.factCheckStatus==='verified'&&(!q||`${a.title}${a.summary}`.toLocaleLowerCase().includes(q))).map(a=>this.article(state,a,identity)));
    if(kind==='materials')return page(this.catalog(state,'Material').filter(m=>m.licenseRecord?.scope==='in_app_composition').map(m=>this.material(state,m)));
    if(kind==='templates')return page(this.catalog(state,'Template').map(t=>({id:t.id,name:t.name,coverKey:this.asset(state,t.coverAssetId),document:t.baseLayers,materialIds:t.baseLayers.layers.map(l=>l.materialId)})));
    if(kind==='plaza'){
      if(query.liked==='mine')user(identity);
      let works=state.entities.Artwork.filter(a=>this.visible(state,a,null)&&(!q||`${a.title}${a.description}`.toLocaleLowerCase().includes(q))&&(!query.category||a.rightsEvidence?.categoryIds?.includes(query.category)||a.sourceType==='user_original'&&this.categoryName(state,query.category)==='年画作品')&&(query.order!=='official'||a.sourceType==='official')&&(query.liked!=='mine'||state.entities.Like.some(l=>scoped(l)&&l.userId===identity.id&&l.artworkId===a.id))).map(a=>this.artwork(state,a,identity));
      works.sort(query.order==='popular'?(a,b)=>b.likeCount-a.likeCount||b.id.localeCompare(a.id):(a,b)=>b.createdAt.localeCompare(a.createdAt)||b.id.localeCompare(a.id));
      const start=query.cursor?works.findIndex(a=>a.id===query.cursor)+1:0;check(!query.cursor||start>0,400,'分页位置已变化，请刷新');
      const items=works.slice(start,start+20);return {items,total:works.length,nextCursor:start+20<works.length?items.at(-1).id:''};
    }
    user(identity);
    if(kind==='creations')return page(state.entities.Creation.filter(c=>scoped(c)&&c.userId===identity.id&&c.status!=='archived').map(c=>this.creation(c)));
    if(kind==='artworks/mine')return page(state.entities.Artwork.filter(a=>scoped(a)&&a.ownerUserId===identity.id).map(a=>this.artwork(state,a,identity)));
    if(kind==='likes')return page(state.entities.Artwork.filter(a=>this.visible(state,a,null)&&state.entities.Like.some(l=>scoped(l)&&l.userId===identity.id&&l.artworkId===a.id)).map(a=>this.artwork(state,a,identity)));
    if(kind==='publications/mine')return page(state.entities.Publication.filter(p=>scoped(p)&&p.userId===identity.id).map(p=>({id:p.id,artworkId:p.artworkId,status:p.status,reason:p.reviewReason||'',updatedAt:p.updatedAt})));
    if(kind==='notifications')return page(state.entities.Notification.filter(n=>scoped(n)&&n.userId===identity.id).sort((a,b)=>b.createdAt.localeCompare(a.createdAt)));
    if(kind==='feedback')return page(state.entities.Feedback.filter(n=>scoped(n)&&n.userId===identity.id).sort((a,b)=>b.createdAt.localeCompare(a.createdAt)));
    if(kind==='favorites'||kind==='history'){
      const rows=state.entities[kind==='favorites'?'Favorite':'BrowseHistory'].filter(r=>scoped(r)&&r.userId===identity.id);
      const items=[];
      for(const row of rows){try{const t=this.target(state,row.targetType,row.targetId,identity);items.push({id:row.id,targetType:row.targetType,targetId:row.targetId,title:t.name||t.title,imageKey:t.imageKey||t.coverKey,updatedAt:row.lastViewedAt||row.createdAt,available:true});}catch(error){if(error.status!==404)throw error;items.push({id:row.id,targetType:row.targetType,targetId:row.targetId,title:'内容已下架或不再公开',imageKey:'',updatedAt:row.lastViewedAt||row.createdAt,available:false});}}
      return page(items.sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt)));
    }
    check(false,404,'接口不存在');
  }
  async detail(kind,id,identity){const state=await this.repository.read();if(kind==='creations')return this.creation(owned(state.entities.Creation,id,identity));return this.target(state,kind==='characters'?'character':kind==='knowledge'?'article':'artwork',id,identity);}
  validateDocument(state,input){
    check(input&&input.schemaVersion===1&&input.width===800&&input.height===1000,422,'画布版本或尺寸不支持');
    const materials=this.catalog(state,'Material').filter(m=>m.licenseRecord?.scope==='in_app_composition'),background=materials.find(m=>m.kind==='background'&&this.asset(state,m.assetId)===input.backgroundKey);
    check(background,422,'背景素材不可用');check(Array.isArray(input.layers)&&input.layers.length<=60,422,'图层数量不正确');
    const ids=new Set();const layers=input.layers.map(layer=>{
      const id=text(layer.id,100,true);check(!ids.has(id),422,'图层标识重复');ids.add(id);
      check(['image','text'].includes(layer.kind),422,'图层类型不支持');
      for(const [field,min,max] of [['x',0,1],['y',0,1],['scale',.08,1.5],['rotation',-360,360]])check(typeof layer[field]==='number'&&Number.isFinite(layer[field])&&layer[field]>=min&&layer[field]<=max,422,'图层位置或大小不正确');
      check(/^#[0-9a-f]{6}$/i.test(layer.color),422,'文字颜色不正确');
      const result={id,kind:layer.kind,x:layer.x,y:layer.y,scale:layer.scale,rotation:layer.rotation,color:layer.color,text:'',imageKey:'',materialId:''};
      if(layer.kind==='text')result.text=text(layer.text,80,true);
      else {const material=materials.find(m=>m.id===layer.materialId&&m.kind!=='background');check(material&&this.asset(state,material.assetId)===layer.imageKey,422,'图层素材未授权或不可用');result.materialId=material.id;result.imageKey=layer.imageKey;}
      return result;
    });
    return {schemaVersion:1,width:800,height:1000,backgroundKey:input.backgroundKey,colorTheme:['peach','sage','ink'].includes(input.colorTheme)?input.colorTheme:'peach',layers};
  }
  async saveCreation(identity,input,id=''){
    user(identity);return this.repository.transact(state=>{
      check(input&&typeof input==='object',400,'保存参数缺失');check(['draft','completed'].includes(input.status),422,'创作状态不正确');
      const document=this.validateDocument(state,input.document);let row;
      if(id){row=owned(state.entities.Creation,id,identity);check(row.status!=='archived',409,'创作已归档');check(Number.isInteger(input.revision)&&input.revision===row.revision,409,'作品已被其他操作更新，请重新读取');check(!input.templateId||input.templateId===row.templateId,409,'不能替换已保存创作的原始模板来源');}
      else {check(input.revision===0,409,'新作品修订号应为0');const templateId=text(input.templateId||'',64,true);check(this.catalog(state,'Template').some(t=>t.id===templateId),422,'请选择当前应用已发布的创作模板');row={...base(),userId:identity.id,templateId,previewAssetId:null,revision:0};state.entities.Creation.push(row);}
      row.title=text(input.title,60,true);row.canvasState=document;row.status=input.status;row.revision++;row.updatedAt=now();return this.creation(row);
    });
  }
  async archiveCreation(identity,id){return this.repository.transact(state=>{const row=owned(state.entities.Creation,id,identity);row.status='archived';row.revision++;row.updatedAt=now();return {archived:true};});}
  async makeArtwork(identity,id,input){
    user(identity);return this.repository.transact(state=>{
      const creation=owned(state.entities.Creation,id,identity);check(creation.status==='completed',409,'请先保存正式作品');
      const document=this.validateDocument(state,creation.canvasState);const declaration=text(input?.copyrightDeclaration,2000,true);
      const cover=Object.values(state.assets).find(a=>a.key===document.backgroundKey);check(cover,422,'封面资源不存在');
      const description=text(input.description||'',1000);
      const existing=state.entities.Artwork.find(a=>scoped(a)&&a.ownerUserId===identity.id&&a.creationId===creation.id&&a.rightsEvidence?.creationRevision===creation.revision&&a.copyrightDeclaration===declaration&&a.description===description);
      if(existing)return this.artwork(state,existing,identity);
      const row={...base(),ownerUserId:identity.id,creationId:creation.id,sourceType:'user_original',title:creation.title,description,coverAssetId:cover.assetId,
        copyrightDeclaration:declaration,rightsEvidence:{canvasState:document,materialIds:document.layers.filter(l=>l.kind==='image').map(l=>l.materialId),creationRevision:creation.revision},visibility:'private'};
      state.entities.Artwork.push(row);return this.artwork(state,row,identity);
    });
  }
  async submit(identity,id,input){
    user(identity);return this.repository.transact(state=>{
      const artwork=owned(state.entities.Artwork,id,identity,'ownerUserId');check(input?.rightsConfirmed===true,422,'请确认作品版权与发布授权');
      const rows=state.entities.Publication.filter(p=>scoped(p)&&p.artworkId===id);check(!rows.some(p=>p.status==='submitted'||p.status==='approved'),409,'作品已提交或已公开');
      check(artwork.rightsEvidence?.canvasState,422,'作品版本记录缺失');this.validateDocument(state,artwork.rightsEvidence.canvasState);
      const publication={...base(),userId:identity.id,artworkId:id,status:'submitted',reviewReason:null,submittedAt:now(),reviewedAt:null};
      state.entities.Publication.push(publication);artwork.visibility='private';artwork.updatedAt=now();return {id:publication.id,status:publication.status};
    });
  }
  notify(state,userId,title,body,targetRoute){state.entities.Notification.push({...base(),userId,kind:'review',title,body,targetRoute,readAt:null});}
  async review(identity,id,input){
    admin(identity);return this.repository.transact(state=>{
      const publication=state.entities.Publication.find(p=>scoped(p)&&p.id===id);check(publication,404,'审核记录不存在');
      const status=text(input.status,20,true),reason=text(input.reason||'',1000,status!=='approved');
      check(publication.status==='submitted'&&['approved','rejected'].includes(status)||publication.status==='approved'&&status==='offline',409,'审核状态流转不允许');
      check(status!=='approved'||input.rightsChecked===true,422,'通过前须核对版权记录');
      const artwork=state.entities.Artwork.find(a=>scoped(a)&&a.id===publication.artworkId);check(artwork,404,'作品不存在');
      if(status==='approved')this.validateDocument(state,artwork.rightsEvidence.canvasState);
      publication.status=status;publication.reviewReason=reason;publication.reviewedAt=now();publication.updatedAt=now();
      artwork.visibility=status==='approved'?'public':'private';artwork.updatedAt=now();
      this.notify(state,publication.userId,status==='approved'?'作品审核通过':status==='rejected'?'作品审核未通过':'作品已下架',reason||'作品已公开展示。',`artwork:${artwork.id}`);
      return {id,status};
    });
  }
  async favorite(identity,input,remove=false){
    user(identity);return this.repository.transact(state=>{
      const supplied=text(input.targetType,20,true),kind=supplied==='article'?'knowledge':supplied,id=text(input.targetId,64,true);
      if(!remove)this.target(state,kind,id,null);
      const previous=state.entities.Favorite.find(f=>scoped(f)&&f.userId===identity.id&&f.targetType===kind&&f.targetId===id);
      if(remove)state.entities.Favorite=state.entities.Favorite.filter(f=>f!==previous);
      else if(!previous)state.entities.Favorite.push({...base(),userId:identity.id,targetType:kind,targetId:id});
      return {active:!remove};
    });
  }
  async like(identity,id,remove=false){
    user(identity);return this.repository.transact(state=>{
      if(!remove)this.target(state,'artwork',id,null);
      const previous=state.entities.Like.find(l=>scoped(l)&&l.userId===identity.id&&l.artworkId===id);
      if(remove)state.entities.Like=state.entities.Like.filter(l=>l!==previous);
      else if(!previous)state.entities.Like.push({...base(),userId:identity.id,artworkId:id});
      return {active:!remove};
    });
  }
  async browse(identity,input){
    user(identity);return this.repository.transact(state=>{
      const supplied=text(input.targetType,20,true),kind=supplied==='article'?'knowledge':supplied,id=text(input.targetId,64,true);this.target(state,kind,id,identity);
      const row=state.entities.BrowseHistory.find(h=>scoped(h)&&h.userId===identity.id&&h.targetType===kind&&h.targetId===id);
      if(row){row.viewCount++;row.lastViewedAt=now();}else state.entities.BrowseHistory.push({...base(),userId:identity.id,targetType:kind,targetId:id,viewCount:1,lastViewedAt:now()});
      return {recorded:true};
    });
  }
  async report(identity,id,input){
    user(identity);return this.repository.transact(state=>{
      this.target(state,'artwork',id,null);check(['copyright','inappropriate','misleading','other'].includes(input?.reasonCode),422,'举报原因不正确');
      const existing=state.entities.Report.find(r=>scoped(r)&&r.userId===identity.id&&r.artworkId===id&&['submitted','reviewing'].includes(r.status));
      if(existing)return {id:existing.id,status:existing.status};
      const report={...base(),userId:identity.id,artworkId:id,reasonCode:input.reasonCode,description:text(input.description||'',1000),status:'submitted',resolution:null};
      state.entities.Report.push(report);return {id:report.id,status:report.status};
    });
  }
  async resolveReport(identity,id,input){
    admin(identity);return this.repository.transact(state=>{
      const report=state.entities.Report.find(r=>scoped(r)&&r.id===id);check(report,404,'举报不存在');
      check(report.status==='submitted'&&input.status==='reviewing'||report.status==='reviewing'&&['resolved','dismissed'].includes(input.status),409,'举报状态流转不允许');
      report.status=input.status;report.resolution=text(input.resolution||'',1000,input.status!=='reviewing');report.updatedAt=now();
      if(input.takeDown===true){
        check(input.status==='resolved',422,'处理成立后才可下架');const artwork=state.entities.Artwork.find(a=>scoped(a)&&a.id===report.artworkId);
        if(artwork){artwork.visibility='private';artwork.updatedAt=now();for(const p of state.entities.Publication.filter(p=>scoped(p)&&p.artworkId===artwork.id&&p.status==='approved')){p.status='offline';p.reviewReason=report.resolution;p.reviewedAt=now();p.updatedAt=now();}
          if(artwork.ownerUserId)this.notify(state,artwork.ownerUserId,'作品已下架',report.resolution,`artwork:${artwork.id}`);
        }
      }
      this.notify(state,report.userId,'举报处理进度',report.resolution||'举报已进入复核。','');return {id,status:report.status};
    });
  }
  profileValue(state,row,identity){return {userId:identity.id,nickname:row?.nickname||identity.displayName||identity.username,avatarKey:this.asset(state,row?.avatarAssetId)||'ip_taoyao',bio:row?.bio||'',
    workCount:state.entities.Artwork.filter(a=>scoped(a)&&a.ownerUserId===identity.id).length,draftCount:state.entities.Creation.filter(c=>scoped(c)&&c.userId===identity.id&&c.status==='draft').length,favoriteCount:state.entities.Favorite.filter(f=>scoped(f)&&f.userId===identity.id).length};}
  async profile(identity){user(identity);const state=await this.repository.read();return this.profileValue(state,state.entities.UserProfile.find(p=>scoped(p)&&p.userId===identity.id),identity);}
  async updateProfile(identity,input){
    user(identity);return this.repository.transact(state=>{
      const asset=Object.values(state.assets).find(a=>a.key===input.avatarKey&&a.key.startsWith('ip_'));check(asset,422,'头像素材不可用');
      let row=state.entities.UserProfile.find(p=>scoped(p)&&p.userId===identity.id);if(!row){row={...base(),userId:identity.id};state.entities.UserProfile.push(row);}
      row.nickname=text(input.nickname,30,true);row.bio=text(input.bio||'',160);row.avatarAssetId=asset.assetId;row.updatedAt=now();return this.profileValue(state,row,identity);
    });
  }
  async readNotification(identity,id){return this.repository.transact(state=>{const row=owned(state.entities.Notification,id,identity);row.readAt=now();return {read:true};});}
  async author(id,identity){
    const state=await this.repository.read(),official=id==='official';
    const works=state.entities.Artwork.filter(a=>this.visible(state,a,null)&&(official?a.sourceType==='official':a.ownerUserId===id));
    check(works.length>0,404,'暂无公开作者资料');
    const profile=state.entities.UserProfile.find(p=>scoped(p)&&p.userId===id);
    return {id,nickname:official?'桃花坞刻版印坊':profile?.nickname||'创作者',avatarKey:official?'ip_taoyao':this.asset(state,profile?.avatarAssetId)||'ip_taoyao',bio:official?'现代原创角色与数字套色作品。':profile?.bio||'',artworks:works.map(a=>this.artwork(state,a,identity))};
  }
  async feedback(identity,input){
    user(identity);return this.repository.transact(state=>{
      check(['suggestion','bug','content','other'].includes(input.category),422,'反馈类型不正确');
      const body=text(input.body,2000,true),previous=state.entities.Feedback.find(f=>scoped(f)&&f.userId===identity.id&&f.body===body&&f.category===input.category&&f.createdAt>new Date(Date.now()-60000).toISOString());
      if(previous)return previous;
      const row={...base(),userId:identity.id,category:input.category,body,status:'submitted',reply:null};state.entities.Feedback.push(row);return row;
    });
  }
  async replyFeedback(identity,id,input){
    admin(identity);return this.repository.transact(state=>{
      const row=state.entities.Feedback.find(f=>scoped(f)&&f.id===id);check(row,404,'反馈不存在');
      const allowed={submitted:['reviewing','replied'],reviewing:['replied'],replied:['closed'],closed:[]};
      check(allowed[row.status]?.includes(input.status),409,'反馈状态流转不允许');
      row.reply=text(input.reply||'',2000,['replied','closed'].includes(input.status));row.status=input.status;row.updatedAt=now();
      this.notify(state,row.userId,'意见反馈进度',row.reply||'反馈已进入处理。','feedback');return {id,status:row.status};
    });
  }
  async contentState(identity,kind,id,input){
    admin(identity);check(['Character','KnowledgeArticle','Material','Template','Topic','Category'].includes(kind),400,'内容类型不支持');
    return this.repository.transact(state=>{
      const row=state.entities[kind].find(r=>scoped(r)&&r.id===id);check(row,404,'内容不存在');
      check(['draft','published','offline'].includes(input.status),422,'内容状态不支持');
      if(input.status==='published'){
        if(kind==='KnowledgeArticle')check(row.factCheckStatus==='verified'&&row.sourceRecords?.length>0,422,'知识内容必须核验来源');
        if(kind==='Material')check(row.licenseRecord?.scope==='in_app_composition',422,'素材授权不足');
        if(kind==='Template')this.validateDocument(state,row.baseLayers);
      }
      row.status=input.status;row.updatedAt=now();return {id,status:row.status};
    });
  }
  async adminList(identity,kind){admin(identity,false);check(['Publication','Report','Feedback','Character','KnowledgeArticle','Material','Template','Artwork','Topic','Category'].includes(kind),400,'管理资源不支持');const state=await this.repository.read();return page(state.entities[kind].filter(scoped));}
  async purgeAccount(identity){
    user(identity);return this.repository.transact(state=>{
      const workIds=new Set(state.entities.Artwork.filter(a=>scoped(a)&&a.ownerUserId===identity.id).map(a=>a.id));
      for(const kind of privateKinds)state.entities[kind]=state.entities[kind].filter(row=>!scoped(row)||row.userId!==identity.id);
      state.entities.Artwork=state.entities.Artwork.filter(row=>!scoped(row)||row.ownerUserId!==identity.id);
      for(const kind of ['Like','Favorite','BrowseHistory','Report'])state.entities[kind]=state.entities[kind].filter(row=>!scoped(row)||!workIds.has(row.artworkId||row.targetId));
      return {purged:true};
    });
  }
}
