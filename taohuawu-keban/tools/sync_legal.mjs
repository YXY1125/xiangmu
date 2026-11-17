import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const docs=[['privacy','privacy-policy.md','隐私政策'],['agreement','user-agreement.md','用户协议'],['personalInfo','personal-info-list.md','个人信息收集清单'],['thirdParty','third-party-list.md','第三方及系统能力清单']];
let source='// Generated from this app\'s store legal documents. Edit the sources, then run tools/sync_legal.mjs.\nexport class LegalDocs {\n  static readonly developmentDraft: boolean = true\n';
const records=[];
for(const [method,file,title] of docs){
  const markdown=await fs.readFile(path.join(root,'store',file),'utf8');
  const body=markdown.replace(/^#{1,6}\s+/gm,'').replace(/\[([^\]]+)\]\(([^)]+)\)/g,'$1（$2）').trim();
  source+=`  static ${method}Title(): string { return ${JSON.stringify(title)} }\n  static ${method}Body(): string { return ${JSON.stringify(body)} }\n`;
  records.push({file:`store/${file}`,sha256:crypto.createHash('sha256').update(markdown).digest('hex'),method:`${method}Body`});
}
source+='}\n';
await fs.writeFile(path.join(root,'app/entry/src/main/ets/models/LegalDocs.ets'),source);
await fs.writeFile(path.join(root,'docs/validation/legal-sync.json'),JSON.stringify({at:new Date().toISOString(),draft:true,productionApproved:false,documents:records},null,2)+'\n');
console.log('Synchronized four development legal documents into native ArkTS; not legal or release approval.');
