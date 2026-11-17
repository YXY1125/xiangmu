import { UserArtwork, GameRecord } from './CultureModels'

export class SyncJob {
  id: string = ''
  module: string = ''
  payload: string = ''
  version: number = 0
}
export class PrivateList<T> { items: T[] = []; total: number = 0 }
export class FavoriteState { id: string = ''; targetId: string = ''; active: boolean = false }
export class LearningState { id: string = ''; articleId: string = '' }
export class BrowsingState { id: string = ''; exhibitionId: string = ''; progress: number = 0 }
export class PrivateSnapshot {
  favorites: FavoriteState[] = []
  artworks: UserArtwork[] = []
  games: GameRecord[] = []
  learning: LearningState[] = []
  browsing: BrowsingState[] = []
}
