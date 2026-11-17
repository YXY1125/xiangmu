import fs from 'node:fs/promises';
import path from 'node:path';
import {appRoot,connect,runPython} from './remote_support.mjs';
const command=process.argv[2];if(!['start','status'].includes(command))throw new Error('Usage: remote_build_postgres.mjs start|status');
const authorization=JSON.parse(await fs.readFile(path.join(appRoot,'docs/validation/deploy/authorization.json'),'utf8'));
if(!authorization.productionDatabaseProvisioning||authorization.app!=='thwkb.zh.huawei')throw new Error('App-specific provisioning authorization missing');
let client;
try{
  client=await connect();
  let script;
  if(command==='start'){
    const worker=await fs.readFile(path.join(appRoot,'tools/production_pg_build.py'),'utf8');
    script=`import os,json,pathlib,subprocess,time\nr=pathlib.Path('/www/server/thwkb.zh.huawei')\nif r.exists():\n assert (r/'owner.json').is_file() and json.loads((r/'owner.json').read_text()).get('app')=='thwkb.zh.huawei','Application directory ownership conflict'\nelse:\n r.mkdir(mode=0o755)\n (r/'owner.json').write_text(json.dumps({'app':'thwkb.zh.huawei','created':time.time()}))\ns=r/'postgres-build-status.json'\nif s.exists():\n state=json.loads(s.read_text())\n assert state.get('phase') in ['failed','built'],'A build is already in progress'\n assert state.get('phase')!='built','PostgreSQL already built; do not overwrite'\n(r/'build-postgres.py').write_text(${JSON.stringify(worker)})\nwith open(r/'build-worker.log','ab') as log:\n p=subprocess.Popen(['python3',str(r/'build-postgres.py')],stdin=subprocess.DEVNULL,stdout=log,stderr=log,start_new_session=True)\nprint(json.dumps({'app':'thwkb.zh.huawei','started':True,'pid':p.pid,'root':str(r),'scope':'application-owned source build only'}))`;
  }else script=`import pathlib,json,os\nr=pathlib.Path('/www/server/thwkb.zh.huawei')\np=r/'postgres-build-status.json'\ns=json.loads(p.read_text()) if p.exists() else {'phase':'not-started'}\na=r/'build/postgresql-17.11.tar.gz'\ns['downloadedBytes']=a.stat().st_size if a.exists() else 0\ns['buildWorkerPids']=[]\nfor pid in os.listdir('/proc'):\n if pid.isdigit():\n  try:\n   args=(pathlib.Path('/proc')/pid/'cmdline').read_bytes()\n   if b'/www/server/thwkb.zh.huawei/build-postgres.py' in args:s['buildWorkerPids'].append(int(pid))\n  except OSError:pass\nprint(json.dumps(s))`;
  const result={at:new Date().toISOString(),...JSON.parse(await runPython(client.connection,script))};
  if(command==='status'&&result.phase==='failed'){
    const diagnostic=await runPython(client.connection,`import pathlib,json\np=pathlib.Path('/www/server/thwkb.zh.huawei/postgres-build.log')\nlines=p.read_text(errors='replace').splitlines() if p.exists() else []\nprint(json.dumps({'publicBuildDiagnostics':lines[-20:]}))`);
    Object.assign(result,JSON.parse(diagnostic));
  }
  await fs.writeFile(path.join(appRoot,'docs/validation/deploy',`postgres-build-${command}.json`),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result,null,2));
}catch{console.error('Application PostgreSQL build operation failed; no shared database/package actions performed; diagnostics suppressed.');process.exitCode=1;}
finally{client?.connection.end();}
