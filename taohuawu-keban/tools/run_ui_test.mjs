import fs from 'node:fs/promises';
import path from 'node:path';
import {execFile,spawn} from 'node:child_process';
import {promisify} from 'node:util';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),exec=promisify(execFile);
const require=createRequire(path.resolve(root,'../../platform/server/package.json')),sharp=require('sharp');
const hdc='D:\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe',APP='thwkb.zh.huawei';
const control=JSON.parse(await fs.readFile(path.join(root,'docs/validation/device/control.json'),'utf8'));
if(control.paused||control.exclusiveForApp!==APP||!/^127\.0\.0\.1:\d{4,5}$/.test(control.target))throw Error('An explicitly assigned healthy exclusive test device is required');
const target=control.target,report={at:new Date().toISOString(),target,app:APP,scope:'actual native UI instrumentation against isolated local development API; not production Gate B',credentials:'generated and retained only in test-process memory; never on argv or logs',steps:[],passed:false};
const run=async args=>(await exec(hdc,['-t',target,...args],{timeout:60000,maxBuffer:1024*1024})).stdout;
try {
 const health=await fetch('http://127.0.0.1:43126/api/v1/platform/health',{headers:{'x-tenant-id':APP},signal:AbortSignal.timeout(4000)}).then(r=>r.json());
 if(health.code!==0||health.data.mode!=='local-development'||health.data.productionReady!==false)throw Error('Isolated development API is required');
 for(const suffix of ['default/entry-default-unsigned.hap','ohosTest/entry-ohosTest-unsigned.hap']){
  const file=path.join(root,'app/entry/build/default/outputs',suffix);await fs.access(file);
  const result=await run(['install',file]);if(!result.includes('install bundle successfully'))throw Error('Native package installation failed');
 }
 await run(['rport','tcp:43126','tcp:43126']);
 await run(['shell','aa','force-stop',APP]);
 const started=Date.now();
 const result=await new Promise((resolve,reject)=>{
  const child=spawn(hdc,['-t',target,'shell','aa','test','-b',APP,'-m','entry_test','-s','unittest','OpenHarmonyTestRunner','-w','300'],{stdio:['ignore','pipe','pipe'],windowsHide:true});
  let raw='';const timer=setTimeout(()=>{child.kill();reject(Error('Native test timeout'));},310000);
  const consume=chunk=>{raw+=chunk;if(raw.length>1024*1024){child.kill();reject(Error('Native test diagnostics exceeded safety limit'));}};
  child.stdout.on('data',consume);child.stderr.on('data',consume);
  child.once('error',()=>{clearTimeout(timer);reject(Error('Native test command unavailable'));});
  child.once('close',code=>{clearTimeout(timer);resolve({code,markers:raw.match(/THWKB_UI_(?:PASS|FAILED|COMPLETE)[A-Za-z0-9 _=;.,:/-]*/g)||[],runnerLoadFailed:/Failed to (?:start|load)|test runner.*(?:not found|failed)/i.test(raw)});});
 });
 report.elapsedSeconds=Math.round((Date.now()-started)/1000);report.commandExit=result.code;report.steps=result.markers;
 report.passed=result.markers.some(s=>s.startsWith('THWKB_UI_COMPLETE'))&&!result.markers.some(s=>s.startsWith('THWKB_UI_FAILED'));
 if(!report.passed)report.failure=result.runnerLoadFailed?'Native test runner could not start':'Native UI flow did not complete; inspect the sanitized failed-step marker';
 const bounds=result.markers.find(s=>s.startsWith('THWKB_UI_PASS canvas-bounds='))?.split('=')[1]?.split(',').map(Number);
 if(bounds?.length===4){
  const [left,top,right,bottom]=bounds.map(Math.round),region={left,top,width:right-left,height:bottom-top};
  const images={};
  for(const state of ['baseline','rotated','scaled']){
   const filename=path.join(root,`docs/validation/device/editor-${state}.png`);
   await run(['file','recv',`/data/app/el2/100/base/${APP}/cache/thwkb-editor-${state}.png`,filename]);
   images[state]=await sharp(filename).extract(region).removeAlpha().raw().toBuffer();
  }
  report.canvasPixelChanges={};
  for(const state of ['rotated','scaled']){
   let changed=0;const a=images.baseline,b=images[state];
   for(let i=0;i<a.length;i+=3)if(Math.max(Math.abs(a[i]-b[i]),Math.abs(a[i+1]-b[i+1]),Math.abs(a[i+2]-b[i+2]))>16)changed++;
   report.canvasPixelChanges[state]={changedPixels:changed,totalPixels:a.length/3,ratio:changed/(a.length/3)};
   if(changed<100){report.passed=false;report.failure=`Actual canvas did not visibly ${state==='rotated'?'rotate':'resize'}; label changes alone are not accepted`;}
  }
 }
 if(report.passed&&!report.canvasPixelChanges){report.passed=false;report.failure='Canvas image comparison evidence is missing';}
 if(report.passed){
  for(const name of ['draft','completed','works'])await run(['file','recv',`/data/app/el2/100/base/${APP}/cache/thwkb-personal-${name}.png`,path.join(root,`docs/validation/device/personal-${name}.png`)]);
 }
}catch{report.passed=false;report.failure='Native instrumentation operation incomplete; raw diagnostics and all supplied text suppressed';}
await fs.mkdir(path.join(root,'docs/validation/device'),{recursive:true});
await fs.appendFile(path.join(root,'docs/validation/device/native-ui-attempts.jsonl'),JSON.stringify(report)+'\n');
await fs.writeFile(path.join(root,'docs/validation/device/native-ui-run.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));process.exitCode=report.passed?0:1;
