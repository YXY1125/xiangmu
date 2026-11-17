import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {patchBaseline} from '../../tools/prepare_api_release.mjs';
test('Production whitelist patch permits only existing app public GET paths',()=>{
 const original=`class Interceptor {\n    isPublic(path, method) { return path==='/api/v1/platform/health' && method==='GET'; } }\nInterceptor;`;
 const Klass=vm.runInNewContext(patchBaseline('tenant/tenant.interceptor.js',original)),instance=new Klass();
 for(const suffix of ['home','characters','characters/id','knowledge/id','materials','templates','plaza','artworks/id','authors/id'])assert.equal(instance.isPublic('/api/v1/biz/thwkb.zh.huawei/'+suffix,'GET'),true);
 for(const suffix of ['profile','creations','artworks/mine','publications/mine','notifications','favorites','history','feedback','admin/Publication'])assert.equal(instance.isPublic('/api/v1/biz/thwkb.zh.huawei/'+suffix,'GET'),false);
 for(const method of ['POST','PUT','DELETE','PATCH'])assert.equal(instance.isPublic('/api/v1/biz/thwkb.zh.huawei/home',method),false);
 assert.equal(instance.isPublic('/api/v1/biz/foreign/home','GET'),false);
 assert.equal(instance.isPublic('/api/v1/platform/health','GET'),true);
 assert.equal(instance.isPublic('/api/v1/biz/thwkb.zh.huawei/characters/id/extra','GET'),false);
});
test('Deployment patch rejects ambiguous, repeated and unrelated shared edits',()=>{
 const original='"use strict";\nimports: [];';
 assert.throws(()=>patchBaseline('unrelated.js',original));
 assert.throws(()=>patchBaseline('app.module.js','"use strict";\n        imports: [\n        imports: ['));
 const patched=patchBaseline('app.module.js','"use strict";\n        imports: [ExistingModule],');
 assert.ok(patched.includes('ExistingModule'));assert.ok(patched.includes('thwkb_module_1.ThwkbModule'));
 assert.throws(()=>patchBaseline('app.module.js',patched));
});
