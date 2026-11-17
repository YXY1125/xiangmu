import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const exec=promisify(execFile),root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const hdc='D:\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';
const run=async args=>{
  try{return (await exec(hdc,['-t',target,...args],{maxBuffer:8*1024*1024,timeout:20000})).stdout;}
  catch{throw new Error('Device command failed; arguments and raw output suppressed for credential safety.');}
};
const command=process.argv[2],args=process.argv.slice(3),runtime=path.join(root,'.runtime/device');
const out=path.join(root,'docs/validation/device');await fs.mkdir(out,{recursive:true});
const control=JSON.parse(await fs.readFile(path.join(out,'control.json'),'utf8').catch(error=>{if(error.code==='ENOENT')return '{}';throw error;}));
if(control.paused===true)throw new Error('Device input is paused by the recorded safety/environment control. Resolve the recorded cause and confirm this app-exclusive device is healthy before resuming.');
const target=control.target;
if(!/^127\.0\.0\.1:\d{4,5}$/.test(target)||control.exclusiveForApp!=='thwkb.zh.huawei')throw new Error('An explicitly assigned project-exclusive device is required.');
const log=async record=>fs.appendFile(path.join(out,'actions.jsonl'),JSON.stringify({at:new Date().toISOString(),...record})+'\n');
async function ensureTarget(){
  await fs.mkdir(runtime,{recursive:true});
  await run(['shell','uitest','dumpLayout','-p','/data/local/tmp/thwkb-guard.json']);
  const local=path.join(runtime,'foreground.json');await run(['file','recv','/data/local/tmp/thwkb-guard.json',local]);
  const tree=JSON.parse(await fs.readFile(local,'utf8'));await fs.unlink(local);
  const apps=(tree.children||[]).filter(n=>n.attributes?.type==='root'&&n.attributes?.bundleName);
  if(!apps.length||apps[0].attributes.bundleName!=='thwkb.zh.huawei')throw new Error('Stopped: target app is not the foreground application. No UI input performed.');
}
if(command!=='create-account')await ensureTarget();
if(command==='snapshot'||command==='layout'){
  const name=args[0];if(!/^[a-z0-9-]+$/.test(name))throw new Error('Invalid evidence name');
  if(command==='snapshot'){
    await run(['shell','uitest','screenCap','-p','/data/local/tmp/thwkb-evidence.png']);
    await run(['file','recv','/data/local/tmp/thwkb-evidence.png',path.join(out,`${name}.png`)]);
  }
  await run(['shell','uitest','dumpLayout','-p','/data/local/tmp/thwkb-evidence.json']);
  await fs.mkdir(runtime,{recursive:true});const temporary=path.join(runtime,'layout.json');
  await run(['file','recv','/data/local/tmp/thwkb-evidence.json',temporary]);
  const tree=JSON.parse(await fs.readFile(temporary,'utf8')),nodes=[];
  const capturedApp=(tree.children||[]).find(n=>n.attributes?.type==='root'&&n.attributes?.bundleName)?.attributes.bundleName;
  if(capturedApp!=='thwkb.zh.huawei'){
    if(command==='snapshot')await fs.rename(path.join(out,`${name}.png`),path.join(runtime,`rejected-${name}.png`));
    await fs.unlink(temporary);await log({command,name,rejected:'foreground-changed'});
    throw new Error('Evidence rejected: foreground changed during capture.');
  }
  function walk(node){
    const a=node.attributes||{};
    // UI automation may return raw password input values. Persist no input text at all.
    if(['TextInput','TextArea'].includes(a.type)){a.text='[input redacted]';a.originalText='[input redacted]';}
    if(a.visible==='true'&&(a.text||a.clickable==='true'||a.checkable==='true'))nodes.push({type:a.type,text:a.text,bounds:a.bounds,id:a.id,checked:a.checked,enabled:a.enabled});
    for(const child of node.children||[])walk(child);
  }
  walk(tree);await fs.writeFile(path.join(out,`${name}.json`),JSON.stringify(tree));
  await fs.unlink(temporary);await log({command,name,target,app:capturedApp});
  console.log(JSON.stringify(nodes.map(node=>({...node,text:node.text?.length>240?node.text.slice(0,240)+'… [full text retained in evidence]':node.text}))));
}else if(command==='click'||command==='swipe'){
  if(!args.every(a=>/^\d+$/.test(a))||args.length!==(command==='click'?2:4))throw new Error('Coordinates required');
  console.log((await run(['shell','uitest','uiInput',command,...args])).trim());await log({command,args});
}else if(command==='back'){
  await run(['shell','uitest','uiInput','keyEvent','Back']);await log({command});
}else if(command==='create-account'){
  await fs.mkdir(runtime,{recursive:true});
  const account={username:`device_${crypto.randomBytes(5).toString('hex')}`,password:crypto.randomBytes(24).toString('hex'),realName:'设备验证用户',phone:`139${Math.floor(10000000+Math.random()*89999999)}`,tenantId:'thwkb.zh.huawei'};
  const response=await fetch('http://127.0.0.1:43126/api/v1/auth/register',{method:'POST',headers:{'content-type':'application/json','x-tenant-id':account.tenantId},body:JSON.stringify(account)});
  const result=await response.json();if(result.code!==0)throw new Error('Development account registration failed');
  await fs.writeFile(path.join(runtime,'account.json'),JSON.stringify(account),{mode:0o600});await log({command,scope:'local-only'});console.log('Local-only account created; credentials not displayed.');
}else if(command==='fill-account'){
  if(!['username','password'].includes(args[0])||!args.slice(1).every(a=>/^\d+$/.test(a))||args.length!==3)throw new Error('field x y required');
  if(args[0]==='password')throw new Error('Password injection through command-line arguments is forbidden. Use secure in-process UI instrumentation or manual password entry; no password was read or sent.');
  const account=JSON.parse(await fs.readFile(path.join(runtime,'account.json'),'utf8'));
  await run(['shell','uitest','uiInput','inputText',args[1],args[2],account[args[0]]]);
  await log({command,field:args[0]});console.log('Input completed; value not displayed.');
}else throw new Error('Supported: snapshot name | click x y | swipe x1 y1 x2 y2 | back | create-account | fill-account field x y');
