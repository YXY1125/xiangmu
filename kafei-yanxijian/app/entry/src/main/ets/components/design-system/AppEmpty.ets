import { Theme } from './Theme'
import { AppButton } from './AppButton'
import { AppIcon } from './AppIcon'

@Component
export struct AppEmpty {
  @Prop title: ResourceStr = '暂无内容'
  @Prop description: ResourceStr = '当前还没有可展示的数据'
  @Prop actionLabel: ResourceStr = ''
  onAction: () => void = () => {}

  build() {
    Column({ space: Theme.space.s3 }) {
      AppIcon({ name: 'empty', iconSize: Theme.icon.xl, color: Theme.colors().textTertiary })
      Text(this.title)
        .fontSize(Theme.type.title3)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.colors().textPrimary)
      Text(this.description)
        .fontSize(Theme.type.callout)
        .fontColor(Theme.colors().textSecondary)
        .textAlign(TextAlign.Center)
      if (this.actionLabel !== '') {
        AppButton({
          label: this.actionLabel,
          variant: 'primary',
          onTap: () => this.onAction()
        })
      }
    }
    .width('100%')
    .padding(Theme.space.s7)
    .justifyContent(FlexAlign.Center)
  }
}
