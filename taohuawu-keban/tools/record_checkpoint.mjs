import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const exec=promisify(execFile),root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),repo=path.resolve(root,'../..');
const read=async file=>JSON.parse(await fs.readFile(path.join(root,file),'utf8'));
const checks=[];
for(const [name,args] of [
  ['gate-a',['runtimes/validate-gate-a.mjs',`apps/thwkb.zh.huawei`]],
  ['structural',['runtimes/validate-delivery.mjs','apps/thwkb.zh.huawei','--check-only','--json']],
  ['icon',['factory/scripts/icon-validator.mjs','apps/thwkb.zh.huawei']],
  ['logo-brand',['factory/scripts/logo-brand-check.mjs','apps/thwkb.zh.huawei']]
]){
  let output,exitCode=0;
  try{const result=await exec(process.execPath,args,{cwd:repo,maxBuffer:1024*1024});output=result.stdout+result.stderr;}
  catch(error){exitCode=Number(error.code)||1;output=(error.stdout||'')+(error.stderr||'');}
  await fs.writeFile(path.join(root,'docs/validation',`${name}-checkpoint.log`),output);
  checks.push({name,command:`node ${args.join(' ')}`,exitCode});
}
const hap='app/entry/build/default/outputs/default/entry-default-unsigned.hap';
const bytes=await fs.readFile(path.join(root,hap));
const logBytes=await fs.readFile(path.join(root,'docs/validation/build/build-debug.log'));
const log=logBytes.toString(logBytes[0]===0xff&&logBytes[1]===0xfe?'utf16le':'utf8');
const spec=await read('AppSpec.json'),freeze=await read('APPSPEC_FREEZE.json'),tests=await read('docs/validation/tests/server-run.json');
const images=await read('docs/validation/engineering-images.json');
const optional=async file=>{try{return await read(file);}catch(error){if(error.code==='ENOENT')return null;throw error;}};
const postgres=await optional('docs/validation/postgres/run.json'),admin=await optional('docs/validation/admin/build.json'),device=await optional('docs/validation/device/control.json');
const adminTypes=await optional('docs/validation/admin/shared-typecheck.json'),productionProbe=await optional('docs/validation/production-route.json');
const productionProvision=await optional('docs/validation/deploy/postgres-provision.json'),productionDatabaseVerification=await optional('docs/validation/deploy/postgres-verification.json');
const productionApi=await optional('docs/validation/deploy/api-deploy.json'),productionApiTests=await optional('docs/validation/deploy/production-api-tests.json'),productionCleanup=await optional('docs/validation/deploy/api-cleanup-audit.json');
const productionContent=await optional('docs/validation/deploy/content-deploy.json'),productionContentTests=await optional('docs/validation/deploy/production-content-tests.json'),nativeUi=await optional('docs/validation/device/native-ui-run.json'),contentApproval=await optional('docs/validation/content-release-approval.json'),adminIncrement=await optional('docs/validation/admin/increment-build.json');
const report={recordedAt:new Date().toISOString(),stage:'S4/S5 implementation and authorized production API integration evidence; formal Gates incomplete',identity:spec.identity,appSpecVersion:freeze.version,entities:spec.entities.length,apis:spec.apis.length,
  checks,tests,build:{command:'powershell -NoProfile -ExecutionPolicy Bypass -File apps/thwkb.zh.huawei/tools/build.ps1',successful:log.includes('BUILD SUCCESSFUL')&&!log.includes('BUILD FAILED'),signed:false,mode:'debug',artifact:hap,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')},
  images:{total:images.total,originalsPreserved:images.originalsPreserved,engineeringBytes:images.bytes,reductionPercent:images.reductionPercent},
  localPostgres:postgres,adminBuild:admin,adminSharedTypecheck:adminTypes,productionRouteProbe:productionProbe,
  productionDatabaseProvisioning:productionProvision,productionDatabaseVerification,productionApiDeployment:productionApi,productionApiTests,productionCleanup,
  productionContentDeployment:productionContent,productionContentTests,nativeUi,contentReleaseApproval:contentApproval?.decision,adminIncrementBuild:adminIncrement,
  gateB:'not-passed',gateC:'not-complete',productionDatabase:productionApi?.passed?'provisioned-and-migrated; deployed API with real HTTPS auth/isolation subset verified':productionProvision?.phase==='provisioned'?'provisioned-and-migrated; API integration not verified':'not-configured-or-tested',productionMigrationExecuted:productionProvision?.phase==='provisioned',productionDatabaseChecksPassed:productionDatabaseVerification?.phase==='verified',productionApiDeployed:productionApi?.passed===true,productionAdminDeployed:false,productionDeployed:false,deviceClicks:device?.reason||'not-verified',releaseReady:false};
await fs.writeFile(path.join(root,'docs/validation/CHECKPOINT.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({tests:tests.tests,passed:tests.passed,checks:checks.map(c=>({name:c.name,exitCode:c.exitCode})),build:report.build.successful,hapBytes:bytes.length,releaseReady:false}));
