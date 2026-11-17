import { CanvasDocument, CanvasLayer } from './ArtModels'

// Editing keeps the wire model unchanged. Only the edited layer is copied per frame;
// JSON snapshots are reserved for undo boundaries and persistence.
export class CanvasEditing {
  static refresh(source: CanvasDocument): CanvasDocument {
    const result = new CanvasDocument()
    result.schemaVersion = source.schemaVersion; result.width = source.width; result.height = source.height
    result.backgroundKey = source.backgroundKey; result.colorTheme = source.colorTheme
    result.layers = source.layers.slice()
    return result
  }
  static layer(source: CanvasLayer): CanvasLayer {
    const result = new CanvasLayer()
    result.id = source.id; result.kind = source.kind; result.materialId = source.materialId
    result.imageKey = source.imageKey; result.text = source.text; result.color = source.color
    result.x = source.x; result.y = source.y; result.scale = source.scale; result.rotation = source.rotation
    return result
  }
  private static replace(source: CanvasDocument, layer: CanvasLayer): CanvasDocument {
    const result = CanvasEditing.refresh(source)
    result.layers = source.layers.map(item => item.id === layer.id ? layer : item)
    return result
  }
  static move(source: CanvasDocument, id: string, x: number, y: number): CanvasDocument {
    const selected = source.layers.find(layer => layer.id === id)
    if (selected === undefined || !Number.isFinite(x) || !Number.isFinite(y)) return source
    const layer = CanvasEditing.layer(selected)
    layer.x = Math.max(0, Math.min(1, x)); layer.y = Math.max(0, Math.min(1, y))
    return CanvasEditing.replace(source, layer)
  }
  static resize(source: CanvasDocument, id: string, value: number): CanvasDocument {
    const selected = source.layers.find(layer => layer.id === id)
    if (selected === undefined || !Number.isFinite(value)) return source
    const layer = CanvasEditing.layer(selected)
    layer.scale = Math.round(Math.max(.08, Math.min(1.5, value)) * 100) / 100
    return CanvasEditing.replace(source, layer)
  }
  static rotate(source: CanvasDocument, id: string): CanvasDocument {
    const selected = source.layers.find(layer => layer.id === id)
    if (selected === undefined) return source
    const layer = CanvasEditing.layer(selected)
    layer.rotation = (layer.rotation + 15 + 360) % 360
    return CanvasEditing.replace(source, layer)
  }
}
