import { CanvasLayer } from '../models/ArtModels'
import { ArtImage } from './ArtImage'

// A stable observable view instance for each layer ID. ForEach must not cache
// closures over obsolete plain JSON layers when a document is replaced.
@Observed
export class CanvasRenderLayer extends CanvasLayer {
  update(source: CanvasLayer): void {
    this.kind = source.kind; this.imageKey = source.imageKey; this.text = source.text
    this.x = source.x; this.y = source.y; this.scale = source.scale
    this.rotation = source.rotation; this.color = source.color
  }
}

@Component
export struct CanvasLayerView {
  @ObjectLink layer: CanvasRenderLayer
  @Prop canvasWidth: number = 300
  @Prop selected: boolean = false
  @Prop interactive: boolean = false
  private startX: number = 0
  private startY: number = 0
  private lastX: number = 0
  private lastY: number = 0
  onSelect: (id: string) => void = () => {}
  onMove: (id: string, x: number, y: number, finished: boolean) => void = () => {}
  private widthValue(): number { return this.canvasWidth * this.layer.scale }
  private move(event: GestureEvent, finished: boolean): void {
    if (!this.interactive || this.canvasWidth <= 0) return
    this.lastX = this.startX + event.offsetX / this.canvasWidth
    this.lastY = this.startY + event.offsetY / (this.canvasWidth * 1.25)
    this.onMove(this.layer.id, this.lastX, this.lastY, finished)
  }
  build() {
    Stack() {
      if (this.layer.kind === 'text') {
        Text(this.layer.text).fontSize(Math.max(12, 34 * this.layer.scale)).fontColor(this.layer.color)
          .fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).width('100%')
      } else ArtImage({ imageKey: this.layer.imageKey, fit: ImageFit.Contain })
    }.id(this.selected && this.interactive ? 'canvas-selected-layer' : 'canvas-layer-' + this.layer.id)
      .accessibilityText('图层 ' + this.layer.id + '，缩放 ' + Math.round(this.layer.scale * 100) + '%，旋转 ' + this.layer.rotation + '°')
      .width(this.widthValue()).height(this.layer.kind === 'text' ? this.widthValue() * .4 : this.widthValue())
      .position({ x: this.layer.x * this.canvasWidth - this.widthValue() / 2,
        y: this.layer.y * this.canvasWidth * 1.25 - (this.layer.kind === 'text' ? this.widthValue() * .2 : this.widthValue() / 2) })
      .rotate({ angle: this.layer.rotation })
      .border({ width: this.interactive && this.selected ? 1.5 : 0, color: '#A93635', style: BorderStyle.Dashed })
      .onClick(() => { if (this.interactive) this.onSelect(this.layer.id) })
      .onGestureJudgeBegin(() => this.interactive ? GestureJudgeResult.CONTINUE : GestureJudgeResult.REJECT)
      .gesture(PanGesture().onActionStart(() => {
        this.startX = this.layer.x; this.startY = this.layer.y
        this.lastX = this.startX; this.lastY = this.startY
        if (this.interactive) this.onSelect(this.layer.id)
      }).onActionUpdate((event: GestureEvent) => this.move(event, false))
        .onActionEnd((event: GestureEvent) => this.move(event, true))
        .onActionCancel(() => { if (this.interactive) this.onMove(this.layer.id, this.lastX, this.lastY, true) }))
  }
}
