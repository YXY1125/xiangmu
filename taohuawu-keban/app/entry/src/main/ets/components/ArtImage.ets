import { MediaCatalog } from '../models/MediaCatalog'
import { Theme } from './design-system/Theme'

@Component
export struct ArtImage {
  @Prop @Watch('resetImage') imageKey: string = ''
  @Prop fit: ImageFit = ImageFit.Cover
  @State failed: boolean = false
  private resetImage(): void { this.failed = false }
  build() {
    Stack() {
      if (MediaCatalog.image(this.imageKey) !== undefined && !this.failed) {
        Image(MediaCatalog.image(this.imageKey))
          .width('100%').height('100%').objectFit(this.fit)
          .onError(() => { this.failed = true })
      } else {
        Text('图片暂不可用').fontSize(12).fontColor(Theme.colors().textSecondary)
      }
    }.width('100%').height('100%')
  }
}
