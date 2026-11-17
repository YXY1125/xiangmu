import { StudioAsset } from './StudioAsset'
import { StudioObject, StudioSnapshot } from '../models/FlowerModels'

@Component
export struct StudioPreview {
  @Prop snapshot: StudioSnapshot = new StudioSnapshot()
  @Prop previewWidth: number = 170
  private ratio(): number { return this.previewWidth / 336 }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.snapshot.background === 'garden') Image($r('app.media.banner_workshop')).width('100%').height('100%').objectFit(ImageFit.Cover).opacity(0.5)
      if (this.snapshot.background !== 'garden') Column().width('100%').height('100%').linearGradient({ angle: 135, colors: [['#FFF8EE', 0], ['#F4DED7', 1]] })
      ForEach(this.snapshot.objects, (item: StudioObject) => {
        Stack({ alignContent: Alignment.TopStart }) {
          if (item.atlasKey && item.atlasKey.length > 0) {
            if (item.atlasKey === 'decorations') {
              Image(StudioAsset.atlas(item.atlasKey)).width(224).height(75).objectFit(ImageFit.Fill).position({ x: -item.atlasIndex * 56, y: 0 })
            } else {
              Image(StudioAsset.atlas(item.atlasKey)).width(280).height(112).objectFit(ImageFit.Fill).position({ x: -(item.atlasIndex % 5) * 56, y: -Math.floor(item.atlasIndex / 5) * 56 })
            }
          } else {
            Image(StudioAsset.image(item.assetKey)).width(56).height(75).objectFit(ImageFit.Contain)
          }
        }.width(56).height(75).clip(true).position({ x: item.x * this.ratio(), y: item.y * this.ratio() }).scale({ x: item.scale, y: item.scale }).rotate({ angle: item.rotation }).zIndex(item.zIndex)
      }, (item: StudioObject) => item.objectId)
      Image(this.snapshot.container === 'basket' ? $r('app.media.container_basket') : $r('app.media.empty_vase')).width(this.snapshot.container === 'basket' ? 120 : 75).height(85).objectFit(ImageFit.Contain).position({ x: (this.snapshot.container === 'basket' ? 52 : 92) * this.ratio(), y: 205 * this.ratio() }).zIndex(100)
    }.width(this.previewWidth).height(this.previewWidth * 1.1).clip(true).borderRadius(18).backgroundColor('#FFF8EE')
  }
}
