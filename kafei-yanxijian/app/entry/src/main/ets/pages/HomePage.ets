import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { KnowledgeItem, RecipeItem, UserSummary } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'
import { AppIcon, AppIconName } from '../components/design-system/AppIcon'
import { CoffeeMetricCard } from '../components/design-system/CoffeeMetricCard'

@Component
export struct HomePage {
  @Prop appName: string = '咖啡研习间'
  @Prop tagline: string = '在知识与萃取之间，建立自己的咖啡档案'
  @Prop @Watch('onRefreshToken') refreshToken: number = 0
  @StorageLink('accessToken') @Watch('onSessionChanged') accessToken: string = ''
  onRequireAuth: () => void = () => {}
  private knowledge: KnowledgeItem[] = CoffeeCatalog.knowledge()
  private recipes: RecipeItem[] = CoffeeCatalog.recipes()
  @State summary: UserSummary = new UserSummary()
  @State hasSummary: boolean = false
  @State summaryLoading: boolean = false
  @State summaryError: string = ''
  @State checkingIn: boolean = false
  @State checkInMessage: string = ''
  private requestSerial: number = 0

  aboutToAppear(): void {
    this.loadSummary()
  }

  private onRefreshToken(): void { this.loadSummary() }
  private onSessionChanged(): void { this.loadSummary() }

  private loadSummary(): void {
    const serial = ++this.requestSerial
    if (this.accessToken.length === 0) {
      this.summary = new UserSummary()
      this.hasSummary = false
      this.summaryLoading = false
      this.summaryError = ''
      return
    }
    this.summaryLoading = true
    this.summaryError = ''
    CoffeeApi.growth().then((result) => {
      if (serial !== this.requestSerial) return
      this.summaryLoading = false
      if (result.code === 0 && result.data !== undefined) {
        this.summary = result.data
        this.hasSummary = true
      } else {
        this.summaryError = result.message.length > 0 ? result.message : '成长数据同步失败'
      }
    })
  }

  private async checkIn(): Promise<void> {
    if (this.accessToken.length === 0) {
      this.onRequireAuth()
      return
    }
    if (this.checkingIn) return
    this.checkingIn = true
    const result = await CoffeeApi.checkIn()
    this.checkingIn = false
    this.checkInMessage = result.code === 0 ? '今日打卡已同步；重复操作不会重复累计' : result.message
    if (result.code === 0) this.loadSummary()
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Row() {
          Image($r('app.media.app_icon')).width(44).height(44).borderRadius(12)
          Column({ space: 1 }) {
            Text('COFFEE LAB').fontSize(12).fontWeight(FontWeight.Bold).fontColor(Theme.colors().brandPrimary)
            Text(this.appName).fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
          Row() {
            AppIcon({ name: 'search', iconSize: 24, color: Theme.colors().textPrimary })
          }.width(44).height(44).justifyContent(FlexAlign.Center)
            .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/SearchPage' }))
        }.width('100%')

        Stack() {
          Image($r('app.media.hero_coffee_lab')).width('100%').height(300).objectFit(ImageFit.Cover)
          Column().width('100%').height(300)
            .linearGradient({ angle: 90, colors: [['#E6241B17', 0.05], ['#B3241B17', 0.55], ['#33241B17', 1]] })
          Column({ space: 12 }) {
            Text('BREW · TASTE · LEARN').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#F3EBDD')
            Text('把每一杯，\n变成可复盘的实验').fontSize(30).fontWeight(FontWeight.Bold).fontColor('#F3EBDD').width('100%')
            Text(this.tagline).fontSize(14).lineHeight(21).fontColor('#EFE1CE').width('100%')
            Button('开始一次冲煮实验').height(44).fontColor('#241B17').backgroundColor('#F3EBDD').borderRadius(22)
              .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/BrewCalculatorPage' }))
          }.width('100%').height(300).padding(24).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Start)
        }
        .width('100%').height(300).clip(true).borderRadius(28)

        Column({ space: 10 }) {
          Text('今天的咖啡档案').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
          if (this.accessToken.length === 0) {
            Row() {
              Text('登录后查看学习、制作、配方与测评数据').fontSize(13).fontColor(Theme.colors().textSecondary).layoutWeight(1)
              Text('去登录').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.colors().brandPrimary)
                .onClick(() => this.onRequireAuth())
            }.width('100%').padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
          } else {
            if (!this.hasSummary && this.summaryLoading) {
              Row({ space: 10 }) {
                LoadingProgress().width(20).height(20).color(Theme.colors().brandPrimary)
                Text('正在同步最新咖啡档案…').fontSize(13).fontColor(Theme.colors().textSecondary)
              }.width('100%').padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
            } else if (!this.hasSummary && this.summaryError.length > 0) {
              Row() {
                Text(this.summaryError).fontSize(12).fontColor(Theme.colors().danger).layoutWeight(1)
                Text('重试').fontSize(12).fontWeight(FontWeight.Bold).fontColor(Theme.colors().brandPrimary)
                  .onClick(() => this.loadSummary())
              }.width('100%').padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
            } else {
              Row({ space: 8 }) {
                CoffeeMetricCard({ label: '已学习', value: this.summary.learningCount }).layoutWeight(1)
                CoffeeMetricCard({ label: '制作', value: this.summary.brewCount }).layoutWeight(1)
                CoffeeMetricCard({ label: '配方', value: this.summary.recipeCount }).layoutWeight(1)
                CoffeeMetricCard({ label: '测评', value: this.summary.evaluationCount }).layoutWeight(1)
              }.width('100%')
              if (this.summaryError.length > 0) {
                Row() {
                  Text(`暂未同步：${this.summaryError}`).fontSize(11).fontColor(Theme.colors().danger).layoutWeight(1)
                  Text('重试').fontSize(11).fontColor(Theme.colors().brandPrimary).onClick(() => this.loadSummary())
                }.width('100%').padding({ left: 12, right: 12 })
              }
              Row() {
                Column({ space: 2 }) {
                  Text(`累计打卡 ${this.summary.checkInCount} 天`).fontSize(14).fontWeight(FontWeight.Medium)
                  Text(this.checkInMessage.length > 0 ? this.checkInMessage : '每天首次打卡计入成长经验').fontSize(10).fontColor(Theme.colors().textSecondary)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Button(this.checkingIn ? '同步中…' : '今日打卡')
                  .enabled(!this.checkingIn)
                  .fontSize(12)
                  .height(38)
                  .backgroundColor(Theme.colors().brandPrimary)
                  .borderRadius(19)
                  .onClick(() => this.checkIn())
              }.width('100%').padding(14).backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
            }
          }
        }.width('100%')

        Column({ space: 12 }) {
          Text('快捷实验').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
          Row({ space: 10 }) {
            this.Action('biz', '咖啡知识', 'pages/SearchPage')
            this.Action('chart', '粉水计算', 'pages/BrewCalculatorPage')
            this.Action('ai', '风味测评', 'pages/FlavorEvaluationPage')
            this.Action('message', '器具百科', 'pages/EquipmentDetailPage')
          }.width('100%')
        }.width('100%')

        Column({ space: 12 }) {
          Text('每日研习').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
          ForEach(this.knowledge.slice(0, 3), (item: KnowledgeItem) => {
            Row() {
              Column({ space: 5 }) {
                Text(item.category).fontSize(11).fontColor(Theme.colors().brandAccent)
                Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.colors().textPrimary).maxLines(2)
                Text(`${item.readingMinutes} 分钟`).fontSize(11).fontColor(Theme.colors().textTertiary)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              AppIcon({ name: 'chevron', iconSize: 20, color: Theme.colors().brandPrimary })
            }.width('100%').padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
              .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/KnowledgeDetailPage', params: { id: item.id } }))
          }, (item: KnowledgeItem) => item.id)
        }.width('100%')

        Stack() {
          Image($r('app.media.banner_origin_ethiopia')).width('100%').height(176).objectFit(ImageFit.Cover)
          Column().width('100%').height(176)
            .linearGradient({ angle: 90, colors: [['#CC241B17', 0], ['#33241B17', 1]] })
          Column({ space: 5 }) {
            Text('ORIGIN NOTES').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#F3EBDD')
            Text('从果实到产地').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('今日专题 · 埃塞俄比亚高地').fontSize(12).fontColor('#EFE1CE')
          }.width('100%').height(176).padding(18).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Start)
        }.width('100%').height(176).clip(true).borderRadius(22)
          .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/SearchPage' }))

