export class EditorGeometry {
  static heightForRatio(ratio: string): number {
    return ratio === '3:4' ? 1200 : ratio === '9:16' ? 1600 : 900
  }

  static fitScale(canvasWidth: number, canvasHeight: number, availableWidth: number, availableHeight: number, zoom: number): number {
    const width = Math.max(80, availableWidth - 24)
    const height = Math.max(80, availableHeight - 24)
    return Math.min(width / canvasWidth, height / canvasHeight) * Math.max(0.4, Math.min(1, zoom))
  }

  static boundedPosition(position: number, deltaVp: number, scale: number, objectExtent: number, canvasExtent: number): number {
    return Math.max(0, Math.min(Math.max(0, canvasExtent - objectExtent), position + deltaVp / Math.max(0.01, scale)))
  }
}
