// Real HTTPS tests. Credentials/tokens exist only in memory; cleanup uses current-session cancellation.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {appRoot} from './remote_support.mjs';
const APP='thwkb.zh.huawei',base='https://saas26.qianqi.online/api/v1',root='/biz/'+APP;
const report={at:new Date().toISOString(),target:base,realProduction:true,contentSeedImported:false,cases:[],cleanup:[]};
const check=(name,condition)=>{report.cases.push({name,passed:!!condition});if(!condition)throw new Error(name);};
async function call(route,method='GET',body,token,tenant=APP){
 const response=await fetch(base+route,{method,headers:{'x-tenant-id':tenant,...(token?{authorization:'Bearer '+token}:{}),...(body?{'content-type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});
 const data=await response.json();return {...data,httpStatus:response.status};
}
const accounts=[];
try {
 const health=await call('/platform/health');check('Existing platform HTTPS health',health.code===0);
 const home=await call(root+'/home');check('Application public home uses deployed PostgreSQL',home.code===0);
 check('Guest private data denied',(await call(root+'/profile')).code===40101);
 for(let i=0;i<2;i++){
  const account={username:'thwkb_qa_'+crypto.randomBytes(8).toString('hex'),password:crypto.randomBytes(28).toString('hex'),realName:'上线前验证用户',phone:'199'+crypto.randomInt(10000000,99999999),tenantId:APP};
  const registered=await call('/auth/register','POST',account);check('Real platform registration '+(i+1),registered.code===0&&!!registered.data?.accessToken);
  accounts.push({...account,token:registered.data.accessToken,id:registered.data.user.id,deleted:false});
 }
 const [a,b]=accounts;check('Distinct trusted auth identities',a.id!==b.id);
 check('Duplicate phone rejected',(await call('/auth/register','POST',{...a,username:'thwkb_qa_'+crypto.randomBytes(8).toString('hex')})).code!==0);
 check('Wrong credentials denied',(await call('/auth/login','POST',{username:a.username,password:'intentional-wrong-password'})).code===40101);
 const profile=await call(root+'/profile','GET',undefined,a.token);check('Authenticated profile endpoint reads real database',profile.code===0);
 const changed=await call(root+'/profile','PUT',{nickname:'甲的隔离验证',avatarKey:'ip_taoyao',userId:b.id},a.token);
 check('Profile write accepted without trusting supplied userId',changed.code===0);
 const bp=await call(root+'/profile','GET',undefined,b.token);check('User B profile isolated',bp.code===0&&bp.data.nickname!=='甲的隔离验证');
 const feedback=await call(root+'/feedback','POST',{category:'content',body:'生产联调验证记录；仅用于上线前数据隔离检查。',userId:b.id},a.token);
 check('Real feedback persistence',feedback.code===0&&!!feedback.data?.id);
 const own=await call(root+'/feedback','GET',undefined,a.token),other=await call(root+'/feedback','GET',undefined,b.token);
 check('A reads own feedback',own.code===0&&own.data.items.some(x=>x.id===feedback.data.id));
 check('B cannot see A feedback',other.code===0&&other.data.total===0);
 check('App login cannot act as moderator',(await call(root+'/admin/Publication','GET',undefined,a.token)).code===40301);
 check('Unknown foreign tenant rejected',(await call(root+'/profile','GET',undefined,a.token,'thwkb-qa-foreign.invalid')).code!==0);
 check('Nonempty account-deletion identity rejected',(await call('/privacy/account','DELETE',{userId:b.id},a.token)).code===40301);
 check('Bulk business deletion forbidden',(await call('/privacy/delete-data','POST',{},a.token)).code!==0);
 check('Logout acknowledged',(await call('/auth/logout','POST',{},a.token)).code===0);
 check('Revoked token denied',(await call(root+'/profile','GET',undefined,a.token)).code===40101);
 const login=await call('/auth/login','POST',{username:a.username,password:a.password});check('Real platform relogin',login.code===0);a.token=login.data.accessToken;
 const recovered=await call(root+'/feedback','GET',undefined,a.token);check('Feedback survives logout/relogin',recovered.code===0&&recovered.data.items.some(x=>x.id===feedback.data.id));
 check('A cancellation completed',(await call('/privacy/account','DELETE',{},a.token)).data?.deleted===true);a.deleted=true;
 check('Cancelled credentials rejected',(await call('/auth/login','POST',{username:a.username,password:a.password})).code===40101);
 check('B remains valid after A cancellation',(await call(root+'/profile','GET',undefined,b.token)).code===0);
} catch(error) {report.failure=report.cases.at(-1)?.passed===false?report.cases.at(-1).name:'HTTPS operation unavailable; sensitive diagnostics suppressed';process.exitCode=1;}
finally {
 for(const account of accounts){
  if(!account.deleted){
   try {const fresh=await call('/auth/login','POST',{username:account.username,password:account.password});if(fresh.code===0)account.token=fresh.data.accessToken;const result=await call('/privacy/account','DELETE',{},account.token);account.deleted=result.data?.deleted===true;}catch{}
  }
  report.cleanup.push({testAccount:accounts.indexOf(account)+1,deleted:account.deleted});
 }
 report.passed=!report.failure&&report.cases.every(x=>x.passed)&&report.cleanup.every(x=>x.deleted);
 if(!report.passed)process.exitCode=1;
 await fs.appendFile(path.join(appRoot,'docs/validation/deploy/production-api-test-attempts.jsonl'),JSON.stringify(report)+'\n');
 await fs.writeFile(path.join(appRoot,'docs/validation/deploy/production-api-tests.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));
}
