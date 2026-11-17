import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {appRoot,connect,runPython} from './remote_support.mjs';
const file=await fs.readFile(path.join(appRoot,'.runtime/downloads/FindBin.pm'));
if(!file.toString().startsWith('# FindBin.pm')||!file.toString().includes('package FindBin'))throw new Error('Unexpected upstream module');
const sha256=crypto.createHash('sha256').update(file).digest('hex');let client;
try{
  client=await connect();
  const script=`import pathlib,base64,hashlib,json,subprocess,os\nr=pathlib.Path('/www/server/thwkb.zh.huawei');assert json.loads((r/'owner.json').read_text())['app']=='thwkb.zh.huawei'\np=r/'build/perl-lib';p.mkdir(exist_ok=True)\nb=base64.b64decode(${JSON.stringify(file.toString('base64'))});assert hashlib.sha256(b).hexdigest()==${JSON.stringify(sha256)}\nf=p/'FindBin.pm'\nif f.exists():assert f.read_bytes()==b,'Existing module differs'\nelse:f.write_bytes(b)\nenv=dict(os.environ,PERL5LIB=str(p))\na=subprocess.run(['perl','-MFindBin','-MFile::Basename','-MCwd','-e','exit 0'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)\nprint(json.dumps({'module':'FindBin','sha256':${JSON.stringify(sha256)},'dependencyCheckExit':a.returncode,'systemPerlChanged':False,'diagnostic':a.stderr.decode()[:500] if a.returncode else ''}))`;
  const report={at:new Date().toISOString(),source:'https://raw.githubusercontent.com/Perl/perl5/v5.36.0/dist/FindBin/lib/FindBin.pm',...JSON.parse(await runPython(client.connection,script))};
  await fs.writeFile(path.join(appRoot,'docs/validation/deploy/perl-build-dependency.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}catch{console.error('Private build dependency setup failed; system packages unchanged.');process.exitCode=1;}finally{client?.connection.end();}
