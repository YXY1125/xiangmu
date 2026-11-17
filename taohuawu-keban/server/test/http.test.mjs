import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {APP} from '../src/repository.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const seed=JSON.parse(await fs.readFile(path.join(root,'db/seeds/001_content.json'),'utf8'));
function start(runtime){
  return new Promise((resolve,reject)=>{
    const child=spawn(process.execPath,[path.join(root,'server/dev.mjs'),'--development-file-store'],{env:{...process.env,NODE_ENV:'test',THWKB_DEV_RUNTIME:runtime},stdio:['ignore','pipe','pipe']});
    const timer=setTimeout(()=>{child.kill();reject(new Error('Local server startup timed out'));},15000);let pending='';
    child.stdout.on('data',chunk=>{pending+=chunk;for(const line of pending.split(/\r?\n/)){try{const event=JSON.parse(line);if(event.event==='ready'){clearTimeout(timer);resolve({child,base:`http://127.0.0.1:${event.port}/api/v1`});}}catch{}}});
    child.stderr.on('data',()=>{});child.once('exit',code=>{clearTimeout(timer);if(code)reject(new Error(`Local server exited (${code}), no sensitive output retained`));});
  });
}
async function stop(server){if(server.child.exitCode!==null)return;const done=new Promise(resolve=>server.child.once('exit',resolve));server.child.kill();await done;}
test('HTTP integration with current SaaS26 AuthService: register/login/logout/restart and A/B isolation',async t=>{
  const parent=path.join(root,'.runtime');await fs.mkdir(parent,{recursive:true});const runtime=await fs.mkdtemp(path.join(parent,'integration-'));
  let server=await start(runtime);t.after(async()=>{
    await stop(server);const resolved=await fs.realpath(runtime),expectedParent=await fs.realpath(parent);
    assert.ok(path.dirname(resolved)===expectedParent&&path.basename(resolved).startsWith('integration-'));
    await fs.rm(resolved,{recursive:true,force:true});
  });
  const call=async(route,method='GET',body,token,tenant=APP)=>{
    const response=await fetch(`${server.base}${route}`,{method,headers:{'x-tenant-id':tenant,...(token?{authorization:`Bearer ${token}`} : {}),...(body?{'content-type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});
    return {status:response.status,...await response.json()};
  };
  const password=crypto.randomBytes(24).toString('hex');
  const signup=async(username,phone)=>call('/auth/register','POST',{username,password,realName:username,phone,tenantId:APP});
  const ra=await signup('integration_a','13800000001'),rb=await signup('integration_b','13800000002');
  assert.equal(ra.code,0);assert.equal(rb.code,0);assert.notEqual(ra.data.user.id,rb.data.user.id);
  const storedUsers=JSON.parse(await fs.readFile(path.join(runtime,'data/registered-users.json'),'utf8'));
  assert.ok(storedUsers.every(u=>u.password.startsWith('scrypt$')&&u.password!==password));
  const ta=ra.data.accessToken,tb=rb.data.accessToken;
  assert.equal((await call('/auth/login','POST',{username:'integration_a',password:'wrong-value'})).status,401);
  assert.equal((await call(`/biz/${APP}/home`)).code,0);
  assert.equal((await call(`/biz/${APP}/creations`)).status,401);
  const body={title:'HTTP 持久化作品',templateId:seed.entities.Template[0].id,document:seed.entities.Template[0].baseLayers,status:'completed',revision:0,userId:rb.data.user.id};
  const saved=await call(`/biz/${APP}/creations`,'POST',body,ta);assert.equal(saved.code,0);
  const id=saved.data.id;
  assert.equal((await call(`/biz/${APP}/creations/${id}`,'GET',undefined,tb)).status,404);
  assert.equal((await call(`/biz/${APP}/creations`,'GET',undefined,tb)).data.total,0);
  assert.equal((await call(`/biz/${APP}/creations/${id}`,'PUT',{...body,revision:1},tb)).status,404);
  assert.equal((await call(`/biz/${APP}/creations`,'GET',undefined,ta,'foreign.tenant')).status,403);
  assert.equal((await call('/auth/logout','POST',{},ta)).code,0);
  assert.equal((await call(`/biz/${APP}/creations/${id}`,'GET',undefined,ta)).status,401);
  await stop(server);server=await start(runtime);
  const login=await call('/auth/login','POST',{username:'integration_a',password});assert.equal(login.code,0);
  const recovered=await call(`/biz/${APP}/creations/${id}`,'GET',undefined,login.data.accessToken);
  assert.equal(recovered.code,0);assert.deepEqual(recovered.data.document,body.document);
  const other=await call('/auth/login','POST',{username:'integration_b',password});
  assert.equal((await call(`/biz/${APP}/creations`,'GET',undefined,other.data.accessToken)).data.total,0);
  assert.equal((await call(`/biz/${APP}/admin/Publication`,'GET',undefined,login.data.accessToken)).status,403);
  const feedback=await call(`/biz/${APP}/feedback`,'POST',{category:'content',body:'建议增加套色步骤说明',userId:rb.data.user.id},login.data.accessToken);assert.equal(feedback.code,0);
  assert.equal((await call(`/biz/${APP}/feedback`,'GET',undefined,other.data.accessToken)).data.total,0);
  assert.equal((await call(`/biz/${APP}/authors/official`)).data.artworks.length,seed.entities.Artwork.length);
  const oversized=await fetch(`${server.base}/biz/${APP}/creations`,{method:'POST',headers:{'x-tenant-id':APP,'content-type':'application/json',authorization:`Bearer ${login.data.accessToken}`},body:JSON.stringify({text:'x'.repeat(270000)})});assert.equal(oversized.status,413);
  assert.equal((await call('/privacy/account','DELETE',{userId:rb.data.user.id},login.data.accessToken)).status,403);
  assert.equal((await call('/privacy/account','DELETE',{},login.data.accessToken)).data.deleted,true);
  assert.equal((await call('/auth/login','POST',{username:'integration_a',password})).status,401);
  assert.equal((await call(`/biz/${APP}/creations`,'GET',undefined,other.data.accessToken)).code,0);
});
