import { StudioObject } from '../models/FlowerModels'

export class StudioAsset {
  static image(key: string): Resource {
    if (key === 'tulip') return $r('app.media.material_tulip')
    if (key === 'lily') return $r('app.media.material_lily')
    if (key === 'peony') return $r('app.media.material_peony')
    if (key === 'eucalyptus') return $r('app.media.material_eucalyptus')
    if (key === 'babys_breath') return $r('app.media.material_babys_breath')
    return $r('app.media.material_rose')
  }

  static atlas(key: string): Resource {
    if (key === 'decorations') return $r('app.media.decorations_cutout')
    if (key === 'atlas_filler') return $r('app.media.atlas_filler_cutout')
    if (key === 'atlas_bulb') return $r('app.media.atlas_bulb_cutout')
    if (key === 'atlas_line') return $r('app.media.atlas_line_cutout')
    if (key === 'atlas_foliage') return $r('app.media.atlas_foliage_cutout')
    if (key === 'atlas_special') return $r('app.media.atlas_special_cutout')
    return $r('app.media.atlas_main_cutout')
  }
}

@Component
export struct StudioObjectView {
  @Prop item: StudioObject = new StudioObject()
  @Prop selected: boolean = false
  onSelect: () => void = () => {}
  onBegin: () => void = () => {}
  onChanged: (x: number, y: number, scale: number, rotation: number) => void =
    (_x: number, _y: number, _scale: number, _rotation: number) => {}
  onEnd: () => void = () => {}
  private startX: number = 0
  private startY: number = 0
  private startScale: number = 1
  private startRotation: number = 0

  private begin(): void {
    this.startX = this.item.x
    this.startY = this.item.y
    this.startScale = this.item.scale
    this.startRotation = this.item.rotation
    this.onSelect()
    this.onBegin()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.item.atlasKey.length > 0) {
        if (this.item.atlasKey === 'decorations') {
          Image(StudioAsset.atlas(this.item.atlasKey)).width(448).height(150).objectFit(ImageFit.Fill).position({ x: -this.item.atlasIndex * 112, y: 0 })
        } else {
          Image(StudioAsset.atlas(this.item.atlasKey)).width(560).height(224).objectFit(ImageFit.Fill).position({ x: -(this.item.atlasIndex % 5) * 112, y: -Math.floor(this.item.atlasIndex / 5) * 112 })
        }
      } else {
        Image(StudioAsset.image(this.item.assetKey)).width(112).height(150).objectFit(ImageFit.Contain)
      }
    }
      .width(112)
      .height(150)
      .clip(true)
      .position({ x: this.item.x, y: this.item.y })
      .scale({ x: this.item.scale, y: this.item.scale })
      .rotate({ angle: this.item.rotation })
      .zIndex(this.item.zIndex)
      .border({ width: this.selected ? 2 : 0, color: '#D98B91' })
      .borderRadius(12)
      .onClick(() => this.onSelect())
      .gesture(GestureGroup(GestureMode.Parallel,
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 2 })
          .onActionStart(() => this.begin())
          .onActionUpdate((event: GestureEvent) => {
            const x = Math.max(-36, Math.min(252, this.startX + event.offsetX))
            const y = Math.max(-54, Math.min(250, this.startY + event.offsetY))
            this.onChanged(x, y, this.item.scale, this.item.rotation)
          })
          .onActionEnd(() => this.onEnd()),
        PinchGesture({ fingers: 2, distance: 3 })
          .onActionStart(() => this.begin())
          .onActionUpdate((event: GestureEvent) => {
            const scale = Math.max(0.3, Math.min(1.8, this.startScale * event.scale))
            this.onChanged(this.item.x, this.item.y, scale, this.item.rotation)
          })
          .onActionEnd(() => this.onEnd()),
        RotationGesture({ fingers: 2, angle: 2 })
          .onActionStart(() => this.begin())
          .onActionUpdate((event: GestureEvent) => {
            this.onChanged(this.item.x, this.item.y, this.item.scale, this.startRotation + event.angle)
          })
          .onActionEnd(() => this.onEnd())
      ))
  }
}
