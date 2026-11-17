import { Theme } from '../design-system/Theme'

@Component
export struct SectionTitle {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  onMore: () => void = () => {}

  build() {
    Row() {
      Column({ space: 3 }) {
        Text(this.title).fontSize(Theme.type.title3).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontSize(Theme.type.caption).fontColor(Theme.colors().textSecondary)
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('查看全部').fontSize(Theme.type.caption).fontColor(Theme.colors().brandPrimary)
        .height(44).padding({ left: 12, right: 4 }).onClick(() => this.onMore())
    }.width('100%').alignItems(VerticalAlign.Center)
  }
}
