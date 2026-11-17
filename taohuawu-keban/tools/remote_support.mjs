import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
export const appRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export const repoRoot=path.resolve(appRoot,'../..');
const require=createRequire(path.join(repoRoot,'runtimes/package.json')),{Client}=require('ssh2');
export async function connect(){
  const config={};
  for(const line of (await fs.readFile(path.join(repoRoot,'runtimes/colleague/saas26.env.deploy'),'utf8')).split(/\r?\n/)){
    const s=line.trim();if(!s||s.startsWith('#'))continue;const i=s.indexOf('=');if(i>0)config[s.slice(0,i).trim()]=s.slice(i+1).trim();
  }
  if(config.SAAS_SITE!=='saas26'||config.SAAS_REMOTE_ROOT!=='/www/wwwroot/saas26.qianqi.online'||config.SAAS_PM2_NAME!=='harmonyos-saas26-api')throw new Error('Deployment target identity mismatch');
  const directory=path.join(appRoot,'.runtime/deploy');await fs.mkdir(directory,{recursive:true});
  const pinFile=path.join(directory,'ssh-host.json');let pin=null;
  try{pin=JSON.parse(await fs.readFile(pinFile,'utf8'));}catch(e){if(e.code!=='ENOENT')throw e;}
  let observed='';const connection=new Client();
  await new Promise((resolve,reject)=>{
    connection.once('ready',resolve).once('error',()=>reject(new Error('SSH unavailable; sensitive diagnostics suppressed')));
    connection.connect({host:config.SAAS_SSH_HOST,port:Number(config.SAAS_SSH_PORT||22),username:config.SAAS_SSH_USER,password:config.SAAS_SSH_PASS,readyTimeout:20000,keepaliveInterval:10000,
      hostVerifier:key=>{observed=crypto.createHash('sha256').update(key).digest('hex');return !pin||pin.host===config.SAAS_SSH_HOST&&pin.sha256===observed;}});
  });
  if(!pin)await fs.writeFile(pinFile,JSON.stringify({host:config.SAAS_SSH_HOST,sha256:observed,trust:'first use of existing authorized deployment target; subsequent calls pinned'},null,2),{flag:'wx'});
  return {connection,hostFingerprint:observed};
}
export function runPython(connection,script,input){
  return new Promise((resolve,reject)=>{
    // Program/config data travels over encrypted stdin, never secret-bearing argv.
    connection.exec('python3 -',(error,stream)=>{
      if(error)return reject(new Error('Remote command unavailable'));
      let stdout='';stream.on('data',chunk=>{stdout+=chunk;if(stdout.length>1024*1024)stream.destroy();});
      stream.stderr.on('data',()=>{});
      stream.once('close',code=>code===0?resolve(stdout):reject(new Error('Remote operation failed; sensitive diagnostics suppressed')));
      stream.end(script+(input?'\n'+input:'')+'\n');
    });
  });
}
