import { EditorLayer } from './EditorLayer'
import { Theme } from '../components/design-system/Theme'
import { AssetResolver } from '../utils/AssetResolver'

/** Stable layer identity keeps the same gesture target throughout a drag. */
@Component
export struct ArtworkLayerView {
  @ObjectLink layer: EditorLayer
  @Prop displayScale: number = 1
  @Prop selected: boolean = false
  @Prop previewing: boolean = false
  onSelect: () => void = () => {}
  onLayerPanStart: () => void = () => {}
  onDragUpdate: (event: GestureEvent) => void = () => {}

  build() {
    Stack() {
      if (this.layer.layerType === 'text' || this.layer.layerType === 'sticker') {
        Text(this.layer.text)
          .fontSize((this.layer.layerType === 'text' ? 62 / 300 : 90 / 260) * this.layer.width * this.displayScale)
          .fontWeight(FontWeight.Bold).fontColor(Theme.colors().brandPrimary).textAlign(TextAlign.Center)
          .width('100%').height('100%')
      } else {
        Image(AssetResolver.media(this.layer.assetId)).objectFit(ImageFit.Contain).width('100%').height('100%')
      }
    }.width(this.layer.width * this.displayScale).height(this.layer.height * this.displayScale)
      .position({ x: this.layer.x * this.displayScale, y: this.layer.y * this.displayScale })
      .rotate({ angle: this.layer.rotation }).opacity(this.layer.opacity).zIndex(this.layer.zIndex)
      .border({ width: this.selected ? 2 : 0, color: Theme.colors().brandAccent })
      .id('editor-layer-' + this.layer.layerId).enabled(!this.previewing)
      .onClick(() => this.onSelect())
      .gesture(PanGesture().onActionStart(() => this.onLayerPanStart())
        .onActionUpdate((event: GestureEvent) => this.onDragUpdate(event)))
  }
}