        Column({ space: 12 }) {
          Text('值得复刻的配方').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
          ForEach(this.recipes.slice(0, 2), (recipe: RecipeItem, index: number) => {
            Column({ space: 0 }) {
              if (index === 0) {
                Image($r('app.media.cover_recipe_latte')).width('100%').height(128).objectFit(ImageFit.Cover)
              } else {
                Image($r('app.media.cover_recipe_cold_brew')).width('100%').height(128).objectFit(ImageFit.Cover)
              }
              Row() {
              Column({ space: 5 }) {
                Text(recipe.method).fontSize(11).fontColor(Theme.colors().brandAccent)
                Text(recipe.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
                Text(`1:${recipe.ratio} · ${recipe.temperature}℃ · ${recipe.flavor}`).fontSize(12).fontColor(Theme.colors().textSecondary)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text('查看').fontSize(12).fontColor(Theme.colors().brandPrimary)
              }.width('100%').padding(18)
            }.width('100%').backgroundColor('#EAD9C5').borderRadius(20).clip(true)
              .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/RecipeDetailPage', params: { id: recipe.id } }))
          }, (recipe: RecipeItem) => recipe.id)
        }.width('100%').margin({ bottom: 20 })

        Stack() {
          Image($r('app.media.cover_equipment_manual')).width('100%').height(170).objectFit(ImageFit.Cover)
          Column().width('100%').height(170)
            .linearGradient({ angle: 180, colors: [['#00241B17', 0.2], ['#D9241B17', 1]] })
          Column({ space: 5 }) {
            Text('器具研习').fontSize(21).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('工作原理 · 使用方法 · 清洁维护').fontSize(12).fontColor('#EFE1CE')
          }.width('100%').height(170).padding(18).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Start)
        }.width('100%').height(170).clip(true).borderRadius(22).margin({ bottom: 24 })
          .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/EquipmentDetailPage' }))
      }
      .width('100%').padding({ left: 16, right: 16, top: 18 })
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder Action(icon: AppIconName, label: string, url: string) {
    Column({ space: 6 }) {
      AppIcon({ name: icon, iconSize: 22, color: Theme.colors().brandPrimary })
      Text(label).fontSize(11).fontColor(Theme.colors().textPrimary)
    }.layoutWeight(1).height(82).justifyContent(FlexAlign.Center).backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
      .onClick(() => AppRouter.push(this.getUIContext(), { url: url }))
  }
}
