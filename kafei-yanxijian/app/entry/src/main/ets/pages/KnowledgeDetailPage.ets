import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { CoffeeApi } from '../services/CoffeeApi'
import { AuthService } from '../services/AuthService'
import { KnowledgeItem } from '../models/CoffeeModels'
import { FavoriteAction } from '../components/design-system/FavoriteAction'

@Entry
@Component
struct KnowledgeDetailPage {
  @State item: KnowledgeItem = CoffeeCatalog.knowledge()[0]
  @State saving: boolean = false
  @State favoriteSaving: boolean = false
  @State favorited: boolean = false
  @State favoriteFeedback: string = ''
  @State message: string = ''
  aboutToAppear(): void { const p = AppRouter.getParams(this.getUIContext()) as Record<string, string>; const id = p ? p['id'] : ''; const match = CoffeeCatalog.knowledge().find((v: KnowledgeItem) => v.id === id); if (match) this.item = match; this.loadFavoriteState() }
  private async learn(): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.message = '请先登录后记录学习进度'; return }
    if (this.saving) return
    this.saving = true
    const result = await CoffeeApi.saveLearning(this.item.id)
    this.saving = false
    this.message = result.code === 0 ? '已同步到学习记录与成长统计' : result.message
  }
  private async favorite(): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.favoriteFeedback = '请先登录'; this.message = '请先登录后收藏知识'; return }
    if (this.favoriteSaving || this.favorited) return
    this.favoriteSaving = true
    this.favoriteFeedback = ''
    const result = await CoffeeApi.saveFavorite('knowledge', this.item.id)
    this.favoriteSaving = false
    this.favorited = result.code === 0
    this.favoriteFeedback = result.code === 0 ? '' : '收藏失败'
    this.message = result.code === 0 ? '收藏成功；已同步到“我的收藏”' : result.message
  }
  private async loadFavoriteState(): Promise<void> {
    if (!AuthService.isLoggedIn()) return
    this.favoriteSaving = true
    const result = await CoffeeApi.hasFavorite('knowledge', this.item.id)
    this.favoriteSaving = false
    if (result.code === 0) {
      this.favorited = result.data === true
      this.favoriteFeedback = ''
    } else {
      this.favoriteFeedback = '状态读取失败'
    }
  }
  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Blank(); FavoriteAction({ selected: this.favorited, saving: this.favoriteSaving, feedback: this.favoriteFeedback, onAction: () => this.favorite() }) }.width('100%')
        Text(this.item.category.toUpperCase()).fontSize(11).fontWeight(FontWeight.Bold).fontColor(Theme.colors().brandPrimary).width('100%')
        Text(this.item.title).fontSize(30).fontWeight(FontWeight.Bold).lineHeight(40).width('100%')
        Text(`${this.item.readingMinutes} 分钟阅读`).fontSize(12).fontColor(Theme.colors().textTertiary).width('100%')
        Text(this.item.summary).fontSize(17).lineHeight(28).fontColor(Theme.colors().textPrimary).width('100%')
        this.Paragraph('观察重点', this.item.observation)
        this.Paragraph('练习建议', this.item.practice)
        if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor(this.message.includes('已') ? Theme.colors().success : Theme.colors().danger).width('100%') }
        Button(this.saving ? '正在同步…' : '标记为已学习').enabled(!this.saving).width('100%').backgroundColor(Theme.colors().brandPrimary).borderRadius(20).onClick(() => this.learn())
        Text('内容版本：1.0 · 公共知识，不含品牌价格或医疗建议').fontSize(10).fontColor(Theme.colors().textTertiary).margin({ bottom: 24 })
      }.padding(18).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
  @Builder Paragraph(title: string, body: string) { Column({ space: 8 }) { Text(title).fontSize(20).fontWeight(FontWeight.Bold).width('100%'); Text(body).fontSize(15).lineHeight(25).fontColor(Theme.colors().textSecondary).width('100%') }.padding(18).backgroundColor(Theme.colors().surfaceCard).borderRadius(20).alignItems(HorizontalAlign.Start) }
}
