import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const root=path.resolve(process.argv[2]||'apps/thwkb.zh.huawei');
const scope={tenantId:'thwkb.zh.huawei',appId:'thwkb.zh.huawei'};
const now=new Date().toISOString();
const uuid=key=>{const hex=crypto.createHash('sha256').update(`thwkb:${key}`).digest('hex');return `${hex.slice(0,8)}-${hex.slice(8,12)}-5${hex.slice(13,16)}-a${hex.slice(17,20)}-${hex.slice(20,32)}`;};
const audit=JSON.parse(fs.readFileSync(path.join(root,'docs/validation/image-integrity.json'),'utf8'));
const spec=JSON.parse(fs.readFileSync(path.join(root,'AppSpec.json'),'utf8'));
const bag=Object.fromEntries(spec.entities.map(e=>[e.name,[]]));
const labels=JSON.parse(fs.readFileSync(path.join(root,'docs/design/content-labels.json'),'utf8'));
const assets=Object.fromEntries(audit.assets.map(a=>[uuid(a.key),{...a,assetId:uuid(a.key)}]));
const base=key=>({id:uuid(key),...scope,createdAt:now,updatedAt:now});
const categories=[['zodiac','十二生肖','cover_zodiac'],['beasts','祥瑞小灵兽','cover_beasts'],['people','吉祥娃娃','cover_characters'],['nature','花鸟鱼虫','cover_flora_fauna'],['solar','节气主题','cover_solar_terms'],['festivals','节日主题','cover_festivals'],['original','原创角色','cover_original_ip'],['printworks','年画作品','cover_printworks']];
for(const [index,[key,name,cover]] of categories.entries())bag.Category.push({...base(`category_${key}`),scope:['solar','festivals','printworks'].includes(key)?'artwork':'character',name,sortOrder:index,status:'published'});
for(const [index,[key,name]] of [['origin','起源与历史'],['technique','木刻与套色'],['meaning','题材与寓意']].entries())bag.Category.push({...base(`knowledge_${key}`),scope:'knowledge',name,sortOrder:index,status:'published'});
for(const [index,key] of ['character','background','sticker'].entries())bag.Category.push({...base(`material_${key}`),scope:'material',name:key==='character'?'角色':key==='background'?'背景':'贴纸',sortOrder:index,status:'published'});
const names={ip_taoyao:'桃夭',ip_tuantuan_rabbit:'团团',ip_jilin_qilin:'霁麟',ip_afu_doll:'阿福',ip_feili_koi:'绯鲤',ip_ruiling_flower:'蕊灵',
zodiac_rat_lili:'栗栗',zodiac_ox_yanyan:'砚砚',zodiac_tiger_banban:'斑斑',zodiac_dragon_yunxiao:'云绡',zodiac_snake_qingxian:'青弦',zodiac_horse_zhucai:'逐彩',zodiac_goat_mianjin:'绵锦',zodiac_monkey_lingmo:'灵墨',zodiac_rooster_chencai:'晨彩',zodiac_dog_shouyin:'守印',zodiac_pig_nuofu:'糯福',
beast_lion_tuanshi:'团狮',beast_deer_huazhi:'花枝',beast_bird_yuqing:'羽青',beast_turtle_mojia:'墨甲',beast_tapir_mengtuan:'梦团',beast_fox_jiangwei:'绛尾',beast_flyingfish_landeng:'澜灯'};
const personalities={ip_taoyao:'好奇爽朗，喜欢把复杂的印艺步骤讲清楚。',ip_tuantuan_rabbit:'机灵敏捷，热衷收集不同色彩。',ip_jilin_qilin:'温和谨慎，关心资料来源是否可靠。',ip_afu_doll:'热情可靠，以鼓点为伙伴加油。',ip_feili_koi:'乐观慷慨，喜欢把祝福化为作品。',ip_ruiling_flower:'安静细致，擅长观察四季的颜色。'};
for(const asset of audit.assets.filter(a=>/^(ip_|zodiac_|beast_)/.test(a.key))){
  const key=asset.key,name=names[key],zodiac=key.startsWith('zodiac_')||key==='ip_tuantuan_rabbit',beast=key.startsWith('beast_')||key==='ip_jilin_qilin';
  const category=zodiac?'zodiac':beast?'beasts':key==='ip_afu_doll'?'people':key==='ip_feili_koi'||key==='ip_ruiling_flower'?'nature':'original';
  const core=labels.coreCharacters[key];
  bag.Character.push({...base(`character_${key}`),categoryId:uuid(`category_${category}`),name,series:category,rolePosition:core?.role||`${zodiac?'生肖萌团':beast?'祥瑞小灵兽':'印坊'}伙伴`,
    appearance:core?.appearance||`${name}采用独立的萌系角色轮廓与印艺配饰，完整造型以本项目立绘为准。`,palette:core?.palette||['#F2A6B8','#D95C52','#F5D58A','#FFF8F0','#A8C9AE'],
    costume:core?.costume||'现代国潮服饰或印坊工具配饰，细节见角色主视觉。',personality:personalities[key]||'喜欢观察印坊里的颜色与纹样，乐于和伙伴一起完成作品。',
    culturalInspiration:`从${zodiac?'生肖动物':beast?'祥瑞与自然意象':'花卉、节庆和印艺'}中提取创意线索；不宣称该角色具有传统历史身份。`,
    originalStory:`在本应用原创的桃花印坊里，${name}负责把每天遇到的色彩与纹样记录下来。${personalities[key]||'它会带着自己的小道具，参与伙伴们的套色与构图练习。'}这是现代原创故事，不是非遗历史资料。`,
    historicalSourceIds:[],heroAssetId:uuid(key),status:'published'});
}
for(const asset of audit.assets.filter(a=>/^(ip_|zodiac_|beast_|bg_|sticker_|festival_)/.test(a.key))){
  const kind=asset.key.startsWith('bg_')||asset.key.startsWith('festival_')?'background':asset.key.startsWith('sticker_')?'sticker':'character';
  bag.Material.push({...base(`material_${asset.key}`),categoryId:uuid(`material_${kind}`),kind,name:names[asset.key]||labels.backgrounds[asset.key]||labels.festivals[asset.key]||labels.stickers[asset.key.slice(8)]||spec.brand.visualAssets.find(a=>a.key===asset.key).usage.replace(/^.*：/,''),
    assetId:uuid(asset.key),canvasMetadata:{width:asset.width,height:asset.height,key:asset.key},copyrightOwner:'项目生成资产，正式发布归属归档待完成',sourceType:'original',
    licenseRecord:{source:'OpenAI imagegen',permissionBasis:'用户授权为本项目制作并用于应用',scope:'in_app_composition',manifest:'docs/ImageManifest.md',sha256:asset.sha256,releaseReview:'pending'},status:'published'});
}
const backgrounds=audit.assets.filter(a=>a.key.startsWith('bg_'));
const templateCharacters=[...bag.Character].sort((a,b)=>Number(assets[b.heroAssetId].key.startsWith('ip_'))-Number(assets[a.heroAssetId].key.startsWith('ip_')));
for(const [index,asset] of backgrounds.entries()){
  const hero=templateCharacters[index%templateCharacters.length];const material=bag.Material.find(m=>m.assetId===hero.heroAssetId);
  const layers=[{id:uuid(`template_layer_${index}`),kind:'image',materialId:material.id,imageKey:assets[hero.heroAssetId].key,text:'',x:.5,y:.52,scale:.65,rotation:0,color:'#493B3A'}];
  bag.Template.push({...base(`template_${asset.key}`),name:labels.backgrounds[asset.key],coverAssetId:uuid(asset.key),aspectRatio:'4:5',canvasWidth:800,canvasHeight:1000,
    baseLayers:{schemaVersion:1,width:800,height:1000,backgroundKey:asset.key,colorTheme:'peach',layers},allowedMaterialKinds:['character','background','sticker','seal'],status:'published'});
}
const sources=JSON.parse(fs.readFileSync(path.join(root,'docs/knowledge/sources.json'),'utf8'));
const articles=JSON.parse(fs.readFileSync(path.join(root,'docs/knowledge/articles.json'),'utf8'));
for(const [index,a] of articles.entries())bag.KnowledgeArticle.push({...base(`knowledge_${a.key}`),categoryId:uuid(`knowledge_${index<4?'origin':index<8?'technique':'meaning'}`),title:a.title,summary:a.summary,body:a.body,coverAssetId:uuid(a.coverKey),sourceRecords:[sources.find(s=>s.id===a.sourceId)],factCheckStatus:'verified',status:'published',publishedAt:now});
const banners=[['banner_taohua_print_studio','桃花印坊开门啦','从一张底稿，开启自己的动漫年画世界','workshop',''],['banner_qilin_color_run','和小灵兽一起套色','认识祥瑞意象与原创角色','category',uuid('category_beasts')],['banner_koi_lucky_waves','把好运印成小作品','选择素材，组合自己的祝福','workshop',''],['banner_printmaking_class','一版一色的小秘密','从来源可靠的资料认识年画工艺','knowledge','']];
for(const [key,title,summary,kind,id] of banners)bag.Topic.push({...base(`topic_${key}`),title,summary,coverAssetId:uuid(key),contentRefs:{kind,id},status:'published',publishAt:now});
for(const [index,template] of bag.Template.entries())bag.Artwork.push({...base(`official_${template.id}`),ownerUserId:null,creationId:null,sourceType:'official',title:`印坊习作：${template.name}`,description:'使用本项目原创生成素材与图层模板组合的官方数字作品，不是传统年画原作。',coverAssetId:template.coverAssetId,
  copyrightDeclaration:'项目授权制作的现代原创视觉组合；正式发布前需完成内部归属归档。',rightsEvidence:{source:'本项目图片台账',materialIds:template.baseLayers.layers.map(l=>l.materialId),categoryIds:[uuid('category_printworks'),...(/autumn|snow|peach_garden|koi_pond/.test(assets[template.coverAssetId].key)?[uuid('category_solar')]:[])],canvasState:template.baseLayers,releaseReview:'pending'},visibility:'public'});
