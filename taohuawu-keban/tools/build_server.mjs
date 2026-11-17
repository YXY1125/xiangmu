import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(path.resolve(root,'../../platform/server/package.json')),ts=require('typescript');
for(const relative of ['main.ts','modules/privacy/privacy.controller.ts']){
  const source=await fs.readFile(path.join(root,'server/src',relative),'utf8');
  const compiled=ts.transpileModule(source,{fileName:relative,reportDiagnostics:true,compilerOptions:{target:ts.ScriptTarget.ES2021,module:ts.ModuleKind.ESNext}});
  if(compiled.diagnostics?.some(d=>d.category===ts.DiagnosticCategory.Error))throw new Error(`TypeScript syntax error in ${relative}`);
  const output=path.join(root,'server/dist',relative.replace(/\.ts$/,'.js'));await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,compiled.outputText);
}
console.log('Compiled app-owned production entry and delegated privacy controller; no server started.');
