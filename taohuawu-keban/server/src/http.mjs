import { BusinessError, check, resolveIdentity, admin } from './security.mjs';
import { APP } from './repository.mjs';
import crypto from 'node:crypto';

export const ROOT=`/biz/${APP}`;
const lists=['characters','knowledge','materials','templates','plaza','creations','artworks/mine','publications/mine','notifications','favorites','history','feedback'];
const publicLists=['characters','knowledge','materials','templates','plaza'];
const codes={400:40001,401:40101,403:40301,404:40401,409:40901,413:41301,422:42201,429:42901};

/** Auth and admin resolvers must be supplied by the host, never by the request body. */
export function createDispatcher({business,auth,resolveAdmin}) {
  return async ({method,path,query={},headers={},body={}})=>{
    check(body&&typeof body==='object'&&!Array.isArray(body),400,'请求格式不正确');
    check(path.startsWith(`${ROOT}/`),404,'接口不存在');
    const route=path.slice(ROOT.length+1);let parts;
    try{parts=route.split('/').map(decodeURIComponent);}catch{check(false,400,'接口路径编码不正确');}
    if(parts[0]==='admin'){
      check(headers['x-tenant-id']===APP,403,'应用租户不匹配');
      check(typeof resolveAdmin==='function',403,'管理认证尚未接入');
      const identity=await resolveAdmin(headers);admin(identity,method!=='GET');
      if(method==='GET'&&parts.length===2)return business.adminList(identity,parts[1]);
      if(method==='PUT'&&parts.length===4&&parts[1]==='publications'&&parts[3]==='review')return business.review(identity,parts[2],body);
      if(method==='PUT'&&parts.length===4&&parts[1]==='reports'&&parts[3]==='resolve')return business.resolveReport(identity,parts[2],body);
      if(method==='PUT'&&parts.length===4&&parts[1]==='feedback'&&parts[3]==='reply')return business.replyFeedback(identity,parts[2],body);
      if(method==='PUT'&&parts.length===5&&parts[1]==='content'&&parts[4]==='state')return business.contentState(identity,parts[2],parts[3],body);
      check(false,404,'管理接口不存在');
    }
    const guest=method==='GET'&&(route==='home'||publicLists.includes(route)||parts.length===2&&['characters','knowledge','artworks','authors'].includes(parts[0])&&parts[1]!=='mine');
    const identity=resolveIdentity(headers,auth,guest);
    if(method==='GET'){
      if(route==='home')return business.home(identity);
      if(route==='profile')return business.profile(identity);
      if(parts.length===2&&parts[0]==='authors')return business.author(parts[1],identity);
      if(lists.includes(route))return business.list(route,query,identity);
      if(parts.length===2&&['characters','knowledge','artworks','creations'].includes(parts[0]))return business.detail(parts[0],parts[1],identity);
    }
    if(method==='POST'){
      if(route==='creations')return business.saveCreation(identity,body);
      if(route==='favorites')return business.favorite(identity,body);
      if(route==='history')return business.browse(identity,body);
      if(route==='feedback')return business.feedback(identity,body);
      if(parts.length===3&&parts[0]==='creations'&&parts[2]==='artwork')return business.makeArtwork(identity,parts[1],body);
      if(parts.length===3&&parts[0]==='artworks'){
        if(parts[2]==='publications')return business.submit(identity,parts[1],body);
        if(parts[2]==='like')return business.like(identity,parts[1]);
        if(parts[2]==='reports')return business.report(identity,parts[1],body);
      }
    }
    if(method==='PUT'){
      if(route==='profile')return business.updateProfile(identity,body);
      if(parts.length===2&&parts[0]==='creations')return business.saveCreation(identity,body,parts[1]);
      if(parts.length===3&&parts[0]==='notifications'&&parts[2]==='read')return business.readNotification(identity,parts[1]);
    }
    if(method==='DELETE'){
      if(parts.length===2&&parts[0]==='creations')return business.archiveCreation(identity,parts[1]);
      if(parts.length===3&&parts[0]==='favorites')return business.favorite(identity,{targetType:parts[1],targetId:parts[2]},true);
      if(parts.length===3&&parts[0]==='artworks'&&parts[2]==='like')return business.like(identity,parts[1],true);
    }
    check(false,404,'接口不存在');
  };
}

async function readBody(request){
  let size=0;const chunks=[];
  for await(const chunk of request){size+=chunk.length;check(size<=256*1024,413,'请求内容过大');chunks.push(chunk);}
  if(!size)return {};
  check((request.headers['content-type']||'').split(';')[0]==='application/json',400,'需要 JSON 请求');
  try {const value=JSON.parse(Buffer.concat(chunks).toString('utf8'));check(value&&typeof value==='object'&&!Array.isArray(value),400,'请求格式不正确');return value;}
  catch(error){if(error instanceof BusinessError)throw error;throw new BusinessError(400,'JSON 格式不正确');}
}

/** Reusable native HTTP adapter; production host can instead call the dispatcher. */
export function createHttpHandler(options){
  const dispatch=createDispatcher(options);
  return async (request,response)=>{
    const requestId=crypto.randomUUID();
    response.setHeader('Content-Type','application/json; charset=utf-8');
    response.setHeader('Cache-Control','no-store');response.setHeader('X-Content-Type-Options','nosniff');
    try {
      const url=new URL(request.url,'http://localhost');
      const body=await readBody(request);
      if(options.prefix)check(url.pathname.startsWith(`${options.prefix}/`),404,'接口不存在');
      const input={method:request.method,path:options.prefix?url.pathname.slice(options.prefix.length):url.pathname,query:Object.fromEntries(url.searchParams),headers:request.headers,body};
      const data=options.extra&&await options.extra(input);
      const result=data?.handled?data.data:await dispatch(input);
      response.statusCode=200;response.end(JSON.stringify({code:0,message:'ok',data:result,requestId}));
    }catch(error){
      const status=error instanceof BusinessError?error.status:500;
      response.statusCode=status;
      response.end(JSON.stringify({code:codes[status]||50001,message:status===500?'服务处理失败，请稍后重试':error.message,data:null,requestId}));
      // Never log request bodies, headers, connection strings or exception messages.
      if(status===500)options.onError?.({requestId,type:error.name||'Error'});
    }
  };
}
