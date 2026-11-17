import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const specPath=path.join(root,'AppSpec.json'),freezePath=path.join(root,'APPSPEC_FREEZE.json');
const oldSpec=fs.readFileSync(specPath,'utf8'),oldFreeze=fs.readFileSync(freezePath,'utf8');
const spec=JSON.parse(oldSpec),freeze=JSON.parse(oldFreeze);
if(freeze.version==='1.3'){console.log('CR003 already applied');process.exit(0);}
if(freeze.version!=='1.2')throw new Error('Expected frozen v1.2');
const feedback={name:'Feedback',table:'thwkb_feedback',description:'当前用户提交的产品反馈与管理员回复，不公开用户个人信息',fields:[
  {name:'id',type:'uuid',required:true,unique:true},{name:'tenantId',type:'string',required:true},{name:'appId',type:'string',required:true},{name:'userId',type:'string',required:true},
  {name:'category',type:'enum',required:true,enumValues:['suggestion','bug','content','other']},{name:'body',type:'text',required:true},
  {name:'status',type:'enum',required:true,enumValues:['submitted','reviewing','replied','closed']},{name:'reply',type:'text'},
  {name:'createdAt',type:'datetime',required:true},{name:'updatedAt',type:'datetime',required:true}
],indexes:[['tenantId','appId','userId','createdAt'],['tenantId','appId','status','updatedAt']]};
spec.entities.push(feedback);
const api=(method,suffix,summary,auth,module,requestDto,responseDto)=>({method,path:`/biz/thwkb.zh.huawei/${suffix}`,summary,auth,module,...(requestDto?{requestDto}:{}),responseDto});
spec.apis.push(
  {method:'POST',path:'/auth/logout',summary:'撤销当前认证会话',auth:true,responseDto:'ActionResult',module:'auth'},
  api('GET','authors/:id','只读取作者公开资料和已审核公开作品',false,'profile','', 'PublicAuthor'),
  api('GET','feedback','读取当前用户反馈记录和回复',true,'feedback','', 'FeedbackPage'),
  api('POST','feedback','提交当前用户意见反馈',true,'feedback','FeedbackRequest','FeedbackDetail'),
  api('GET','admin/:kind','受信管理员查询本应用管理资源',true,'moderation','', 'AdminResourcePage'),
  api('PUT','admin/publications/:id/review','受信管理员审核作品版本',true,'moderation','ReviewRequest','ActionResult'),
  api('PUT','admin/reports/:id/resolve','受信管理员复核举报',true,'moderation','ReportResolution','ActionResult'),
  api('PUT','admin/feedback/:id/reply','受信管理员回复反馈',true,'feedback','FeedbackReply','ActionResult'),
  api('PUT','admin/content/:kind/:id/state','受信管理员修改本应用内容发布状态',true,'moderation','ContentState','ActionResult')
);
const mine=spec.modules.pages.find(p=>p.id==='mine');if(mine)mine.features.push('意见反馈与回复','我的喜欢');
fs.mkdirSync(path.join(root,'docs/validation/history'),{recursive:true});
fs.writeFileSync(path.join(root,'docs/validation/history/AppSpec-before-CR003.json'),oldSpec);
fs.writeFileSync(path.join(root,'docs/validation/history/APPSPEC_FREEZE-before-CR003.json'),oldFreeze);
const content=JSON.stringify(spec,null,2)+'\n';fs.writeFileSync(specPath,content);
fs.writeFileSync(freezePath,JSON.stringify({...freeze,version:'1.3',previousChecksum:freeze.checksum,checksum:crypto.createHash('sha256').update(content).digest('hex'),gateAStatus:'pending',changeRecord:'docs/product/change-request-003-business-completeness.md',changeApprovedAt:new Date().toISOString()},null,2)+'\n');
fs.writeFileSync(path.join(root,'server/contracts/entities.json'),JSON.stringify(spec.entities,null,2)+'\n');
const table='thwkb_feedback',type={uuid:'uuid',string:'text',enum:'text',text:'text',datetime:'timestamptz'};
let sql='-- CR003 user-approved app-owned extension; does not change migration001 or platform tables.\nBEGIN;\n';
sql+=`CREATE TABLE ${table} (\n${feedback.fields.map(f=>`  "${f.name}" ${type[f.type]}${f.required?' NOT NULL':''}${f.enumValues?` CHECK ("${f.name}" IN (${f.enumValues.map(v=>`'${v}'`).join(',')}))`:''}`).join(',\n')},\n  PRIMARY KEY ("tenantId","appId",id)\n);\n`;
feedback.indexes.forEach((fields,i)=>{sql+=`CREATE INDEX ${table}_q${i} ON ${table} (${fields.map(f=>`"${f}"`).join(',')});\n`;});
sql+="INSERT INTO thwkb_migrations(version) VALUES ('002');\nCOMMIT;\n";
fs.writeFileSync(path.join(root,'db/migrations/002_feedback.sql'),sql);
const seedPath=path.join(root,'db/seeds/001_content.json'),seed=JSON.parse(fs.readFileSync(seedPath,'utf8'));seed.entities.Feedback=[];fs.writeFileSync(seedPath,JSON.stringify(seed,null,2)+'\n');
console.log('CR003 applied; Gate A revalidation required; no database migration executed.');
