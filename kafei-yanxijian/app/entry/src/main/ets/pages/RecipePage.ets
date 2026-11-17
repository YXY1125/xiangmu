import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { CoffeeApi } from '../services/CoffeeApi'
import { CoffeeRecord, RecipeItem } from '../models/CoffeeModels'
import { RemoteCoffeeImage } from '../components/RemoteCoffeeImage'

@Component
export struct RecipePage {
  @StorageLink('coffeeDataRevision') @Watch('onRevision') revision: number = 0
  @StorageLink('accessToken') @Watch('onSessionChanged') accessToken: string = ''
  @State filter: string = '全部'
  @State mine: CoffeeRecord[] = []
  @State loading: boolean = false
  @State error: string = ''
  onRequireAuth: () => void = () => {}
  private recipes: RecipeItem[] = CoffeeCatalog.recipes()
  private requestSerial: number = 0

  aboutToAppear(): void { this.loadMine() }
  private onRevision(): void { this.loadMine() }
  private onSessionChanged(): void { this.loadMine() }
  private loadMine(): void {
    const serial = ++this.requestSerial
    if (this.accessToken.length === 0) { this.mine = []; this.loading = false; this.error = ''; return }
    this.loading = true
    CoffeeApi.listUserRecipes().then((result) => {
      if (serial !== this.requestSerial) return
      this.loading = false
      if (result.code === 0 && result.data !== undefined) {
        this.mine = (Array.isArray(result.data.items) ? result.data.items : []).filter((row: CoffeeRecord) => row.status === 'active')
        this.error = ''
      } else this.error = result.message
    })
  }
  private officialVisible(): RecipeItem[] {
    if (this.filter === '全部') return this.recipes
    return this.recipes.filter((recipe: RecipeItem) => recipe.method.includes(this.filter))
  }
  private openCreate(): void {
    if (this.accessToken.length === 0) { this.onRequireAuth(); return }
    AppRouter.push(this.getUIContext(), { url: 'pages/RecipeEditPage' })
  }
  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() { Text('配方').fontSize(30).fontWeight(FontWeight.Bold).layoutWeight(1); Text('＋').fontSize(28).fontColor(Theme.colors().brandPrimary).onClick(() => this.openCreate()) }
        Row({ space: 8 }) {
          ForEach(['全部', '手冲', '意式', '冷萃'], (name: string) => {
            Text(name).fontSize(12).fontColor(this.filter === name ? Color.White : Theme.colors().textSecondary)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor(this.filter === name ? Theme.colors().brandPrimary : Theme.colors().surfaceCard).borderRadius(16)
              .onClick(() => { this.filter = name })
          })
        }.width('100%')
        if (this.accessToken.length > 0) {
          Row() { Text('我的配方').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1); Text(`${this.mine.length} 个有效版本`).fontSize(11).fontColor(Theme.colors().textSecondary) }.width('100%')
          if (this.loading) { Text('正在同步个人配方…').fontSize(12).fontColor(Theme.colors().textSecondary).width('100%') }
          if (this.error.length > 0) { Text(this.error).fontSize(12).fontColor(Theme.colors().danger).width('100%').onClick(() => this.loadMine()) }
          ForEach(this.mine, (row: CoffeeRecord) => {
            Column({ space: 10 }) {
              if (row.payload.coverKey.length > 0) {
                RemoteCoffeeImage({ imageKey: row.payload.coverKey, label: row.payload.name || '配方封面', imageHeight: 135 })
              }
              Row() {
                Column({ space: 5 }) { Text(row.payload.name || '未命名配方').fontSize(17).fontWeight(FontWeight.Bold); Text(`${row.payload.method || '手冲'} · 1:${row.payload.ratio} · ${row.payload.temperature}℃ · v${row.version}`).fontSize(11).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('编辑').fontSize(12).fontColor(Theme.colors().brandPrimary)
              }
            }.padding(16).backgroundColor('#EAD9C5').borderRadius(18).onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/RecipeEditPage', params: { recordId: row.id } }))
          }, (row: CoffeeRecord) => row.id)
        } else {
          Text('登录后创建并实时同步个人配方。').fontSize(12).fontColor(Theme.colors().brandPrimary).onClick(() => this.onRequireAuth())
        }
        Text('官方配方').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
        ForEach(this.officialVisible(), (recipe: RecipeItem, index: number) => {
          Column({ space: 0 }) {
            if (recipe.method.includes('冷萃')) {
              Image($r('app.media.cover_recipe_cold_brew')).width('100%').height(146).objectFit(ImageFit.Cover)
            } else {
              Image($r('app.media.cover_recipe_latte')).width('100%').height(146).objectFit(ImageFit.Cover)
            }
            Column({ space: 10 }) {
            Row() { Text(recipe.method).fontSize(11).fontColor(index % 2 === 0 ? Theme.colors().brandAccent : Theme.colors().brandPrimary); Blank(); Text(`1:${recipe.ratio}`).fontSize(12).fontWeight(FontWeight.Bold) }
            Text(recipe.name).fontSize(22).fontWeight(FontWeight.Bold).width('100%')
            Text(`${recipe.temperature}℃ · ${recipe.flavor}`).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
            Text('查看配方').fontSize(12).fontColor(Theme.colors().brandPrimary).width('100%')
            }.padding(20).alignItems(HorizontalAlign.Start)
          }.backgroundColor(index % 2 === 0 ? '#EAD9C5' : Theme.colors().surfaceCard).borderRadius(22).clip(true)
            .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/RecipeDetailPage', params: { id: recipe.id } }))
        }, (recipe: RecipeItem) => recipe.id)
        Text('配方编辑创建新版本；归档不会物理删除历史。').fontSize(11).lineHeight(18).fontColor(Theme.colors().textTertiary).margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
