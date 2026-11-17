export class CreativeBackground {
  id: string = ''
  name: string = ''
  constructor(id: string, name: string) { this.id = id; this.name = name }
}

export const CREATIVE_BACKGROUNDS: CreativeBackground[] = [
  new CreativeBackground('bg_plum_paper', '宣纸梅影'),
  new CreativeBackground('bg_cinnabar_cloud', '朱砂云锦'),
  new CreativeBackground('bg_jade_ruyi', '青绿如意'),
  new CreativeBackground('bg_peony_spring', '牡丹迎春'),
  new CreativeBackground('bg_fish_lotus', '连年有余'),
  new CreativeBackground('bg_pine_crane', '松鹤清和'),
  new CreativeBackground('bg_lantern_night', '上元灯夜'),
  new CreativeBackground('bg_mountain_cloud', '青山云岚'),
  new CreativeBackground('bg_window_papercut', '窗花纳福'),
  new CreativeBackground('bg_carved_wood', '木版余温'),
  new CreativeBackground('bg_golden_waves', '金波流云'),
  new CreativeBackground('bg_porcelain_blue', '青花雅韵'),
  new CreativeBackground('bg_spring_kites', '纸鸢春晴'),
  new CreativeBackground('bg_peach_blossom', '桃花报春'),
  new CreativeBackground('bg_zodiac_ring', '生肖团圆'),
  new CreativeBackground('bg_festive_knot', '吉结良缘'),
  new CreativeBackground('bg_ink_paper', '墨韵新章'),
  new CreativeBackground('bg_ginkgo_gold', '银杏秋金'),
  new CreativeBackground('bg_pomegranate', '榴开百子'),
  new CreativeBackground('bg_peach_longevity', '寿桃呈祥')
]
