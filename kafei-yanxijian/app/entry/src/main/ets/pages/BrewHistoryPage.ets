import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeRecord } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'
import { RemoteCoffeeImage } from '../components/RemoteCoffeeImage'

@Entry
@Component
struct BrewHistoryPage {
  @StorageLink('coffeeDataRevision') @Watch('onRevision') revision: number = 0
  @State rows: CoffeeRecord[] = []
  @State loading: boolean = false
  @State error: string = ''
  @State filter: string = '全部'
  private requestSerial: number = 0

  aboutToAppear(): void { this.load() }
  private onRevision(): void { this.load() }

  private load(): void {
    const serial = ++this.requestSerial
    this.loading = true
    this.error = ''
    CoffeeApi.listBrews().then((result) => {
      if (serial !== this.requestSerial) return
      this.loading = false
      if (result.code === 0 && result.data !== undefined) {
        this.rows = Array.isArray(result.data.items) ? result.data.items : []
      } else {
        this.error = result.message
      }
    })
  }

  private visibleRows(): CoffeeRecord[] {
    if (this.filter === '全部') return this.rows
    return this.rows.filter((row: CoffeeRecord) => row.payload.method === this.filter)
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
        Text('制作历史').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1)
        Text('刷新').fontSize(12).fontColor(Theme.colors().brandPrimary).onClick(() => this.load())
      }.width('100%')
      Row({ space: 8 }) {
        ForEach(['全部', '手冲', '意式', '冷萃'], (name: string) => {
          Text(name).fontSize(12).fontColor(this.filter === name ? Color.White : Theme.colors().textSecondary)
            .padding({ left: 13, right: 13, top: 8, bottom: 8 })
            .backgroundColor(this.filter === name ? Theme.colors().brandPrimary : Theme.colors().surfaceCard)
            .borderRadius(15).onClick(() => { this.filter = name })
        })
      }.width('100%')
      if (this.loading) {
        Text('正在同步制作记录…').fontSize(13).fontColor(Theme.colors().textSecondary).margin({ top: 30 })
      } else if (this.error.length > 0) {
        Column({ space: 10 }) {
          Text(this.error).fontSize(13).fontColor(Theme.colors().danger)
          Button('重试').onClick(() => this.load())
        }.padding(24).backgroundColor(Theme.colors().surfaceCard).borderRadius(20)
      } else if (this.visibleRows().length === 0) {
        Column({ space: 10 }) {
          Text('还没有制作记录').fontSize(19).fontWeight(FontWeight.Bold)
          Text('完成一次真实冲煮并保存后，会立即同步到这里和成长统计。').fontSize(13).lineHeight(20).fontColor(Theme.colors().textSecondary).textAlign(TextAlign.Center)
          Button('新建制作记录').backgroundColor(Theme.colors().brandPrimary).borderRadius(20)
            .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/BrewRecordEditPage' }))
        }.padding(28).backgroundColor(Theme.colors().surfaceCard).borderRadius(22)
      } else {
        List({ space: 10 }) {
          ForEach(this.visibleRows(), (row: CoffeeRecord) => {
            ListItem() {
              Column({ space: 7 }) {
                if (row.payload.imageKey.length > 0) {
                  RemoteCoffeeImage({ imageKey: row.payload.imageKey, label: row.payload.coffeeName || '制作记录图片', imageHeight: 150 })
                }
                Row() {
                  Text(row.payload.coffeeName || '未命名咖啡').fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
                  Text(row.status === 'archived' ? '已归档' : `v${row.version}`).fontSize(11).fontColor(Theme.colors().brandPrimary)
                }
                Text(`${row.payload.method || '手冲'} · ${row.payload.dose}g / ${row.payload.water}ml · ${row.payload.temperature}℃`)
                  .fontSize(12).fontColor(Theme.colors().textSecondary).width('100%')
                Text(row.payload.note || '未填写制作感受').fontSize(12).fontColor(Theme.colors().textTertiary).maxLines(2).width('100%')
                Text(row.createdAt.slice(0, 10)).fontSize(10).fontColor(Theme.colors().textTertiary).width('100%')
              }.padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(18).alignItems(HorizontalAlign.Start)
            }
          }, (row: CoffeeRecord) => row.id)
        }.layoutWeight(1).width('100%')
      }
    }.padding(16).width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