for(const asset of audit.assets.filter(a=>a.key.startsWith('festival_')))bag.Artwork.push({...base(`official_${asset.key}`),ownerUserId:null,creationId:null,sourceType:'official',title:labels.festivals[asset.key],description:'现代原创节庆主题插画，不是传统年画原作或历史场景复原。',coverAssetId:uuid(asset.key),copyrightDeclaration:'本项目生成的现代原创场景，使用范围与发布归属见图片版权记录。',
  rightsEvidence:{source:'本项目图片台账',materialIds:[uuid(`material_${asset.key}`)],categoryIds:[uuid('category_festivals'),uuid('category_printworks')],canvasState:{schemaVersion:1,width:800,height:1000,backgroundKey:asset.key,colorTheme:'peach',layers:[]},releaseReview:'pending'},visibility:'public'});
const output={schemaVersion:1,scope,generatedAt:now,mode:'development-content-review',productionReleaseApproved:false,assets,categories:categories.map(([key,name,coverKey])=>({id:uuid(`category_${key}`),name,coverKey,targetKind:['solar','festivals','printworks'].includes(key)?'artwork':'character'})),entities:bag};
fs.mkdirSync(path.join(root,'db/seeds'),{recursive:true});
fs.writeFileSync(path.join(root,'db/seeds/001_content.json'),JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify(Object.fromEntries(Object.entries(bag).map(([k,v])=>[k,v.length]))));
