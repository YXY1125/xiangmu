import fs from 'node:fs/promises';
import fsSync from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import http from 'node:http';
import {FileRepository,APP} from './src/repository.mjs';
import {ArtBusiness} from './src/service.mjs';
import {createHttpHandler} from './src/http.mjs';
import {check,resolveIdentity} from './src/security.mjs';
import '../tools/build_server.mjs';
const {deleteCurrentAccount}=await import('./dist/modules/privacy/privacy.controller.js');

// This explicitly selected local-only harness does not deploy or alter shared platform source.
check(process.argv.includes('--development-file-store'),400,'必须显式选择本地开发存储');
check(process.env.NODE_ENV!=='production',403,'开发服务禁止作为生产服务运行');
const appRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const platformRoot=path.resolve(appRoot,'../../platform/server');
const runtime=path.resolve(process.env.THWKB_DEV_RUNTIME||path.join(appRoot,'.runtime/local-api'));
const allowedRuntime=path.resolve(appRoot,'.runtime');
check(runtime.startsWith(`${allowedRuntime}${path.sep}`),403,'本地运行数据必须保留在当前应用隔离目录');
await fs.mkdir(path.join(runtime,'server'),{recursive:true});
await fs.mkdir(path.join(runtime,'tenants'),{recursive:true});
const spec=JSON.parse(await fs.readFile(path.join(appRoot,'AppSpec.json'),'utf8'));
await fs.writeFile(path.join(runtime,'tenants',`${APP}.json`),JSON.stringify({tenantId:APP,slug:APP,appName:spec.identity.appName,company:spec.identity.company,bundleId:APP,industryPack:spec.industryPack,brand:{primary:'#D95C52'},featureModules:[]}));
process.chdir(path.join(runtime,'server'));
process.env.STORAGE_BACKEND='json';
const require=createRequire(path.join(platformRoot,'package.json'));
const ts=require('typescript');
// Interpret the current platform TypeScript in memory; no stale dist and no source copying.
require.extensions['.ts']=(module,filename)=>{
  check(path.resolve(filename).startsWith(`${path.join(platformRoot,'src')}${path.sep}`),403,'非平台源码');
  const source=fsSync.readFileSync(filename,'utf8');
  const output=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS,experimentalDecorators:true,emitDecoratorMetadata:true,esModuleInterop:true},fileName:filename});
  module._compile(output.outputText,filename);
};
require('reflect-metadata');
const {AuthService}=require(path.join(platformRoot,'src/modules/auth/auth.service.ts'));
const {TenantRegistryService}=require(path.join(platformRoot,'src/tenant/tenant-registry.service.ts'));
const {MysqlService}=require(path.join(platformRoot,'src/data/mysql/mysql.service.ts'));
const registry=new TenantRegistryService(new MysqlService());registry.onModuleInit();
const auth=new AuthService(registry);auth.onModuleInit();
const seed=JSON.parse(await fs.readFile(path.join(appRoot,'db/seeds/001_content.json'),'utf8'));
const business=new ArtBusiness(new FileRepository(path.join(runtime,'data/business.json'),seed));
const rate=new Map();
const extra=async input=>{
  if(input.path==='/platform/health')return {handled:true,data:{mode:'local-development',storage:'file',productionReady:false}};
  if(input.path==='/privacy/account'&&input.method==='DELETE')return {handled:true,data:await deleteCurrentAccount({auth,business},input.headers,input.body)};
  if(!input.path.startsWith('/auth/'))return null;
  check(input.headers['x-tenant-id']===APP,403,'应用租户不匹配');
  check(input.method==='POST',404,'接口不存在');
  check(!input.body.tenantId||input.body.tenantId===APP,403,'应用租户不匹配');
  if(input.path==='/auth/logout'){
    resolveIdentity(input.headers,auth);auth.revokeAppSession(input.headers.authorization.slice(7));return {handled:true,data:{loggedOut:true}};
  }
  check(['/auth/login','/auth/register'].includes(input.path),404,'接口不存在');
  const key='localhost',previous=rate.get(key)||[];const recent=previous.filter(t=>t>Date.now()-60000);
  check(recent.length<20,429,'操作频繁，请稍后再试');recent.push(Date.now());rate.set(key,recent);
  const body=input.body;
  check(typeof body.username==='string'&&/^[A-Za-z0-9_.@-]{3,64}$/.test(body.username)&&typeof body.password==='string'&&body.password.length>=6&&body.password.length<=128,400,'账号或密码格式不正确');
  if(input.path==='/auth/login'){
    const data=await auth.login(body.username,body.password,APP);check(data,401,'账号或密码错误');return {handled:true,data};
  }
  check(typeof body.realName==='string'&&body.realName.trim().length>0&&body.realName.length<=40,400,'请输入有效昵称');
  const result=await auth.register({username:body.username,password:body.password,phone:body.phone,realName:body.realName,inviteCode:'',deviceModel:'local-development',aaid:''},APP);
  check(result.ok,400,'注册未完成，请检查字段或使用其他账号');return {handled:true,data:result.data};
};
const server=http.createServer(createHttpHandler({business,auth,extra,prefix:'/api/v1',onError:row=>console.error(JSON.stringify(row))}));
server.requestTimeout=15000;server.headersTimeout=10000;
server.listen(Number(process.env.THWKB_DEV_PORT||0),'127.0.0.1',()=>{
  console.log(JSON.stringify({event:'ready',port:server.address().port,mode:'local-development',storage:'file',productionReady:false}));
});
for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>server.close(()=>process.exit(0)));
