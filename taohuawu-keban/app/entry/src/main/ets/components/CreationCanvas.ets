import { CanvasDocument } from '../models/ArtModels'
import { ArtImage } from './ArtImage'
import { CanvasLayerView, CanvasRenderLayer } from './CanvasLayerView'

@Component
export struct CreationCanvas {
  @Prop @Watch('syncLayers') document: CanvasDocument = new CanvasDocument()
  @Prop selectedId: string = ''
  @Prop interactive: boolean = false
  @State canvasWidth: number = 300
  @State renderLayers: CanvasRenderLayer[] = []
  onSelect: (id: string) => void = () => {}
  onMove: (id: string, x: number, y: number, finished: boolean) => void = () => {}
  aboutToAppear(): void { this.syncLayers() }
  private syncLayers(): void {
    const next: CanvasRenderLayer[] = []
    for (const source of this.document.layers) {
      let layer = this.renderLayers.find(item => item.id === source.id)
      if (layer === undefined) { layer = new CanvasRenderLayer(); layer.id = source.id }
      layer.update(source); next.push(layer)
    }
    // Keep layer identities (and decoded images) stable during transforms.
    if (next.length !== this.renderLayers.length || next.some((layer, index) => layer !== this.renderLayers[index])) this.renderLayers = next
  }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ArtImage({ imageKey: this.document.backgroundKey, fit: this.document.backgroundKey.startsWith('festival_') ? ImageFit.Contain : ImageFit.Cover }).width('100%').height('100%').backgroundColor('#FFF8F0')
      ForEach(this.renderLayers, (layer: CanvasRenderLayer) => {
        CanvasLayerView({ layer: layer, canvasWidth: this.canvasWidth, selected: this.selectedId === layer.id,
          interactive: this.interactive, onSelect: this.onSelect, onMove: this.onMove })
      }, (layer: CanvasRenderLayer) => layer.id)
    }.width('100%').aspectRatio(.8).clip(true)
      .border({ width: 2, color: this.document.colorTheme === 'sage' ? '#53785D' : this.document.colorTheme === 'ink' ? '#493B3A' : '#D95C52' })
      .onAreaChange((oldArea: Area, newArea: Area) => { this.canvasWidth = Number(newArea.width) })
  }
}
