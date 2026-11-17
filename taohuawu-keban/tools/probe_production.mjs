import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const endpoint='https://saas26.qianqi.online/api/v1/biz/thwkb.zh.huawei/home';
const report={at:new Date().toISOString(),method:'GET',endpoint,httpStatus:0,businessCode:null,publicRouteReady:false,scope:'read-only public route probe only; no token, database migration or deployment'};
try {
  const response=await fetch(endpoint,{headers:{'X-Tenant-Id':'thwkb.zh.huawei'},signal:AbortSignal.timeout(15000),redirect:'error'});
  const body=await response.json().catch(()=>null);
  report.httpStatus=response.status;report.businessCode=typeof body?.code==='number'?body.code:null;
  report.publicRouteReady=response.ok&&report.businessCode===0&&body?.data!=null;
}catch{report.networkState='unavailable; sensitive diagnostics suppressed';}
await fs.writeFile(path.join(root,'docs/validation/production-route.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));process.exitCode=report.publicRouteReady?0:2;
