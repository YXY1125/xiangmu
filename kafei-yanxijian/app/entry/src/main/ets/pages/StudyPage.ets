import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { EquipmentItem, KnowledgeItem } from '../models/CoffeeModels'

@Component
export struct StudyPage {
  @State keyword: string = ''
  @State category: string = '全部'
  onRequireAuth: () => void = () => {}
  private items: KnowledgeItem[] = CoffeeCatalog.knowledge()
  private equipment: EquipmentItem[] = CoffeeCatalog.equipment()

  private visibleKnowledge(): KnowledgeItem[] {
    const key = this.keyword.trim().toLowerCase()
    return this.items.filter((item: KnowledgeItem) => {
      const categoryMatch = this.category === '全部' || item.category.includes(this.category)
      const keywordMatch = key.length === 0 || item.title.toLowerCase().includes(key) ||
        item.category.toLowerCase().includes(key) || item.summary.toLowerCase().includes(key)
      return categoryMatch && keywordMatch
    })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Text('研习').fontSize(30).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
        Stack() {
          Image($r('app.media.cover_coffee_beans')).width('100%').height(188).objectFit(ImageFit.Cover)
          Column().width('100%').height(188)
            .linearGradient({ angle: 180, colors: [['#00241B17', 0.2], ['#CC241B17', 1]] })
          Column({ space: 4 }) {
            Text('BEAN ATLAS').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#F3EBDD')
            Text('认识果实、生豆与烘焙').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('从外观、处理到杯中风味').fontSize(12).fontColor('#EFE1CE')
          }.width('100%').height(188).padding(18).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Start)
        }.width('100%').height(188).clip(true).borderRadius(24)
        TextInput({ text: this.keyword, placeholder: '搜索豆种、产地、烘焙、冲煮与风味' })
          .height(46).backgroundColor(Theme.colors().surfaceCard).borderRadius(23)
          .onChange((value: string) => { this.keyword = value })
        Row({ space: 8 }) {
          ForEach(['全部', '豆种', '产地', '烘焙', '处理', '冲煮', '风味'], (name: string) => {
            Text(name).fontSize(12).padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .backgroundColor(this.category === name ? Theme.colors().brandPrimary : Theme.colors().brandPrimaryContainer)
              .borderRadius(16).fontColor(this.category === name ? Color.White : Theme.colors().textPrimary)
              .onClick(() => { this.category = name })
          })
        }.width('100%')
        Text('推荐知识').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
        if (this.visibleKnowledge().length === 0) {
          Text('没有符合当前关键词与分类的知识内容。').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%').padding(16)
        }
        ForEach(this.visibleKnowledge(), (item: KnowledgeItem) => {
          Column({ space: 7 }) {
            Row() { Text(item.category).fontSize(11).fontColor(Theme.colors().brandAccent); Blank(); Text(`${item.readingMinutes} 分钟`).fontSize(11).fontColor(Theme.colors().textTertiary) }
            Text(item.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
            Text(item.summary).fontSize(13).lineHeight(20).fontColor(Theme.colors().textSecondary).maxLines(2).width('100%')
          }.width('100%').padding(17).backgroundColor(Theme.colors().surfaceCard).borderRadius(18).alignItems(HorizontalAlign.Start)
            .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/KnowledgeDetailPage', params: { id: item.id } }))
        }, (item: KnowledgeItem) => item.id)
        Text('器具百科').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%').margin({ top: 6 })
        Image($r('app.media.cover_equipment_manual')).width('100%').height(150).objectFit(ImageFit.Cover).borderRadius(20)
        ForEach(this.equipment, (item: EquipmentItem) => {
          Row() {
            Column({ space: 4 }) { Text(item.category).fontSize(10).fontColor(Theme.colors().brandAccent); Text(item.name).fontSize(16).fontWeight(FontWeight.Bold); Text(item.principle).fontSize(12).fontColor(Theme.colors().textSecondary).maxLines(2) }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(24).fontColor(Theme.colors().brandPrimary)
          }.padding(16).backgroundColor('#EAD9C5').borderRadius(18)
            .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/EquipmentDetailPage', params: { id: item.id } }))
        }, (item: EquipmentItem) => item.id)
      }.padding(16).width('100%').margin({ bottom: 20 })
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
