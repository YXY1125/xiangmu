import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import net from 'node:net';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {execFile,spawn} from 'node:child_process';
import {promisify} from 'node:util';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),exec=promisify(execFile);
const bin=path.join(root,'.runtime/postgres-tools/pgsql/bin');
const control=args=>new Promise((resolve,reject)=>{
  // Detached server processes must not inherit execFile's pipes on Windows.
  const child=spawn(path.join(bin,'pg_ctl.exe'),args,{windowsHide:true,stdio:'ignore'});
  child.once('error',reject);child.once('exit',code=>code===0?resolve():reject(new Error('Local PostgreSQL control failed')));
});
await fs.access(path.join(bin,'initdb.exe'));
const runtime=await fs.mkdtemp(path.join(root,'.runtime/pg-qa-'));
const data=path.join(runtime,'data'),pwfile=path.join(runtime,'init-password');
const password=crypto.randomBytes(32).toString('hex');
const server=net.createServer();await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const port=server.address().port;await new Promise(resolve=>server.close(resolve));
const outputDir=path.join(root,'docs/validation/postgres');await fs.mkdir(outputDir,{recursive:true});
let started=false,exitCode=1,output='',version='',stage='initdb';
try {
  await fs.writeFile(pwfile,password+'\n',{mode:0o600});
  const init=await exec(path.join(bin,'initdb.exe'),['-D',data,'-U','thwkb_qa','--pwfile='+pwfile,'-A','scram-sha-256','--encoding=UTF8','--locale=C'],{windowsHide:true,maxBuffer:1024*1024});
  await fs.unlink(pwfile);
  output+='Isolated local cluster initialized with SCRAM authentication.\n';
  stage='local-server-start';
  await control(['-D',data,'-l',path.join(runtime,'postgres.log'),'-o',`-h 127.0.0.1 -p ${port}`,'-w','-t','25','start']);started=true;
  const require=createRequire(path.resolve(root,'../../platform/server/package.json')),{Pool}=require('pg');
  const url=new URL(`postgresql://thwkb_qa@127.0.0.1:${port}/postgres`);url.password=password;
  stage='local-database-create';const pool=new Pool({connectionString:url.href,max:1});
  try {version=(await pool.query('SHOW server_version')).rows[0].server_version;await pool.query('CREATE DATABASE thwkb_qa_local');}finally{await pool.end();}
  url.pathname='/thwkb_qa_local';
  stage='tests';const run=spawn(process.execPath,['--test',path.join(root,'server/pg-test/postgres.test.mjs')],{windowsHide:true,env:{...process.env,THWKB_PG_TEST_URL:url.href},stdio:['ignore','pipe','pipe']});
  for(const stream of [run.stdout,run.stderr])stream.on('data',chunk=>{output+=chunk;process.stdout.write(chunk);});
  exitCode=await new Promise(resolve=>run.on('exit',resolve));
} catch(error) {
  output+=`Stage: ${stage}; exit code: ${typeof error.code==='number'?error.code:'unavailable'}\n`;
  // initdb has no connection string or password argv. Retain only its ordinary diagnostics.
  if(stage==='initdb')output+=String(error.stderr||'').split(/\r?\n/).filter(line=>/error:|fatal:|could not|administrator|denied/i.test(line)).join('\n')+'\n';
  output+='FAILED: isolated local PostgreSQL setup or test execution failed; connection and credential diagnostics suppressed.\n';
  console.error('Local PostgreSQL verification failed; no production action was performed.');
} finally {
  await fs.unlink(pwfile).catch(()=>{});
  if(started)await control(['-D',data,'-m','fast','-w','stop']).catch(()=>{output+='WARNING: local PostgreSQL shutdown needs attention.\n';exitCode=1;});
  await fs.writeFile(path.join(outputDir,'tests.log'),output);
  const count=name=>Number(output.match(new RegExp(`(?:^|\\n)(?:#|ℹ)?\\s*${name}\\s+(\\d+)`))?.[1]||0);
  const report={at:new Date().toISOString(),command:'node apps/thwkb.zh.huawei/tools/test_postgres.mjs',exitCode,version,tests:count('tests'),passed:count('pass'),failed:count('fail'),scope:'isolated ephemeral local PostgreSQL; actual app migrations and repository',host:'127.0.0.1',systemServiceInstalled:false,productionConfigured:false,productionMigrationExecuted:false,gateBPassed:false};
  await fs.writeFile(path.join(outputDir,'run.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report));
}
process.exitCode=exitCode||0;
