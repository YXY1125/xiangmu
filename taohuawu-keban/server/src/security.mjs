import { APP } from './repository.mjs';

export class BusinessError extends Error {
  constructor(status,message){super(message);this.status=status;}
}
export function check(condition,status,message){if(!condition)throw new BusinessError(status,message);}
export function text(value,max=200,required=false){
  check(typeof value==='string',400,'字段类型错误');
  const result=value.trim();check(result.length<=max&&(!required||result.length>0),400,'字段长度不正确');return result;
}
export function user(identity){
  check(identity&&identity.tenantId===APP&&typeof identity.id==='string'&&identity.id.length>0,401,'请重新登录');
  return identity;
}
export function admin(identity,write=true){
  check(identity&&identity.tenantId===APP&&['tenant_admin','tenant_operator','platform_super'].includes(identity.role),403,'没有本应用管理权限');
  if(write)check(identity.role!=='tenant_operator',403,'当前角色无审核写入权限');
  return identity;
}
export function scoped(row){return row&&row.tenantId===APP&&row.appId===APP;}
export function owned(rows,id,identity,field='userId'){
  user(identity);const row=rows.find(value=>value.id===id&&scoped(value)&&value[field]===identity.id);
  check(row,404,'记录不存在');return row;
}
export function resolveIdentity(headers,auth,optional=false){
  check(headers['x-tenant-id']===APP,403,'应用租户不匹配');
  const header=headers.authorization||'';
  if(!header){check(optional,401,'请先登录');return null;}
  check(header.startsWith('Bearer '),401,'无效的登录凭据');
  const identity=auth.resolveAppSession(header.slice(7));
  user(identity);return identity;
}
