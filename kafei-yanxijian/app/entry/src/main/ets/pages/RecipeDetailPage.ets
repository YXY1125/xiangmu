import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { RecipeItem } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'
import { AuthService } from '../services/AuthService'
import { FavoriteAction } from '../components/design-system/FavoriteAction'

@Entry
@Component
struct RecipeDetailPage {
  @State recipe: RecipeItem = CoffeeCatalog.recipes()[0]
  @State message: string = ''
  @State favoriteSaving: boolean = false
  @State favorited: boolean = false
  @State favoriteFeedback: string = ''

  aboutToAppear(): void {
    const params = AppRouter.getParams(this.getUIContext()) as Record<string, string>
    const id = params ? params['id'] : ''
    const match = CoffeeCatalog.recipes().find((value: RecipeItem) => value.id === id)
    if (match) {
      this.recipe = match
    }
    this.loadFavoriteState()
  }

  private async favorite(): Promise<void> {
    if (!AuthService.isLoggedIn()) {
      this.favoriteFeedback = '请先登录'
      this.message = '请先登录后收藏配方'
      return
    }
    if (this.favoriteSaving || this.favorited) return
    this.favoriteSaving = true
    this.favoriteFeedback = ''
    const result = await CoffeeApi.saveFavorite('recipe', this.recipe.id)
    this.favoriteSaving = false
    this.favorited = result.code === 0
    this.favoriteFeedback = result.code === 0 ? '' : '收藏失败'
    this.message = result.code === 0 ? '配方已收藏；已同步到“我的收藏”' : result.message
  }

  private async loadFavoriteState(): Promise<void> {
    if (!AuthService.isLoggedIn()) return
    this.favoriteSaving = true
    const result = await CoffeeApi.hasFavorite('recipe', this.recipe.id)
    this.favoriteSaving = false
    if (result.code === 0) {
      this.favorited = result.data === true
      this.favoriteFeedback = ''
    } else {
      this.favoriteFeedback = '状态读取失败'
    }
  }

  private copy(): void {
    if (!AuthService.isLoggedIn()) {
      this.message = '请先登录后复制配方'
      return
    }
    AppRouter.push(this.getUIContext(), {
      url: 'pages/RecipeEditPage',
      params: {
        name: `${this.recipe.name}（副本）`,
        ratio: this.recipe.ratio,
        temperature: this.recipe.temperature,
        method: this.recipe.method,
        flavor: this.recipe.flavor,
        steps: this.recipe.steps.join('\n')
      }
    })
  }

  private startBrew(): void {
    AppRouter.push(this.getUIContext(), {
      url: 'pages/BrewCalculatorPage',
      params: { ratio: this.recipe.ratio, temperature: this.recipe.temperature, method: this.recipe.method }
    })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
          Blank()
          FavoriteAction({
            selected: this.favorited,
            saving: this.favoriteSaving,
            feedback: this.favoriteFeedback,
            onAction: () => this.favorite()
          })
        }.width('100%')

        Column({ space: 8 }) {
          Text(this.recipe.method.toUpperCase()).fontSize(11).fontColor('#D8C7B2')
          Text(this.recipe.name).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#F3EBDD')
          Text(this.recipe.flavor).fontSize(14).fontColor('#D8C7B2')
        }
        .padding(24)
        .backgroundColor('#241B17')
        .borderRadius(26)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 8 }) {
          this.Metric('粉水比', `1:${this.recipe.ratio}`)
          this.Metric('水温', `${this.recipe.temperature}℃`)
          this.Metric('时间', this.durationLabel())
        }.width('100%')

        Text('制作步骤').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
        ForEach(this.recipe.steps, (step: string, index: number) => {
          Row() {
            Text(`${index + 1}`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.colors().brandPrimary)
              .width(28)
            Text(step).fontSize(14).layoutWeight(1)
          }
          .padding(15)
          .backgroundColor(Theme.colors().surfaceCard)
          .borderRadius(16)
        })

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(13)
            .fontColor(this.message.includes('已') ? Theme.colors().success : Theme.colors().danger)
            .width('100%')
        }

        Row({ space: 8 }) {
          Button('复制并调整')
            .layoutWeight(1)
            .fontColor(Theme.colors().brandPrimary)
            .backgroundColor(Theme.colors().surfaceCard)
            .borderRadius(18)
            .onClick(() => this.copy())
          Button('开始制作')
            .layoutWeight(1)
            .backgroundColor(Theme.colors().brandPrimary)
            .borderRadius(18)
            .onClick(() => this.startBrew())
        }.width('100%').margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder
  Metric(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold)
      Text(label).fontSize(10).fontColor(Theme.colors().textSecondary)
    }
    .layoutWeight(1)
    .padding(15)
    .backgroundColor('#EAD9C5')
    .borderRadius(17)
  }

  private durationLabel(): string {
    if (this.recipe.durationSeconds >= 3600) {
      return `${Math.round(this.recipe.durationSeconds / 3600)} 小时`
    }
    const minutes = Math.floor(this.recipe.durationSeconds / 60)
    const seconds = this.recipe.durationSeconds % 60
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`
  }
}
