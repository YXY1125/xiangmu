import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {appRoot,repoRoot} from './remote_support.mjs';
const require=createRequire(path.join(repoRoot,'platform/server/package.json')),ts=require('typescript');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function once(source,anchor,replacement){if(source.split(anchor).length!==2)throw new Error('Remote baseline anchor is not unique');return source.replace(anchor,replacement);}
export function patchBaseline(name,source){
 if(source.includes('thwkb'))throw new Error('Baseline already contains application; fresh audit required');
 const reference=name==='app.module.js'?'./modules/thwkb/thwkb.module':'../thwkb/thwkb.module';
 const addRequire=s=>once(s,'"use strict";','"use strict";\nconst thwkb_module_1 = require('+JSON.stringify(reference)+');');
 if(name==='app.module.js')return once(addRequire(source),'        imports: [','        imports: [\n            thwkb_module_1.ThwkbModule,');
 if(name==='modules/privacy/privacy.module.js')return once(addRequire(source),'        imports: [','        imports: [thwkb_module_1.ThwkbModule, ');
 if(name==='tenant/tenant.interceptor.js')return once(source,'    isPublic(path, method) {',String.raw`    isPublic(path, method) {
        if (method === 'GET' && /^\/api\/v1\/biz\/thwkb\.zh\.huawei\/(?:home|characters(?:\/[^/]+)?|knowledge(?:\/[^/]+)?|materials|templates|plaza|artworks\/(?!mine$)[^/]+|authors\/[^/]+)$/.test(path)) return true;`);
 if(name==='modules/privacy/privacy.controller.js'){
  let result=addRequire(source);
  result=once(result,'xsbp, ndlsg) {','xsbp, ndlsg, thwkb) {');
  result=once(result,'        this.ndlsg = ndlsg;','        this.ndlsg = ndlsg;\n        this.thwkb = thwkb;');
  result=once(result,'        ndlsg_store_1.NdlsgStore])','        ndlsg_store_1.NdlsgStore, thwkb_module_1.ThwkbRuntime])');
  result=once(result,'        const tenantId = (0, tenant_interceptor_1.currentTenantId)();',`        const tenantId = (0, tenant_interceptor_1.currentTenantId)();
        if (tenantId === 'thwkb.zh.huawei') return (0, api_response_1.fail)(api_response_1.ErrorCode.FORBIDDEN, '本应用不提供独立批量删除业务数据');`);
  return once(result,"        const tenantId = (0, tenant_interceptor_1.currentTenantId)() || (payload.tenantId ?? '').trim();",`        const tenantId = (0, tenant_interceptor_1.currentTenantId)() || (payload.tenantId ?? '').trim();
        if (tenantId === 'thwkb.zh.huawei') return this.thwkb.deleteCurrentAccount(req.headers?.authorization ?? '', payload);`);
 }
 if(name==='modules/auth/auth.service.js')return once(source,`        const inviteCode = (input.inviteCode ?? '').trim();
        if (tenantId === security_4.LANDSCAPE_TENANT`, `        const inviteCode = (input.inviteCode ?? '').trim();
        if (tenantId === 'thwkb.zh.huawei') {
            if (!/^[A-Za-z0-9_.@-]{3,64}$/.test(username) || password.length > 128 || !input.realName?.trim() || realName.length > 40 || inviteCode.length > 40) return { ok: false, message: '注册字段格式或长度不正确' };
            if (this.accountsForTenant(tenantId).some(item => item.phone === phone)) return { ok: false, message: '该手机号已被注册' };
        }
        if (tenantId === security_4.LANDSCAPE_TENANT`);
 throw new Error('Unapproved shared file');
}
export async function prepare(){
 const baseline=JSON.parse(await fs.readFile(path.join(appRoot,'docs/validation/deploy/api-baseline.json'),'utf8'));
 if(baseline.tenantExists||!baseline.diskTenantsMergedAfterMysql)throw new Error('Tenant registration precondition changed');
 const shared=[];
 for(const entry of baseline.files){
  const buffer=await fs.readFile(path.join(appRoot,'.runtime/deploy/baseline',entry.name));if(hash(buffer)!==entry.sha256)throw new Error('Local baseline checksum mismatch');
  const output=patchBaseline(entry.name,buffer.toString('utf8'));
  const diagnostics=ts.createSourceFile(entry.name,output,ts.ScriptTarget.ES2021,true,ts.ScriptKind.JS).parseDiagnostics;
  if(diagnostics.length)throw new Error('Patched JavaScript syntax invalid');
  shared.push({name:entry.name,before:entry.sha256,after:hash(output),base64:Buffer.from(output).toString('base64')});
 }
 const source=await fs.readFile(path.join(repoRoot,'platform/server/src/modules/thwkb/thwkb.module.ts'),'utf8');
 const compiled=ts.transpileModule(source,{fileName:'thwkb.module.ts',reportDiagnostics:true,compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.CommonJS,experimentalDecorators:true,emitDecoratorMetadata:true,esModuleInterop:true}});
 if(compiled.diagnostics?.some(d=>d.category===ts.DiagnosticCategory.Error))throw new Error('Module compilation failed');
 const module=compiled.outputText,files=[];
 const names=['AppSpec.json','db/seeds/001_content.json','server/package.json','server/production.mjs','server/contracts/entities.json','server/dist/main.js','server/dist/modules/privacy/privacy.controller.js'];
 for(const entry of await fs.readdir(path.join(appRoot,'server/src')))if(entry.endsWith('.mjs'))names.push('server/src/'+entry);
 for(const name of names){const buffer=await fs.readFile(path.join(appRoot,name));files.push({name,sha256:hash(buffer),base64:buffer.toString('base64')});}
 const tenant=JSON.parse(await fs.readFile(path.join(repoRoot,'platform/tenants/thwkb.zh.huawei.json'),'utf8'));
 if(tenant.bundleId!=='thwkb.zh.huawei'||tenant.tenantId!==tenant.bundleId)throw new Error('Tenant identity mismatch');
 const manifest={release:'api-'+new Date().toISOString().replace(/[-:.]/g,''),shared,module:{sha256:hash(module),base64:Buffer.from(module).toString('base64')},files,tenant};
 await fs.writeFile(path.join(appRoot,'.runtime/deploy/release-manifest.json'),JSON.stringify(manifest));
 return {release:manifest.release,shared:shared.map(({name,before,after})=>({name,before,after})),appFileCount:files.length,moduleSha256:manifest.module.sha256,tenant:tenant.tenantId};
}
if(process.argv[1]&&path.resolve(process.argv[1])===new URL(import.meta.url).pathname.replace(/^\/(\w:)/,'$1').replaceAll('/',path.sep))console.log(JSON.stringify(await prepare(),null,2));
