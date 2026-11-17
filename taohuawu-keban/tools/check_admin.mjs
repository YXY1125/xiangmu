import path from 'node:path';
import fs from 'node:fs/promises';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),repo=path.resolve(root,'../..');
const admin=path.join(repo,'platform/admin');
const {build}=await import(pathToFileURL(path.join(admin,'node_modules/vite/dist/node/index.js')));
const {default:vue}=await import(pathToFileURL(path.join(admin,'node_modules/@vitejs/plugin-vue/dist/index.mjs')));
let output='';const write=console.log;
console.log=(...args)=>{output+=args.join(' ')+'\n';write(...args);};
let successful=false;
try {
  const result=await build({configFile:false,root:admin,plugins:[vue()],build:{outDir:path.join(root,'.runtime/admin-build'),emptyOutDir:false,rollupOptions:{preserveEntrySignatures:'strict',input:path.join(admin,'src/views/ThwkbOperationsView.vue')},reportCompressedSize:false}});
  const outputs=Array.isArray(result)?result.flatMap(r=>r.output):result.output;
  if(!outputs.some(o=>o.type==='chunk'&&o.isEntry&&o.exports.includes('default')))throw Error('Actual component export was removed');
  successful=true;
} finally {
  await fs.mkdir(path.join(root,'docs/validation/admin'),{recursive:true});
  await fs.writeFile(path.join(root,'docs/validation/admin/build.log'),output);
  await fs.writeFile(path.join(root,'docs/validation/admin/build.json'),JSON.stringify({at:new Date().toISOString(),successful,scope:'app-specific Vue entry only; no platform deployment; no browser flow acceptance',command:'node apps/thwkb.zh.huawei/tools/check_admin.mjs'},null,2)+'\n');
}
