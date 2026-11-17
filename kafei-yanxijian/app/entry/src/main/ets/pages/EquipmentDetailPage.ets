import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { EquipmentItem } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'
import { AuthService } from '../services/AuthService'
import { FavoriteAction } from '../components/design-system/FavoriteAction'

@Entry
@Component
struct EquipmentDetailPage {
  @State item: EquipmentItem = CoffeeCatalog.equipment()[0]
  @State saving: boolean = false
  @State favorited: boolean = false
  @State favoriteFeedback: string = ''
  @State message: string = ''

  aboutToAppear(): void {
    const params = AppRouter.getParams(this.getUIContext()) as Record<string, string>
    const id = params ? params['id'] : ''
    const match = CoffeeCatalog.equipment().find((value: EquipmentItem) => value.id === id)
    if (match) this.item = match
    this.loadFavoriteState()
  }

  private async favorite(): Promise<void> {
    if (!AuthService.isLoggedIn()) {
      this.favoriteFeedback = '请先登录'
      this.message = '请先登录后收藏器具'
      return
    }
    if (this.saving || this.favorited) return
    this.saving = true
    this.favoriteFeedback = ''
    const result = await CoffeeApi.saveFavorite('equipment', this.item.id)
    this.saving = false
    this.favorited = result.code === 0
    this.favoriteFeedback = result.code === 0 ? '' : '收藏失败'
    this.message = result.code === 0 ? '器具已收藏；已同步到“我的收藏”' : result.message
  }

  private async loadFavoriteState(): Promise<void> {
    if (!AuthService.isLoggedIn()) return
    this.saving = true
    const result = await CoffeeApi.hasFavorite('equipment', this.item.id)
    this.saving = false
    if (result.code === 0) {
      this.favorited = result.data === true
      this.favoriteFeedback = ''
    } else {
      this.favoriteFeedback = '状态读取失败'
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
          Blank()
          Text('对比').fontSize(13).fontColor(Theme.colors().brandPrimary)
            .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/EquipmentComparePage', params: { id: this.item.id } }))
        }.width('100%')
        Column({ space: 8 }) {
          Text(this.item.category).fontSize(11).fontColor('#D8C7B2')
          Text(this.item.name).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#F3EBDD')
          Text(this.item.principle).fontSize(14).lineHeight(22).fontColor('#D8C7B2')
        }.padding(24).backgroundColor('#241B17').borderRadius(26).alignItems(HorizontalAlign.Start)
        this.Block('工作原理', this.item.principle)
        this.Block('适用人群', this.item.suitableFor)
        this.Block('使用方法', this.item.usage)
        this.Block('优势与局限', this.item.tradeoffs)
        this.Block('清洁维护', this.item.maintenance)
        if (this.message.length > 0) {
          Text(this.message).fontSize(13).fontColor(this.message.includes('已收藏') ? Theme.colors().success : Theme.colors().danger).width('100%')
        }
        Row() {
          FavoriteAction({
            selected: this.favorited,
            saving: this.saving,
            feedback: this.favoriteFeedback,
            onAction: () => this.favorite()
          })
        }.width('100%').justifyContent(FlexAlign.Center)
        Text('资料不含虚构品牌型号、价格或未经核实的性能参数。').fontSize(10).fontColor(Theme.colors().textTertiary).margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder
  Block(title: string, body: string) {
    Column({ space: 7 }) {
      Text(title).fontSize(19).fontWeight(FontWeight.Bold).width('100%')
      Text(body).fontSize(14).lineHeight(23).fontColor(Theme.colors().textSecondary).width('100%')
    }.padding(18).backgroundColor(Theme.colors().surfaceCard).borderRadius(19).alignItems(HorizontalAlign.Start)
  }
}
