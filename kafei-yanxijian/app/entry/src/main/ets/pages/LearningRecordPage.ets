import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeRecord, KnowledgeItem } from '../models/CoffeeModels'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { CoffeeApi } from '../services/CoffeeApi'

@Entry
@Component
struct LearningRecordPage {
  @StorageLink('coffeeDataRevision') @Watch('onRevision') revision: number = 0
  @State rows: CoffeeRecord[] = []
  @State loading: boolean = false
  @State error: string = ''
  private requestSerial: number = 0

  aboutToAppear(): void { this.load() }
  private onRevision(): void { this.load() }
  private load(): void {
    const serial = ++this.requestSerial
    this.loading = true
    CoffeeApi.listLearning().then((result) => {
      if (serial !== this.requestSerial) return
      this.loading = false
      if (result.code === 0 && result.data !== undefined) {
        this.rows = Array.isArray(result.data.items) ? result.data.items : []
        this.error = ''
      } else this.error = result.message
    })
  }
  private title(id: string): string {
    const item = CoffeeCatalog.knowledge().find((row: KnowledgeItem) => row.id === id)
    return item ? item.title : '咖啡研习记录'
  }
  build() {
    Column({ space: 16 }) {
      Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Text('学习记录').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1); Text('刷新').fontSize(12).fontColor(Theme.colors().brandPrimary).onClick(() => this.load()) }.width('100%')
      if (this.loading) {
        Text('正在同步学习进度…').fontSize(13).fontColor(Theme.colors().textSecondary)
      } else if (this.error.length > 0) {
        Text(this.error).fontSize(13).fontColor(Theme.colors().danger).onClick(() => this.load())
      } else if (this.rows.length === 0) {
        Column({ space: 8 }) { Text('还没有学习记录').fontSize(19).fontWeight(FontWeight.Bold); Text('在知识详情标记完成后，进度会实时同步。').fontSize(13).fontColor(Theme.colors().textSecondary) }.padding(28).backgroundColor(Theme.colors().surfaceCard).borderRadius(22)
      } else {
        List({ space: 10 }) {
          ForEach(this.rows, (row: CoffeeRecord) => {
            ListItem() { Row() { Column({ space: 5 }) { Text(this.title(row.payload.knowledgeId)).fontSize(16).fontWeight(FontWeight.Bold); Text(`完成于 ${row.createdAt.slice(0, 10)}`).fontSize(11).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('已学习').fontSize(11).fontColor(Theme.colors().success) }.padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(17) }
          }, (row: CoffeeRecord) => row.id)
        }.layoutWeight(1).width('100%')
      }
    }.padding(16).width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
