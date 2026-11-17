import { Theme } from '../components/design-system/Theme'
import { AppHeader } from '../components/design-system/AppHeader'
import { AppBarChart, AppRingChart, BarChartItem } from '../components/design-system/AppChart'
import { AppCard } from '../components/design-system/AppCard'

function buildTrendItems(): BarChartItem[] {
  return []
}

@Component
export struct DashboardPage {
  private trendItems: BarChartItem[] = buildTrendItems()

  build() {
    Scroll() {
      Column({ space: Theme.space.s4 }) {
        AppHeader({ title: '数据看板', subtitle: '经营指标与趋势' })
        Column() {
          AppRingChart({ title: '任务完成率', percent: 0 })
        }
        .padding({ left: Theme.space.pageX, right: Theme.space.pageX })
        .width('100%')
        Column() {
          AppBarChart({
            title: '近五日业务趋势',
            items: this.trendItems
          })
        }
        .padding({ left: Theme.space.pageX, right: Theme.space.pageX })
        .width('100%')
        Column() {
          AppCard({ title: '预警', variant: 'outlined' }) {
            Text('暂无真实业务数据。此通用组件未接入应用路由。')
              .fontSize(Theme.type.body)
              .fontColor(Theme.colors().warning)
          }
        }
        .padding({ left: Theme.space.pageX, right: Theme.space.pageX })
        .width('100%')
      }
      .padding({ bottom: Theme.space.s8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.colors().surfacePage)
  }
}
