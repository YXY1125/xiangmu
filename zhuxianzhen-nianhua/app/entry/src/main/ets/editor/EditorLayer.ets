import { ArtworkLayer } from '../models/CultureModels'

/** UI-only observed model. Persisted JSON is always rehydrated through from(). */
@Observed
export class EditorLayer {
  layerId: string = ''
  assetId: string = ''
  layerType: string = 'character'
  x: number = 120
  y: number = 160
  width: number = 150
  height: number = 150
  rotation: number = 0
  zIndex: number = 1
  opacity: number = 1
  text: string = ''

  static from(source: ArtworkLayer): EditorLayer {
    const layer = new EditorLayer()
    layer.copyFrom(source)
    return layer
  }

  copyFrom(source: ArtworkLayer): void {
    this.layerId = source.layerId
    this.assetId = source.assetId
    this.layerType = source.layerType
    this.x = source.x
    this.y = source.y
    this.width = source.width
    this.height = source.height
    this.rotation = source.rotation
    this.zIndex = source.zIndex
    this.opacity = source.opacity
    this.text = source.text
  }
}
