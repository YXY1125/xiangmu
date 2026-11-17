import { CharacterProfile, CreativeTemplate, CultureArticle, Exhibition } from '../models/CultureModels'

function character(id: string, name: string, series: string, image: string, personality: string,
  origin: string, meaning: string, story: string): CharacterProfile {
  const item = new CharacterProfile()
  item.id = id
  item.name = name
  item.series = series
  item.image = image
  item.personality = personality
  item.origin = origin
  item.meaning = meaning
  item.story = story
  return item
}

function article(id: string, title: string, category: string, summary: string, body: string,
  image: string, source: string, original: boolean = false): CultureArticle {
  const item = new CultureArticle()
  item.id = id
  item.title = title
  item.category = category
  item.summary = summary
  item.body = body
  item.image = image
  item.sourceNote = source
  item.original = original
  return item
}

function exhibition(id: string, title: string, intro: string, image: string, ids: string[]): Exhibition {
  const item = new Exhibition()
  item.id = id
  item.title = title
  item.intro = intro
  item.image = image
  item.itemIds = ids
  return item
}

function template(id: string, name: string, category: string, ratio: string,
  background: string, asset: string): CreativeTemplate {
  const item = new CreativeTemplate()
  item.id = id
  item.name = name
  item.category = category
  item.ratio = ratio
  item.background = background
  item.defaultAsset = asset
  return item
}

export class CultureCatalog {
  static characters(): CharacterProfile[] {
    return [
      character('qin-xiaojiang', '秦小将', '门神守护团', 'char_qin_xiaojiang', '热情勇敢的守门队长', '以传统门神秦琼文化形象为原型的现代原创改编', '守护家宅、勇毅担当', '原创故事：秦小将每天巡看年画街，把祝福送到每一扇门。'),
      character('yuchi-xiaowei', '尉迟小卫', '门神守护团', 'char_yuchi_xiaowei', '沉稳可靠、外冷内暖', '以传统门神尉迟恭文化形象为原型的现代原创改编', '镇宅纳吉、忠诚守护', '原创故事：尉迟小卫擅长修复旧门板，也守护伙伴的创作灵感。'),
      character('shoumen-tuanzi', '守门团子', '门神守护团', 'char_shoumen_tuanzi', '机灵又爱打瞌睡', '门神文化中的门环、门钉与守护寓意', '平安团圆', '原创故事：小团子能听懂门环的叮当声，提醒大家迎接归人。'),
      character('caishen-tuanzi', '财神团子', '财神纳福团', 'char_caishen_tuanzi', '大方乐观', '传统迎祥纳福观念的原创萌系表达', '勤勉有得、分享喜悦', '原创故事：他不派发横财，而是奖励认真完成每件小事的人。'),
      character('zhaocai-tongzi', '招财童子', '财神纳福团', 'char_zhaocai_tongzi', '行动敏捷、善于整理', '传统童子、如意与元宝等吉祥符号', '勤俭有序、福气相随', '原创故事：童子把散落的祝福分类收好，送给真正需要的人。'),
      character('fuqi-jingling', '福气精灵', '财神纳福团', 'char_fuqi_jingling', '温柔细心', '祥云、如意纹与福文化的原创角色化设计', '福从善意来', '原创故事：精灵会把一句真诚的祝福变成金色云朵。'),
      character('qilin-baobao', '麒麟宝宝', '瑞兽奇遇团', 'char_qilin_baobao', '好奇善良', '传统麒麟瑞兽意象的现代原创改编', '祥瑞仁善', '原创故事：麒麟宝宝用蹄印盖出一朵朵吉祥花。'),
      character('xingshi-tuantuan', '醒狮团团', '瑞兽奇遇团', 'char_xingshi_tuantuan', '活泼爱热闹', '传统醒狮文化与年节祝福', '奋发进取、喜庆吉祥', '原创故事：团团练习眨眼和采青，梦想登上新春大舞台。'),
      character('xiangyun-xiaolong', '祥云小龙', '瑞兽奇遇团', 'char_xiangyun_xiaolong', '自由、富有想象力', '龙纹与祥云纹的原创动漫化表达', '昂扬向上、顺遂如意', '原创故事：小龙把云朵卷成画纸，邀请朋友在天空作画。'),
      character('fufuwa', '福福娃', '福娃迎春团', 'char_fufuwa', '开朗热心', '年节服饰、福字与团圆文化', '迎福团圆', '原创故事：福福娃负责年画街的新春广播，让祝福不迟到。'),
      character('chunhua-tongzi', '春花童子', '福娃迎春团', 'char_chunhua_tongzi', '文静有巧思', '牡丹、莲花等传统花卉吉祥纹样', '花开富贵、生机盎然', '原创故事：她收集四季颜色，为新年调出最明亮的一版红。'),
      character('nianshou-baobao', '年兽宝宝', '福娃迎春团', 'char_nianshou_baobao', '胆小却嘴硬', '年兽传说的友善原创改编', '辞旧迎新、直面成长', '原创故事：怕响声的年兽宝宝学会敲小鼓，终于加入迎春队伍。')
    ]
  }

