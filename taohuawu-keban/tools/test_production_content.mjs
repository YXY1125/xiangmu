// Actual HTTPS + PostgreSQL business flows. Test credentials never leave process memory.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {appRoot} from './remote_support.mjs';
const APP='thwkb.zh.huawei',base='https://saas26.qianqi.online/api/v1',root='/biz/'+APP;
const report={at:new Date().toISOString(),target:base,realProduction:true,scope:'public content, actual creation persistence, pending publication and A/B isolation; no administrator approval or native UI implied',cases:[],cleanup:[]},accounts=[];
const check=(name,condition)=>{report.cases.push({name,passed:!!condition});if(!condition)throw Error('Case failed');};
async function call(route,method='GET',body,token){
 const response=await fetch(base+route,{method,headers:{'x-tenant-id':APP,...(token?{authorization:'Bearer '+token}:{}),...(body?{'content-type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});
 return {...await response.json(),httpStatus:response.status};
}
try {
 const home=await call(root+'/home');check('Production home has four real banners and no private guest history',home.code===0&&home.data.banners.length===4&&home.data.recent.length===0);
 const lists={};
 for(const [kind,total] of [['characters',24],['knowledge',12],['materials',74],['templates',12],['plaza',20]]){
  lists[kind]=await call(root+'/'+kind);check('Production '+kind+' contains approved source records',lists[kind].code===0&&lists[kind].data.total===total);
 }
 const character=lists.characters.data.items[0],article=lists.knowledge.data.items[0],official=lists.plaza.data.items[0],template=lists.templates.data.items[0];
 check('Character detail distinguishes modern original story',(await call(root+'/characters/'+character.id)).data?.originalNotice==='现代原创角色设定');
 const knowledge=await call(root+'/knowledge/'+article.id);check('Knowledge detail retains factual sources',knowledge.code===0&&knowledge.data.sources.length>0);
 check('Official author has actual public works',(await call(root+'/authors/official')).data?.artworks?.length>0);
 for(let i=0;i<2;i++){
  const account={username:'thwkb_flow_'+crypto.randomBytes(8).toString('hex'),password:crypto.randomBytes(28).toString('hex'),realName:'创作闭环验证用户',phone:'198'+crypto.randomInt(10000000,99999999),tenantId:APP};
  const registered=await call('/auth/register','POST',account);check('Real scoped registration '+(i+1),registered.code===0&&!!registered.data?.accessToken);
  accounts.push({...account,token:registered.data.accessToken,id:registered.data.user.id,deleted:false});
 }
 const [a,b]=accounts;
 for(const kind of ['creations','artworks/mine','favorites','history','notifications','feedback'])check('New user has no private '+kind,(await call(root+'/'+kind,'GET',undefined,a.token)).data?.total===0);
 const document=structuredClone(template.document);document.layers[0].x=.31;document.layers[0].y=.64;document.layers[0].scale=.53;document.layers[0].rotation=12;
 document.layers.push({id:crypto.randomUUID(),kind:'text',materialId:'',imageKey:'',text:'平安喜乐',x:.5,y:.88,scale:.45,rotation:0,color:'#D95C52'});
 const draftBody={title:'生产创作闭环验证',templateId:template.id,status:'draft',revision:0,document,userId:b.id};
 const draft=await call(root+'/creations','POST',draftBody,a.token);check('Actual draft creation commits to production PostgreSQL',draft.code===0&&draft.data.revision===1);
 const id=draft.data.id;
 check('Stored layers preserve text, position, scale and rotation',isDeepStrictEqual((await call(root+'/creations/'+id,'GET',undefined,a.token)).data?.document,document));
 check('B cannot read A creation',(await call(root+'/creations/'+id,'GET',undefined,b.token)).code===40401);
 check('B cannot update A creation',(await call(root+'/creations/'+id,'PUT',{...draftBody,revision:1},b.token)).code===40401);
 check('B private creation list remains empty',(await call(root+'/creations','GET',undefined,b.token)).data?.total===0);
 const completed=await call(root+'/creations/'+id,'PUT',{...draftBody,status:'completed',revision:1},a.token);check('Draft becomes completed with optimistic revision',completed.code===0&&completed.data.revision===2);
 check('Stale save is rejected without overwrite',(await call(root+'/creations/'+id,'PUT',{...draftBody,revision:1},a.token)).code===40901);
 const artwork=await call(root+'/creations/'+id+'/artwork','POST',{copyrightDeclaration:'生产联调验证，使用本项目已获授权的生成素材组合。',description:'上线前真实接口验证，测试结束由本人注销清理。'},a.token);check('Artwork snapshot is created from completed source',artwork.code===0&&!!artwork.data?.id);
 const workId=artwork.data.id;
 check('Private artwork is invisible to guest',(await call(root+'/artworks/'+workId)).code===40401);
 check('B cannot access private artwork',(await call(root+'/artworks/'+workId,'GET',undefined,b.token)).code===40401);
 check('Publication requires active rights confirmation',(await call(root+'/artworks/'+workId+'/publications','POST',{rightsConfirmed:false},a.token)).code===42201);
 const submitted=await call(root+'/artworks/'+workId+'/publications','POST',{rightsConfirmed:true},a.token);check('Publication is persisted as submitted, not approved',submitted.code===0&&submitted.data.status==='submitted');
 check('Unreviewed work stays hidden from public detail',(await call(root+'/artworks/'+workId)).code===40401);
 check('Unreviewed work stays out of plaza',!(await call(root+'/plaza')).data.items.some(r=>r.id===workId));
 check('Owner sees actual submitted review status',(await call(root+'/publications/mine','GET',undefined,a.token)).data?.items.some(r=>r.id===submitted.data.id&&r.status==='submitted'));
 check('Ordinary app identity cannot approve publication',(await call(root+'/admin/publications/'+submitted.data.id+'/review','PUT',{status:'approved',rightsChecked:true},a.token)).code===40301);
 for(let i=0;i<2;i++)await call(root+'/favorites','POST',{targetType:'character',targetId:character.id},a.token);
 check('Repeated favorite has one persistent relation',(await call(root+'/favorites','GET',undefined,a.token)).data?.total===1);
 for(const targetType of ['article','knowledge'])await call(root+'/favorites','POST',{targetType,targetId:article.id},a.token);
 const favorites=await call(root+'/favorites','GET',undefined,a.token);
 check('Article alias and canonical knowledge favorite share one database relation',favorites.code===0&&favorites.data.total===2&&favorites.data.items.filter(r=>r.targetId===article.id&&r.targetType==='knowledge').length===1);
 check('Knowledge detail reflects stored favorite',(await call(root+'/knowledge/'+article.id,'GET',undefined,a.token)).data?.favorite===true);
 for(let i=0;i<2;i++)await call(root+'/artworks/'+official.id+'/like','POST',{},a.token);
 check('Repeated like has one persistent relation',(await call(root+'/artworks/'+official.id,'GET',undefined,a.token)).data?.likeCount===official.likeCount+1);
 for(const targetType of ['article','knowledge'])await call(root+'/history','POST',{targetType,targetId:article.id},a.token);
 check('Repeated browsing has one history relation',(await call(root+'/history','GET',undefined,a.token)).data?.total===1);
 check('Home recent browsing uses same persistent source',(await call(root+'/home','GET',undefined,a.token)).data?.recent.length===1);
 check('B does not inherit favorites or browsing',(await call(root+'/favorites','GET',undefined,b.token)).data?.total===0&&(await call(root+'/history','GET',undefined,b.token)).data?.total===0);
 check('Logout acknowledges session revocation',(await call('/auth/logout','POST',{},a.token)).code===0);
 check('Old token cannot read saved creation',(await call(root+'/creations/'+id,'GET',undefined,a.token)).code===40101);
 const relogin=await call('/auth/login','POST',{username:a.username,password:a.password});check('Real SaaS26 relogin succeeds',relogin.code===0);a.token=relogin.data.accessToken;
 const restored=await call(root+'/creations/'+id,'GET',undefined,a.token);check('Relogin restores exact document and revision',restored.code===0&&restored.data.revision===2&&isDeepStrictEqual(restored.data.document,document));
 check('Relogin restores favorite and pending publication',(await call(root+'/favorites','GET',undefined,a.token)).data?.total===2&&(await call(root+'/publications/mine','GET',undefined,a.token)).data?.total===1);
 check('Archive is acknowledged',(await call(root+'/creations/'+id,'DELETE',{},a.token)).data?.archived===true);
 check('Archived creation cannot be silently overwritten',(await call(root+'/creations/'+id,'PUT',{...draftBody,revision:3},a.token)).code===40901);
}catch{report.failure=report.cases.at(-1)?.passed===false?report.cases.at(-1).name:'HTTPS operation incomplete; sensitive diagnostics suppressed';}
finally{
 for(const account of accounts){
  try{const login=await call('/auth/login','POST',{username:account.username,password:account.password});if(login.code===0)account.token=login.data.accessToken;account.deleted=(await call('/privacy/account','DELETE',{},account.token)).data?.deleted===true;}catch{}
  report.cleanup.push({testAccount:accounts.indexOf(account)+1,deleted:account.deleted});
 }
 const plaza=await call(root+'/plaza').catch(()=>null);report.cases.push({name:'After test cleanup public official content is preserved',passed:plaza?.code===0&&plaza.data.total===20});
 report.passed=!report.failure&&report.cases.every(c=>c.passed)&&report.cleanup.every(c=>c.deleted);report.gateBPassed=false;
 await fs.appendFile(path.join(appRoot,'docs/validation/deploy/production-content-test-attempts.jsonl'),JSON.stringify(report)+'\n');
 await fs.writeFile(path.join(appRoot,'docs/validation/deploy/production-content-tests.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));process.exitCode=report.passed?0:1;
}
