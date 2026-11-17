import fs from 'node:fs/promises';

/** Secret values stay in server memory; the process manager can store only a protected file path. */
export async function databaseConnection({connectionString,configFile}) {
  try {
    let value=connectionString;
    if(!value){
      if(!configFile)throw new Error();
      const stat=await fs.stat(configFile);
      if(process.platform==='linux'&&(stat.mode&0o077)!==0)throw new Error();
      const config=JSON.parse(await fs.readFile(configFile,'utf8'));
      if(config.host!=='127.0.0.1'||config.port!==55426||config.database!=='thwkb_zh_huawei'||config.user!=='thwkb_app'||typeof config.password!=='string'||config.password.length<32)throw new Error();
      const url=new URL(`postgresql://thwkb_app@127.0.0.1:55426/thwkb_zh_huawei`);url.password=config.password;value=url.href;
    }
    const url=new URL(value);
    if(!['postgres:','postgresql:'].includes(url.protocol)||!url.username||!url.password)throw new Error();
    if(!['127.0.0.1','localhost','[::1]'].includes(url.hostname)&&!['verify-full','verify-ca'].includes(url.searchParams.get('sslmode')))throw new Error();
    return value;
  }catch{throw new Error('Protected application database configuration unavailable or invalid');}
}
