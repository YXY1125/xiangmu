import { ArtImage } from './ArtImage'
import { Theme } from './design-system/Theme'

@Component
export struct LoadState {
  @Prop loading: boolean = false
  @Prop message: string = ''
  @Prop emptyText: string = '暂时没有内容'
  @Prop emptyImage: string = 'empty_search'
  onRetry: () => void = () => {}
  build() {
    Column({ space: 12 }) {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(Theme.colors().brandPrimary)
        Text('正在读取…').fontSize(14).fontColor(Theme.colors().textSecondary)
      } else {
        ArtImage({ imageKey: this.message ? 'empty_network' : this.emptyImage, fit: ImageFit.Contain }).width(140).height(140)
        Text(this.message || this.emptyText).fontSize(14).fontColor(Theme.colors().textSecondary).textAlign(TextAlign.Center)
        if (this.message) Button('重新加载').onClick(() => this.onRetry()).backgroundColor(Theme.colors().brandPrimary)
      }
    }.width('100%').padding(32)
  }
}
