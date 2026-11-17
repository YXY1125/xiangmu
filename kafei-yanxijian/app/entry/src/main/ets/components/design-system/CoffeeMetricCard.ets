import { Theme } from './Theme'

/** Reactive metric tile. Use a component instead of a local @Builder value parameter. */
@Component
export struct CoffeeMetricCard {
  @Prop label: string = ''
  @Prop value: number = 0
  @Prop cardColor: string = '#FFFDFC'

  build() {
    Column({ space: 4 }) {
      Text(`${this.value}`)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.colors().textPrimary)
      Text(this.label)
        .fontSize(11)
        .fontColor(Theme.colors().textSecondary)
    }
    .height(92)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.cardColor)
    .borderRadius(17)
  }
}