  static articles(): CultureArticle[] {
    return [
      article('origin', '朱仙镇木版年画的源流', '年画起源', '从民间生活出发，认识朱仙镇木版年画的文化脉络。', '认识项目\n朱仙镇木版年画属于传统美术，2006 年列入第一批国家级非物质文化遗产名录，项目编号为 Ⅶ-7，申报地区为河南省开封市。\n\n理解源流\n公开资料将这一艺术与开封地区的民间生活、印刷和年节文化联系起来。不同介绍对最早起源的措辞并不完全一致，本应用不将某一位“创始人”或单一年份写成定论。\n\n观察练习（原创导读）\n先找画面中面积最大的主体，再看两侧如何呼应。尝试在工坊中用一个角色和少量纹样完成重心稳定的构图。', 'exhibition_classic', '中国非物质文化遗产网，国家级代表性项目“朱仙镇木版年画”：https://www.ihchina.cn/project_details/13906/ 。核验/改写：应用内容编辑，2026-11-13；插图为现代原创。'),
      article('colors', '年画里的传统色彩', '传统色彩', '朱砂、藤黄、青绿如何在套色中相互映衬。', '颜色与材料\n项目名录介绍了以矿物、植物为原料手工制备颜料的用色传统。屏幕上的红、黄、绿只是数字色值，不能据此判断一件实物所含颜料。\n\n读懂对比\n浓重色块与深色轮廓共同形成鲜明的视觉节奏。欣赏时可以观察邻近色块的冷暖差别，以及线条怎样把服饰、面部和装饰分开。\n\n创作练习（原创导读）\n选择一个主色、一个辅助色和一种纸色，再用少量金色点睛。本应用的朱砂红与青绿属于品牌设计方案，不是对全部历史年画配色的归纳。', 'thumb_traditional_colors', '中国非物质文化遗产网，项目名录的用色说明：https://www.ihchina.cn/project_details/13906/ 。核验/改写：应用内容编辑，2026-11-13；数字配色练习为原创导读。'),
      article('carving', '一刀一线：木版雕刻', '木版雕刻', '从画稿到刻版，理解线条为什么有力量。', '从线稿到印版\n祥符区政府的工艺介绍记载了梨木刻版、整备版面和多种雕刻工具。刻版的目的不是把画面简单刻空，而是让需要着墨的部分能够稳定转印。\n\n观察阴阳关系\n留出的线、刻去的空隙以及转折的宽窄，共同影响印出的轮廓。粗细和疏密需要服务于主体辨识，不能只追求细节数量。\n\n数字体验的边界\n工坊提供的是图层编排，不是真实刻版课程。观察线条时可放大作品；请勿在缺乏指导和防护的情况下模仿刀具操作。', 'banner_craft', '开封市祥符区人民政府“朱仙镇木版年画”，制作工艺部分：https://www.xiangfuqu.gov.cn/kfsxfqwz/msyc/pc/content/content_1878635824010838016.html 。核验/改写：应用内容编辑，2026-11-13。'),
      article('printing', '层层着色：套色印刷', '套色印刷', '认识分版、上色、对版和印制。', '套印不是一次完成\n地方政府的工艺资料区分了线版和色版，并介绍逐次印制、调节压力和晾放等操作。具体套印次序应结合画样与工艺记录理解，不宜概括为所有作品都只有固定几步。\n\n为什么需要对版\n让不同颜色在预定位置相遇，是套色效果的重要条件。纸张状态、着墨和操作力度也会改变成品。\n\n观察练习（原创导读）\n在工坊中把两个纹样相叠，先观察完全对齐的效果，再轻微移动上层。数字错位只是一种视觉实验，不代表传统作品一定采用这种处理。', 'banner_craft', '开封市祥符区人民政府“朱仙镇木版年画”，制作工艺及套色说明：https://www.xiangfuqu.gov.cn/kfsxfqwz/msyc/pc/content/content_1878635824010838016.html 。核验/改写：应用内容编辑，2026-11-13。'),
      article('door-gods', '门神文化与守护愿望', '门神文化', '从门上图像读懂人们对平安的朴素期盼。', '图像里的守护\n门神图像承载人们对居所平安的愿望。地方介绍列举了以秦叔宝、尉迟恭为人物的“马上鞭”等题材；不同画样的姿态、器物和组合仍应逐件辨认。\n\n文化原型与原创角色\n本应用的秦小将、尉迟小卫是现代原创改编，其性格与年画街故事不是历史史实，也不是古代画作的原名。\n\n观察练习（原创导读）\n留意成对人物的朝向、动作与重心。尝试让两侧形象相互呼应，而不是把同一图像机械复制。', 'cover_characters', '开封市祥符区人民政府“朱仙镇木版年画”，题材及人物设色说明：https://www.xiangfuqu.gov.cn/kfsxfqwz/msyc/pc/content/content_1878635824010838016.html 。核验/改写：应用内容编辑，2026-11-13；角色设定为原创。'),
      article('patterns', '牡丹、祥云与如意纹', '吉祥纹样', '图案不仅是装饰，也是可阅读的祝愿。', '先看整体，再读装饰\n年画的题材与民间故事、戏曲和神话等文化资源相连。装饰应和人物、器物、画题一起阅读，不能只凭一个局部图形就断定作品的年代、作者或完整寓意。\n\n本应用的纹样表达\n祥云、牡丹、如意和铜钱在工坊中被设计为现代原创图层。这里以云气、花开、称心和富足作为设计联想，不声称每一种解释都适用于所有历史画样。\n\n组合练习（原创导读）\n从一个主题出发，选择两种纹样并控制大小差异。保留主次关系，让装饰帮助传达祝福，而不是遮住主体。', 'banner_festival', '中国国家图书馆中国记忆项目“朱仙镇木版年画”，题材介绍：https://memory.nlc.cn/topic/resource/196 。核验/改写：应用内容编辑，2026-11-13；具体纹样联想与练习为本应用原创导读。'),
      article('customs', '贴年画与新春民俗', '传统民俗', '年画如何进入节日空间和家庭生活。', '年画与节日空间\n国家图书馆中国记忆项目将木版年画与除夕张贴图像的习俗联系起来。年画不仅供观看，也进入门、墙面与家庭的节日布置之中。\n\n传承不是停在过去\n该项目还记录了新中国成立后对传统版样的整理与时代题材创作。传统技艺的延续，既需要保存资料，也包含艺人的持续实践。\n\n记录练习（原创导读）\n回想你所在地区的新春装饰，区分亲眼见闻与听来的传说。设计一张属于自己的祝福卡，并在标题中标明它是当代创作，不将新故事包装成古老习俗。', 'banner_festival', '中国国家图书馆中国记忆项目“朱仙镇木版年画”：https://memory.nlc.cn/topic/resource/196 。核验/改写：应用内容编辑，2026-11-13；地域观察练习为原创导读。')
    ]
  }

