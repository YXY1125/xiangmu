import { Theme } from '../components/design-system/Theme'
import { FlowerMaterial, PagePayload } from '../models/FlowerModels'
import { FlowerApiService } from '../services/FlowerApiService'

@Component
export struct FlowerAtlasPage {
  @State private state: string = 'loading'
  @State private message: string = ''
  @State private items: FlowerMaterial[] = []
  @State private query: string = ''
  @State private category: string = ''
  @State private selected: FlowerMaterial | null = null
  private categories: string[] = ['全部', '主花', '配花', '球根花', '线条花', '叶材', '特殊花材']
  onUseMaterial: (materialId: string) => void = () => {}
  onRequireAuth: () => void = () => {}

  aboutToAppear(): void { this.load() }
  private load(): void {
    this.state = 'loading'
    FlowerApiService.materials(this.query, this.category).then((response) => {
      if (response.code !== 0 || response.data === undefined) { this.state = 'error'; this.message = response.message; return }
      const payload = response.data as PagePayload<FlowerMaterial>; this.items = payload.items; this.state = this.items.length > 0 ? 'ready' : 'empty'
    })
  }

  private random(): void {
    if (this.items.length === 0) return
    this.openDetail(this.items[Math.floor(Math.random() * this.items.length)].id)
  }

  private openDetail(id: string): void {
    FlowerApiService.material(id).then((response) => {
      if (response.code === 0 && response.data !== undefined) this.selected = response.data
      else this.message = response.message
    })
  }

  private favorite(item: FlowerMaterial): void {
    const token = AppStorage.get<string>('accessToken') ?? ''
    if (token.length === 0) { this.onRequireAuth(); return }
    FlowerApiService.favoriteMaterial(item.id).then((response) => {
      if (response.code === 0) { item.favorite = !item.favorite; this.items = this.items.slice(); this.selected = item }
      else this.message = response.message
    })
  }

  build() {
    Stack() {
      Column() {
        Column({ space: 12 }) {
          Row() { Column({ space: 3 }) { Text('花材图鉴').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#24362B'); Text('真实花材知识 · 结构化养护与搭配').fontSize(12).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Button('随机认识').height(34).fontSize(12).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.random()) }.width('100%')
          TextInput({ placeholder: '搜索花材、别名或花语', text: this.query }).height(44).backgroundColor('#FFFEFA').borderRadius(16).onChange((value: string) => this.query = value).onSubmit(() => this.load())
          Scroll() { Row({ space: 8 }) { ForEach(this.categories, (value: string) => { Text(value).fontSize(12).fontColor(this.category === (value === '全部' ? '' : value) ? '#FFFFFF' : '#496B55').padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor(this.category === (value === '全部' ? '' : value) ? '#496B55' : '#E2EBDD').borderRadius(99).onClick(() => { this.category = value === '全部' ? '' : value; this.load() }) }, (value: string) => value) } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
        }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 10 })

        if (this.state === 'loading') {
          Column({ space: 10 }) { LoadingProgress().color('#496B55'); Text('正在打开花材图鉴…').fontSize(13).fontColor(Theme.colors().textSecondary) }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.state === 'error') {
          Column({ space: 10 }) { Text('图鉴加载失败').fontSize(18).fontWeight(FontWeight.Bold); Text(this.message).fontSize(13).fontColor(Theme.colors().textSecondary); Button('重试').onClick(() => this.load()) }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.state === 'empty') {
          Column({ space: 10 }) { Image($r('app.media.empty_vase')).width(180).height(170).objectFit(ImageFit.Contain); Text('没有找到匹配的花材').fontSize(17).fontWeight(FontWeight.Bold); Text('换个名称或分类再看看').fontSize(12).fontColor(Theme.colors().textSecondary) }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Grid() {
            ForEach(this.items, (item: FlowerMaterial) => {
              GridItem() { Column({ space: 8 }) { this.Sprite(item); Text(item.name).fontSize(16).fontWeight(FontWeight.Bold).width('100%'); Text(`${item.category} · ${item.season}`).fontSize(11).fontColor(Theme.colors().textSecondary).width('100%') }.alignItems(HorizontalAlign.Start).padding(8).backgroundColor('#FFFEFA').borderRadius(18).onClick(() => this.openDetail(item.id)) }
            }, (item: FlowerMaterial) => item.id)
          }.columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(10).padding({ left: 16, right: 16, bottom: 28 }).layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)

      if (this.selected !== null) {
        Column() {
          Row() { Button('返回').height(36).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.selected = null); Text(this.selected.name).fontSize(22).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1) }.width('100%').padding(16)
          Scroll() {
            Column({ space: 14 }) {
              this.DetailSprite(this.selected)
              Text(this.selected.alias.length > 0 ? `别名：${this.selected.alias}` : this.selected.category).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
              this.InfoBlock('花语与寓意', this.selected.flowerLanguage)
              this.InfoBlock('科属与花期', `${this.selected.family} · ${this.selected.season}`)
              this.InfoBlock('养护与保鲜', this.selected.care)
              this.InfoBlock('花艺搭配建议', this.selected.pairing)
              Row({ space: 10 }) { Button(this.selected.favorite ? '取消收藏' : '收藏花材').layoutWeight(1).backgroundColor('#F4DED7').fontColor('#8A4D53').onClick(() => { if (this.selected !== null) this.favorite(this.selected) }); Button('用它创作').layoutWeight(1).backgroundColor('#496B55').onClick(() => { if (this.selected !== null) this.onUseMaterial(this.selected.id) }) }.width('100%')
            }.width('100%').padding({ left: 16, right: 16, bottom: 34 })
          }.layoutWeight(1).scrollBar(BarState.Off)
        }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage).zIndex(20)
      }
    }.width('100%').height('100%')
  }

  @Builder Sprite(item: FlowerMaterial) {
    Stack({ alignContent: Alignment.TopStart }) { Image(AtlasResource(item.atlasKey)).width(750).height(240).objectFit(ImageFit.Fill).position({ x: -(item.atlasIndex % 5) * 150, y: -Math.floor(item.atlasIndex / 5) * 120 }) }.width('100%').height(120).clip(true).borderRadius(14).backgroundColor('#F3ECE2')
  }
  @Builder DetailSprite(item: FlowerMaterial) {
    Stack({ alignContent: Alignment.TopStart }) { Image(AtlasResource(item.atlasKey)).width(1650).height(528).objectFit(ImageFit.Fill).position({ x: -(item.atlasIndex % 5) * 330, y: -Math.floor(item.atlasIndex / 5) * 264 }) }.width('100%').height(264).clip(true).borderRadius(24).backgroundColor('#F3ECE2')
  }
  @Builder InfoBlock(title: string, content: string) { Column({ space: 6 }) { Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2E4938').width('100%'); Text(content).fontSize(14).lineHeight(22).fontColor(Theme.colors().textSecondary).width('100%') }.alignItems(HorizontalAlign.Start).width('100%').padding(16).backgroundColor('#FFFEFA').borderRadius(18) }
}

function AtlasResource(key: string): Resource {
  if (key === 'atlas_filler') return $r('app.media.atlas_filler')
  if (key === 'atlas_bulb') return $r('app.media.atlas_bulb')
  if (key === 'atlas_line') return $r('app.media.atlas_line')
  if (key === 'atlas_foliage') return $r('app.media.atlas_foliage')
  if (key === 'atlas_special') return $r('app.media.atlas_special')
  return $r('app.media.atlas_main')
}
