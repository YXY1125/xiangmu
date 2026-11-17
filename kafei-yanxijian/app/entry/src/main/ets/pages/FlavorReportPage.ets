import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { AppBarChart, BarChartItem } from '../components/design-system/AppChart'
import { CoffeeRecord, EvaluationStats, TagCount } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'

@Entry
@Component
struct FlavorReportPage {
  @StorageLink('coffeeDataRevision') @Watch('onRevision') revision: number = 0
  @State average: number = 0
  @State tags: string = ''
  @State count: number = 0
  @State history: CoffeeRecord[] = []
  @State stats: EvaluationStats = new EvaluationStats()
  @State error: string = ''
  private requestSerial: number = 0
  aboutToAppear(): void { this.load() }
  private onRevision(): void { this.load() }
  private load(): void {
    const serial = ++this.requestSerial
    const params = AppRouter.getParams(this.getUIContext()) as Record<string, Object>
    if (params) { this.average = Number(params['average'] ?? this.average); this.tags = `${params['tags'] ?? this.tags}` }
    CoffeeApi.evaluationStats().then((result) => {
      if (serial !== this.requestSerial) return
      if (result.code === 0 && result.data !== undefined) {
        const stats: EvaluationStats = result.data
        this.stats = stats
        this.count = stats.count
        if (stats.count > 0) this.average = stats.averages.overall
        this.tags = Array.isArray(stats.tags) ? stats.tags.slice(0, 6).map((tag: TagCount) => `${tag.name}×${tag.count}`).join('、') : this.tags
      } else this.error = result.message
    })
    CoffeeApi.listEvaluations().then((result) => {
      if (serial !== this.requestSerial) return
      if (result.code === 0 && result.data !== undefined) this.history = Array.isArray(result.data.items) ? result.data.items : []
    })
  }
  private scoreItems(): BarChartItem[] {
    if (this.stats.count === 0) return []
    const labels: string[] = ['酸', '甜', '苦', '醇厚', '香气', '余韵', '整体']
    const values: number[] = [this.stats.averages.acidity, this.stats.averages.sweetness, this.stats.averages.bitterness, this.stats.averages.body, this.stats.averages.aroma, this.stats.averages.aftertaste, this.stats.averages.overall]
    const items: BarChartItem[] = []
    for (let i = 0; i < labels.length; i++) {
      const item = new BarChartItem()
      item.label = labels[i]
      item.value = values[i]
      items.push(item)
    }
    return items
  }
  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Text('测评报告').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1); Text('刷新').fontSize(12).fontColor(Theme.colors().brandPrimary).onClick(() => this.load()) }.width('100%')
        if (this.error.length > 0) { Text(this.error).fontSize(12).fontColor(Theme.colors().danger).width('100%') }
        Column({ space: 6 }) { Text('整体满意度均值').fontSize(12).fontColor('#D8C7B2'); Text(this.average > 0 ? this.average.toFixed(1) : '—').fontSize(52).fontWeight(FontWeight.Bold).fontColor('#F3EBDD'); Text(`${this.count} 次真实测评 · 满分 5`).fontSize(11).fontColor('#D8C7B2') }.padding(24).backgroundColor('#241B17').borderRadius(26).width('100%')
        Text('七维概览').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
        AppBarChart({ title: '七维评分均值（1–5）', items: this.scoreItems() })
        Column({ space: 8 }) { Text('风味标签分布').fontSize(18).fontWeight(FontWeight.Bold).width('100%'); Text(this.tags.length > 0 ? this.tags : '暂无真实测评数据').fontSize(14).lineHeight(22).fontColor(Theme.colors().textSecondary).width('100%') }.padding(18).backgroundColor('#EAD9C5').borderRadius(19)
        Text('最近测评').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
        if (this.history.length === 0) { Text('完成一次测评后显示历史。').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%') }
        ForEach(this.history.slice(-5).reverse(), (row: CoffeeRecord) => { Row() { Column({ space: 4 }) { Text(row.payload.bean || '未命名咖啡豆').fontSize(15).fontWeight(FontWeight.Bold); Text(`${row.payload.method} · ${row.createdAt.slice(0, 10)}`).fontSize(11).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(`${row.payload.scores.overall}/5`).fontSize(15).fontColor(Theme.colors().brandPrimary) }.padding(15).backgroundColor(Theme.colors().surfaceCard).borderRadius(16) }, (row: CoffeeRecord) => row.id)
        Button('再测一杯').width('100%').backgroundColor(Theme.colors().brandPrimary).borderRadius(20).onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/FlavorEvaluationPage' })).margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
