import { AppIcon } from './AppIcon'
import { Theme } from './Theme'

/** 详情页统一收藏入口：始终在原位置反馈加载、成功、失败和已收藏状态。 */
@Component
export struct FavoriteAction {
  @Prop selected: boolean = false
  @Prop saving: boolean = false
  @Prop feedback: string = ''
  onAction: () => void = () => {}

  private label(): string {
    if (this.saving) return '收藏中…'
    if (this.selected) return '已收藏'
    if (this.feedback.length > 0) return this.feedback
    return '收藏'
  }

  private foreground(): string {
    if (this.selected) return Theme.colors().success
    if (this.feedback.length > 0) return Theme.colors().danger
    return Theme.colors().brandPrimary
  }

  private resolvedBackground(): ResourceColor {
    if (this.selected) return Theme.colors().successContainer
    if (this.feedback.length > 0) return Theme.colors().dangerContainer
    return Color.Transparent
  }

  build() {
    Row({ space: Theme.space.s1 }) {
      AppIcon({
        name: 'favorite',
        iconSize: Theme.icon.sm,
        color: this.foreground(),
        active: this.selected
      })
      Text(this.label())
        .fontSize(Theme.type.captionL)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.foreground())
        .maxLines(1)
    }
    .height(Theme.icon.minTouch)
    .padding({ left: Theme.space.s2, right: Theme.space.s2 })
    .borderRadius(Theme.radius.pill)
    .backgroundColor(this.resolvedBackground())
    .opacity(this.saving ? 0.72 : 1)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
    .accessibilityText(this.selected ? '已收藏' : this.label())
    .onClick(() => {
      if (!this.saving) this.onAction()
    })
  }
}
