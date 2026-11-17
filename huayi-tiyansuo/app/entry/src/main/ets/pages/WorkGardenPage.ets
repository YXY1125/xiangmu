import { Theme } from '../components/design-system/Theme'
import { FlowerWork, PagePayload } from '../models/FlowerModels'
import { FlowerApiService } from '../services/FlowerApiService'
import { StudioPreview } from '../components/StudioPreview'

@Component
export struct WorkGardenPage {
  @State private state: string = 'loading'
  @State private sort: string = 'recommended'
  @State private message: string = ''
  @State private items: FlowerWork[] = []
  @State private selected: FlowerWork | null = null
  @State private authorFilter: string = ''
  onRequireAuth: () => void = () => {}

  aboutToAppear(): void { this.load() }
  private load(): void {
    this.state = 'loading'
    FlowerApiService.works(this.sort).then((response) => {
      if (response.code !== 0 || response.data === undefined) { this.state = 'error'; this.message = response.message; return }
      this.items = (response.data as PagePayload<FlowerWork>).items; this.state = this.items.length > 0 ? 'ready' : 'empty'
    })
  }

  private interact(action: string): void {
    if (this.selected === null) return
    const token = AppStorage.get<string>('accessToken') ?? ''
    if (token.length === 0) { this.onRequireAuth(); return }
    FlowerApiService.interactWork(this.selected.id, action).then((response) => {
      if (response.code === 0 && response.data !== undefined) {
        const index = this.items.findIndex((item: FlowerWork) => item.id === response.data?.id)
        if (index >= 0) this.items[index] = response.data
        this.items = this.items.slice(); this.selected = response.data
      } else this.message = response.message
    })
  }

  private visibleItems(): FlowerWork[] {
    if (this.authorFilter.length === 0) return this.items
    return this.items.filter((item: FlowerWork) => item.authorName === this.authorFilter)
  }

  build() {
    Stack() {
      Column() {
        Column({ space: 10 }) {
          Row() { Column({ space: 3 }) { Text(this.authorFilter.length > 0 ? `${this.authorFilter}的花园` : '作品花园').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#24362B'); Text('让每一束花都有自己的故事').fontSize(12).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); if (this.authorFilter.length > 0) Button('查看全部').height(34).fontSize(11).onClick(() => this.authorFilter = '') }.width('100%')
          Row({ space: 8 }) { this.SortChip('recommended', '推荐'); this.SortChip('latest', '最新'); this.SortChip('popular', '热门') }.width('100%')
        }.padding({ left: 16, right: 16, top: 14, bottom: 12 }).width('100%')
        if (this.state === 'loading') {
          Column({ space: 10 }) { LoadingProgress().color('#496B55'); Text('正在漫步作品花园…').fontSize(13).fontColor(Theme.colors().textSecondary) }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.state === 'error') {
          Column({ space: 10 }) { Text('花园暂时未开放').fontSize(18).fontWeight(FontWeight.Bold); Text(this.message).fontSize(13).fontColor(Theme.colors().textSecondary); Button('重试').onClick(() => this.load()) }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.state === 'empty') {
          Column({ space: 10 }) { Image($r('app.media.empty_vase')).width(190).height(180).objectFit(ImageFit.Contain); Text('还没有公开作品').fontSize(18).fontWeight(FontWeight.Bold); Text('去工坊完成第一件花艺作品吧').fontSize(12).fontColor(Theme.colors().textSecondary) }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Grid() { ForEach(this.visibleItems(), (item: FlowerWork) => { GridItem() { Column({ space: 7 }) { StudioPreview({ snapshot: item.canvas, previewWidth: 164 }); Text(item.title).fontSize(15).fontWeight(FontWeight.Bold).maxLines(1).width('100%'); Row() { Text(item.authorName).fontSize(11).fontColor(Theme.colors().textSecondary).layoutWeight(1); Text(`${item.likeCount} 喜欢`).fontSize(10).fontColor('#D98B91') }.width('100%') }.alignItems(HorizontalAlign.Start).padding(7).backgroundColor('#FFFEFA').borderRadius(20).onClick(() => this.selected = item) } }, (item: FlowerWork) => item.id) }.columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(10).padding({ left: 16, right: 16, bottom: 24 }).layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)

      if (this.selected !== null) {
        Column() {
          Row({ space: 10 }) {
            Button('返回').height(36).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.selected = null)
            Text('作品详情').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
            Button('作者主页').height(34).fontSize(11).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => {
              if (this.selected !== null) {
                this.authorFilter = this.selected.authorName
                this.selected = null
              }
            })
          }.width('100%').padding(16)
          Scroll() {
            Column({ space: 14 }) {
              StudioPreview({ snapshot: this.selected.canvas, previewWidth: 300 })
              Text(this.selected.title).fontSize(26).fontWeight(FontWeight.Bold).width('100%')
              Column({ space: 3 }) {
                Text(this.selected.authorName).fontSize(15).fontWeight(FontWeight.Bold)
                Text('查看作者的公开作品').fontSize(11).fontColor(Theme.colors().textSecondary)
              }.alignItems(HorizontalAlign.Start).width('100%').padding(14).backgroundColor('#FFFEFA').borderRadius(18)
              Text(`主题 · ${this.selected.themeName}`).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
            }.alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 18 })
          }.layoutWeight(1).scrollBar(BarState.Off)
          Row({ space: 10 }) {
            Button(this.selected.liked ? '取消点赞' : '点赞').layoutWeight(1).backgroundColor('#F4DED7').fontColor('#8A4D53').onClick(() => this.interact(this.selected?.liked ? 'unlike' : 'like'))
            Button(this.selected.collected ? '取消收藏' : '收藏').layoutWeight(1).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.interact(this.selected?.collected ? 'uncollect' : 'collect'))
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 14 }).backgroundColor('#FFFEFA')
        }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage).zIndex(20)
      }
    }.width('100%').height('100%')
  }

  @Builder SortChip(value: string, label: string) { Text(label).fontSize(12).fontColor(this.sort === value ? '#FFFFFF' : '#496B55').padding({ left: 18, right: 18, top: 8, bottom: 8 }).backgroundColor(this.sort === value ? '#496B55' : '#E2EBDD').borderRadius(99).onClick(() => { this.sort = value; this.load() }) }
}