  static exhibitions(): Exhibition[] {
    return [
      exhibition('classic', '朱仙镇年画经典作品展', '从构图、色彩与题材认识经典视觉语言。', 'exhibition_classic', ['origin', 'colors']),
      exhibition('door', '门神文化专题展', '看守护形象如何进入民间生活。', 'exhibition_doorgods', ['door-gods']),
      exhibition('fortune', '吉祥寓意专题展', '读懂花卉、器物与纹样组成的祝福。', 'exhibition_auspicious', ['patterns']),
      exhibition('beasts', '瑞兽与传统神话专题展', '在文化原型与原创角色之间建立清晰边界。', 'exhibition_mythology', ['patterns']),
      exhibition('craft', '木版年画制作工艺展', '从画稿、刻版到套色印刷的完整观察。', 'exhibition_craft', ['carving', 'printing']),
      exhibition('spring', '新春年俗主题展', '在节日生活中发现年画的当代表达。', 'exhibition_spring', ['customs'])
    ]
  }

  static templates(): CreativeTemplate[] {
    return [
      template('t01', '门神迎春', '门神画', '3:4', 'bg_cinnabar_cloud', 'char_qin_xiaojiang'),
      template('t02', '双将守福', '门神画', '3:4', 'bg_carved_wood', 'char_yuchi_xiaowei'),
      template('t03', '财运团团', '财神纳福画', '1:1', 'bg_festive_knot', 'char_caishen_tuanzi'),
      template('t04', '如意招财', '财神纳福画', '3:4', 'bg_jade_ruyi', 'char_zhaocai_tongzi'),
      template('t05', '麒麟送瑞', '生肖主题画', '1:1', 'bg_zodiac_ring', 'char_qilin_baobao'),
      template('t06', '醒狮开运', '国潮头像', '1:1', 'bg_window_papercut', 'char_xingshi_tuantuan'),
      template('t07', '云龙逐梦', '手机壁纸', '9:16', 'bg_mountain_cloud', 'char_xiangyun_xiaolong'),
      template('t08', '福到新春', '新春祝福卡', '3:4', 'bg_plum_paper', 'char_fufuwa'),
      template('t09', '花开富贵', '吉祥贺卡', '3:4', 'bg_peony_spring', 'char_chunhua_tongzi'),
      template('t10', '年兽来啦', '节日主题画', '1:1', 'bg_lantern_night', 'char_nianshou_baobao'),
      template('t11', '守门团圆', '福娃主题画', '1:1', 'bg_pomegranate', 'char_shoumen_tuanzi'),
      template('t12', '福云轻舞', '手机壁纸', '9:16', 'bg_golden_waves', 'char_fuqi_jingling'),
      template('t13', '牡丹锦簇', '传统纹样海报', '3:4', 'bg_peach_blossom', 'motif_peony'),
      template('t14', '祥云万里', '传统纹样海报', '9:16', 'bg_porcelain_blue', 'motif_cloud'),
      template('t15', '新春大吉', '新春祝福卡', '1:1', 'bg_ink_paper', 'motif_ruyi'),
      template('t16', '金玉满堂', '吉祥贺卡', '3:4', 'bg_peach_longevity', 'motif_coin'),
      template('t17', '守护头像', '国潮头像', '1:1', 'bg_pine_crane', 'char_qin_xiaojiang'),
      template('t18', '瑞兽合家欢', '福娃主题画', '3:4', 'bg_fish_lotus', 'char_qilin_baobao'),
      template('t19', '花灯迎岁', '节日主题画', '9:16', 'bg_spring_kites', 'motif_cloud'),
      template('t20', '自由画布', '自由创作', '1:1', 'bg_ginkgo_gold', '')
    ]
  }
}
