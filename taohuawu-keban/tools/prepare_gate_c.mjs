import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const target=path.join(root,'docs/product/GATE_C.md');
const template=await fs.readFile(path.resolve(root,'../../factory/validators/GATE_C.md'),'utf8');
// Copy the actual factory checklist once; do not overwrite a later human acceptance record.
await fs.writeFile(target,'当前项目执行结论：FAIL / 未完成。真实全页面、设备适配、效果图与商店截图尚未验收；所有项保持未认证，不以文件存在自动勾选。整改见交付根 FIX_LIST.md。\n\n'+template,{flag:'wx'});
console.log('Copied authoritative Gate C checklist with explicit fail status; no acceptance boxes changed.');
