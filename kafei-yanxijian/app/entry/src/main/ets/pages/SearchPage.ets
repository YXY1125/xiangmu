import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { EquipmentItem, KnowledgeItem, RecipeItem } from '../models/CoffeeModels'

@Entry
@Component
struct SearchPage {
  @State keyword: string = ''

  private searchKey(): string { return this.keyword.trim().toLowerCase() }

  private knowledgeResults(): KnowledgeItem[] {
    const key = this.searchKey()
    if (key.length === 0) return []
    return CoffeeCatalog.knowledge().filter((item: KnowledgeItem) => item.title.toLowerCase().includes(key) ||
      item.category.toLowerCase().includes(key) || item.summary.toLowerCase().includes(key))
  }

  private recipeResults(): RecipeItem[] {
    const key = this.searchKey()
    if (key.length === 0) return []
    return CoffeeCatalog.recipes().filter((item: RecipeItem) => item.name.toLowerCase().includes(key) ||
      item.method.toLowerCase().includes(key) || item.flavor.toLowerCase().includes(key))
  }

  private equipmentResults(): EquipmentItem[] {
    const key = this.searchKey()
    if (key.length === 0) return []
    return CoffeeCatalog.equipment().filter((item: EquipmentItem) => item.name.toLowerCase().includes(key) ||
      item.category.toLowerCase().includes(key) || item.principle.toLowerCase().includes(key))
  }

  private total(): number {
    return this.knowledgeResults().length + this.recipeResults().length + this.equipmentResults().length
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
        TextInput({ text: this.keyword, placeholder: '搜索知识、配方与器具' })
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Theme.colors().surfaceCard)
          .borderRadius(22)
          .margin({ left: 8 })
          .onChange((value: string) => { this.keyword = value })
        if (this.keyword.length > 0) {
          Text('清空').fontSize(12).fontColor(Theme.colors().brandPrimary).margin({ left: 8 }).onClick(() => { this.keyword = '' })
        }
      }.width('100%')

      if (this.keyword.trim().length === 0) {
        Text('输入产地、豆种、处理、冲煮方式、风味或器具关键词。')
          .fontSize(13).fontColor(Theme.colors().textSecondary).margin({ top: 40 })
      } else if (this.total() === 0) {
        Text('没有找到相关内容').fontSize(17).fontWeight(FontWeight.Bold).margin({ top: 40 })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Text(`找到 ${this.total()} 项结果`).fontSize(12).fontColor(Theme.colors().textSecondary).width('100%')
            ForEach(this.knowledgeResults(), (item: KnowledgeItem) => {
              this.ResultCard('知识 · ' + item.category, item.title, item.summary, () => {
                AppRouter.push(this.getUIContext(), { url: 'pages/KnowledgeDetailPage', params: { id: item.id } })
              })
            }, (item: KnowledgeItem) => item.id)
            ForEach(this.recipeResults(), (item: RecipeItem) => {
              this.ResultCard('配方 · ' + item.method, item.name, item.flavor, () => {
                AppRouter.push(this.getUIContext(), { url: 'pages/RecipeDetailPage', params: { id: item.id } })
              })
            }, (item: RecipeItem) => item.id)
            ForEach(this.equipmentResults(), (item: EquipmentItem) => {
              this.ResultCard('器具 · ' + item.category, item.name, item.principle, () => {
                AppRouter.push(this.getUIContext(), { url: 'pages/EquipmentDetailPage', params: { id: item.id } })
              })
            }, (item: EquipmentItem) => item.id)
          }.width('100%').margin({ bottom: 24 })
        }.layoutWeight(1).width('100%')
      }
    }.padding(16).width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder
  ResultCard(type: string, title: string, summary: string, action: () => void) {
    Column({ space: 4 }) {
      Text(type).fontSize(10).fontColor(Theme.colors().brandPrimary).width('100%')
      Text(title).fontSize(16).fontWeight(FontWeight.Bold).width('100%')
      Text(summary).fontSize(12).fontColor(Theme.colors().textSecondary).maxLines(2).width('100%')
    }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(17).onClick(action)
  }
}
