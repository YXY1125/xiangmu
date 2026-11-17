import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { AppBarChart, BarChartItem } from '../components/design-system/AppChart'
import { ActivityStats, UserSummary } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'
import { CoffeeMetricCard } from '../components/design-system/CoffeeMetricCard'

@Component
struct GrowthAchievementRow {
  @Prop name: string = ''
  @Prop achieved: boolean = false

  build() {
    Row() {
      Text(this.achieved ? '●' : '○').fontSize(18)
        .fontColor(this.achieved ? Theme.colors().brandAccent : Theme.colors().textTertiary)
      Text(this.name).fontSize(15).layoutWeight(1).margin({ left: 10 })
      Text(this.achieved ? '已达成' : '未达成').fontSize(11)
        .fontColor(this.achieved ? Theme.colors().brandPrimary : Theme.colors().textTertiary)
    }.padding(15).backgroundColor(Theme.colors().surfaceCard).borderRadius(16)
  }
}

@Entry
@Component
struct GrowthPage {
  @StorageLink('coffeeDataRevision') @Watch('onRevision') revision: number = 0
  @State summary: UserSummary = new UserSummary()
  @State activity: ActivityStats = new ActivityStats()
  @State loadError: string = ''
  @State summaryLoading: boolean = false
  @State hasSummary: boolean = false
  private requestSerial: number = 0

  aboutToAppear(): void {
    this.load()
  }
  private onRevision(): void { this.load() }

  private load(): void {
    const serial = ++this.requestSerial
    this.loadError = ''
    this.summaryLoading = true
    CoffeeApi.growth().then((result) => {
      if (serial !== this.requestSerial) return
      this.summaryLoading = false
      if (result.code === 0 && result.data !== undefined) {
        this.summary = result.data
        this.hasSummary = true
      } else {
        this.loadError = result.message
      }
    })
    CoffeeApi.activityStats().then((result) => {
      if (serial !== this.requestSerial) return
      if (result.code === 0 && result.data !== undefined) {
        this.activity = result.data
      } else if (this.loadError.length === 0) {
        this.loadError = result.message
      }
    })
  }

  private activityItems(): BarChartItem[] {
    const items: BarChartItem[] = []
    for (let day of this.activity.days) {
      const item = new BarChartItem()
      item.label = day.label
      item.value = day.brewCount + day.learningCount + day.evaluationCount
      items.push(item)
    }
    return items
  }

  private methodItems(): BarChartItem[] {
    const items: BarChartItem[] = []
    for (let method of this.activity.methods) {
      const item = new BarChartItem()
      item.label = method.name
      item.value = method.count
      items.push(item)
      if (items.length >= 6) break
    }
    return items
  }

  private levelName(): string {
    if (this.summary.experience >= 1200) return '咖啡研习大师'
    if (this.summary.experience >= 700) return '精品咖啡探索家'
    if (this.summary.experience >= 360) return '进阶研习者'
    if (this.summary.experience >= 160) return '咖啡爱好者'
    if (this.summary.experience >= 60) return '初阶探索者'
    return '咖啡新手'
  }

  private nextLevel(): number {
    if (this.summary.experience < 60) return 60
    if (this.summary.experience < 160) return 160
    if (this.summary.experience < 360) return 360
    if (this.summary.experience < 700) return 700
    if (this.summary.experience < 1200) return 1200
    return 1200
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
          Text('成长统计').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 })
        }.width('100%')
        if (this.loadError.length > 0) {
          Row() {
            Text(this.loadError).fontSize(12).fontColor(Theme.colors().danger).layoutWeight(1)
            Text('重试').fontSize(12).fontColor(Theme.colors().brandPrimary).onClick(() => this.load())
          }.padding(14).backgroundColor(Theme.colors().surfaceCard).borderRadius(14)
        }
        Column({ space: 6 }) {
          Text(this.levelName()).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#F3EBDD')
          Text(`${this.summary.experience} 经验 · 由真实行为累计`).fontSize(12).fontColor('#D8C7B2')
          Progress({ value: this.summary.experience, total: this.nextLevel(), type: ProgressType.Linear }).color('#B47A43').width('100%')
        }.padding(22).backgroundColor('#241B17').borderRadius(24).width('100%').alignItems(HorizontalAlign.Start)
        if (!this.hasSummary && this.summaryLoading) {
          Row({ space: 10 }) {
            LoadingProgress().width(20).height(20).color(Theme.colors().brandPrimary)
            Text('正在同步成长统计…').fontSize(13).fontColor(Theme.colors().textSecondary)
          }.width('100%').padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(17)
        } else {
          Row({ space: 8 }) {
            CoffeeMetricCard({ label: '学习', value: this.summary.learningCount, cardColor: '#EAD9C5' }).layoutWeight(1)
            CoffeeMetricCard({ label: '制作', value: this.summary.brewCount, cardColor: '#EAD9C5' }).layoutWeight(1)
            CoffeeMetricCard({ label: '测评', value: this.summary.evaluationCount, cardColor: '#EAD9C5' }).layoutWeight(1)
            CoffeeMetricCard({ label: '打卡', value: this.summary.checkInCount, cardColor: '#EAD9C5' }).layoutWeight(1)
          }.width('100%')
        }
        AppBarChart({ title: '近 7 日有效活动', items: this.activityItems() })
        AppBarChart({ title: '冲煮方式分布', items: this.methodItems() })
        Text('趋势由已保存的学习、制作和测评记录实时计算；空数据不会生成虚假图表。').fontSize(10).fontColor(Theme.colors().textTertiary).width('100%')
        Text('成就证据').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
        GrowthAchievementRow({ name: '初次学习', achieved: this.summary.learningCount > 0 })
        GrowthAchievementRow({ name: '首次制作', achieved: this.summary.brewCount > 0 })
        GrowthAchievementRow({ name: '首次测评', achieved: this.summary.evaluationCount > 0 })
        GrowthAchievementRow({ name: '配方收藏', achieved: this.summary.recipeFavoriteCount > 0 })
        Text('经验只由学习完成、保存制作、有效测评和打卡等真实行为产生，打开页面不会增加经验。')
          .fontSize(11).lineHeight(18).fontColor(Theme.colors().textSecondary).margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

}
