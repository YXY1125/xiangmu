import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeRecord, EquipmentItem, KnowledgeItem, RecipeItem } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'
import { CoffeeCatalog } from '../services/CoffeeCatalog'

@Entry
@Component
struct FavoritePage {
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
    this.error = ''
    CoffeeApi.listFavorites().then((result) => {
      if (serial !== this.requestSerial) return
      this.loading = false
      if (result.code === 0 && result.data !== undefined) {
        this.rows = (Array.isArray(result.data.items) ? result.data.items : [])
          .filter((row: CoffeeRecord) => row.status === 'active')
      } else {
        this.error = result.message
      }
    })
  }

  private title(row: CoffeeRecord): string {
    if (row.payload.targetType === 'knowledge') {
      const item = CoffeeCatalog.knowledge().find((value: KnowledgeItem) => value.id === row.payload.targetId)
      return item ? item.title : '知识内容'
    }
    if (row.payload.targetType === 'recipe') {
      const item = CoffeeCatalog.recipes().find((value: RecipeItem) => value.id === row.payload.targetId)
      return item ? item.name : '咖啡配方'
    }
    if (row.payload.targetType === 'equipment') {
      const item = CoffeeCatalog.equipment().find((value: EquipmentItem) => value.id === row.payload.targetId)
      return item ? item.name : '咖啡器具'
    }
    return '收藏内容'
  }

  private typeName(type: string): string {
    if (type === 'knowledge') return '知识'
    if (type === 'recipe') return '配方'
    if (type === 'equipment') return '器具'
    return '内容'
  }

  private open(row: CoffeeRecord): void {
    if (row.payload.targetType === 'knowledge') {
      AppRouter.push(this.getUIContext(), { url: 'pages/KnowledgeDetailPage', params: { id: row.payload.targetId } })
    } else if (row.payload.targetType === 'recipe') {
      AppRouter.push(this.getUIContext(), { url: 'pages/RecipeDetailPage', params: { id: row.payload.targetId } })
    } else if (row.payload.targetType === 'equipment') {
      AppRouter.push(this.getUIContext(), { url: 'pages/EquipmentDetailPage', params: { id: row.payload.targetId } })
    }
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
        Text('我的收藏').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1)
        Text('刷新').fontSize(12).fontColor(Theme.colors().brandPrimary).onClick(() => this.load())
      }.width('100%')

      if (this.loading) {
        Text('正在同步收藏…').fontSize(13).fontColor(Theme.colors().textSecondary)
      } else if (this.error.length > 0) {
        Text(this.error).fontSize(13).fontColor(Theme.colors().danger).onClick(() => this.load())
      } else if (this.rows.length === 0) {
        Column({ space: 8 }) {
          Text('还没有收藏').fontSize(20).fontWeight(FontWeight.Bold)
          Text('知识、配方和器具详情页的收藏会实时汇总到这里。').fontSize(13).fontColor(Theme.colors().textSecondary).textAlign(TextAlign.Center)
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.rows, (row: CoffeeRecord) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(this.typeName(row.payload.targetType)).fontSize(10).fontColor(Theme.colors().brandAccent)
                  Text(this.title(row)).fontSize(16).fontWeight(FontWeight.Bold)
                  Text(row.createdAt.slice(0, 10)).fontSize(10).fontColor(Theme.colors().textTertiary)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('›').fontSize(24).fontColor(Theme.colors().brandPrimary)
              }.padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(17).onClick(() => this.open(row))
            }
          }, (row: CoffeeRecord) => row.id)
        }.layoutWeight(1).width('100%')
      }
    }.padding(16).width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
