import { Theme } from './Theme'

export class BarChartItem {
  value: number = 0
  label: string = ''
}

/**
 * Lightweight charts driven only by real caller-provided values.
 */
@Component
export struct AppBarChart {
  @Prop title: string = ''
  @Prop items: BarChartItem[] = []
  private maxVal(): number {
    let m = 1
    for (let item of this.items) {
      if (item.value > m) {
        m = item.value
      }
    }
    return m
  }

  build() {
    Column({ space: Theme.space.s3 }) {
      if (this.title.length > 0) {
        Text(this.title)
          .fontSize(Theme.type.title3)
          .fontColor(Theme.colors().textPrimary)
          .width('100%')
      }
      if (this.items.length === 0) {
        Text('暂无可统计数据').fontSize(Theme.type.body).fontColor(Theme.colors().textTertiary).height(80).width('100%').textAlign(TextAlign.Center)
      } else {
        Row({ space: Theme.space.s2 }) {
          ForEach(this.items, (item: BarChartItem, idx: number) => {
            Column({ space: Theme.space.s1 }) {
              Text(`${item.value}`).fontSize(Theme.type.caption).fontColor(Theme.colors().textSecondary)
              Column()
                .width('100%')
                .height(110 * (item.value / this.maxVal()))
                .backgroundColor(Theme.colors().chart1)
                .borderRadius(Theme.radius.xs)
              Text(item.label)
                .fontSize(Theme.type.caption)
                .fontColor(Theme.colors().textTertiary)
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.End)
            .height(150)
          }, (item: BarChartItem, idx: number) => `bar-${idx}`)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
    }
    .width('100%')
    .padding(Theme.space.cardPadding)
    .backgroundColor(Theme.colors().surfaceCard)
    .borderRadius(Theme.radius.md)
  }
}

@Component
export struct AppRingChart {
  @Prop title: string = '完成率'
  @Prop percent: number = 0.86

  build() {
    Column({ space: Theme.space.s2 }) {
      Text(this.title)
        .fontSize(Theme.type.title3)
        .fontColor(Theme.colors().textPrimary)
      Stack() {
        Progress({ value: this.percent * 100, total: 100, type: ProgressType.Ring })
          .width(120)
          .height(120)
          .color(Theme.colors().brandPrimary)
          .style({ strokeWidth: 10 })
        Text(`${Math.round(this.percent * 100)}%`)
          .fontSize(Theme.type.title2)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.colors().textPrimary)
      }
    }
    .width('100%')
    .padding(Theme.space.cardPadding)
    .backgroundColor(Theme.colors().surfaceCard)
    .borderRadius(Theme.radius.md)
    .alignItems(HorizontalAlign.Center)
  }
}
