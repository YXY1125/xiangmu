export class CharacterProfile {
  id: string = ''
  name: string = ''
  series: string = ''
  image: string = ''
  personality: string = ''
  origin: string = ''
  meaning: string = ''
  story: string = ''
}

export class CultureArticle {
  id: string = ''
  title: string = ''
  category: string = ''
  summary: string = ''
  body: string = ''
  image: string = ''
  sourceNote: string = ''
  original: boolean = false
}

export class Exhibition {
  id: string = ''
  title: string = ''
  intro: string = ''
  image: string = ''
  itemIds: string[] = []
}

export class CreativeTemplate {
  id: string = ''
  name: string = ''
  category: string = ''
  ratio: string = '1:1'
  background: string = ''
  defaultAsset: string = ''
}

export class ArtworkLayer {
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
}

export class UserArtwork {
  id: string = ''
  artworkId: string = ''
  ownerId: string = 'guest'
  title: string = ''
  canvasWidth: number = 900
  canvasHeight: number = 900
  backgroundId: string = 'paper'
  layers: ArtworkLayer[] = []
  textObjects: ArtworkLayer[] = []
  createdAt: number = 0
  updatedAt: number = 0
  clientCreatedAt: number = 0
  clientUpdatedAt: number = 0
  thumbnailPath: string = ''
  exportPath: string = ''
}

export class GameRecord {
  id: string = ''
  recordId: string = ''
  ownerId: string = 'guest'
  gameId: string = ''
  score: number = 0
  durationSeconds: number = 0
  detail: string = ''
  completedAt: number = 0
}

/** Current-owner personal-space data, read as one serialized snapshot. */
export class MySpaceSnapshot {
  ownerId: string = ''
  favoriteIds: string[] = []
  artworks: UserArtwork[] = []
  gameRecords: GameRecord[] = []
  learningIds: string[] = []
}
