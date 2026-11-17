import { GameRecord, UserArtwork } from '../models/CultureModels'
import { HttpClient } from './HttpClient'

class FavoriteSync {
  id: string = ''
  targetId: string = ''
  active: boolean = false
}
class LearningSync { id: string = ''; articleId: string = '' }
class BrowsingSync { id: string = ''; exhibitionId: string = ''; progress: number = 0 }

export class CloudSyncService {
  private static loggedIn(): boolean { return (AppStorage.get<string>('accessToken') ?? '').length > 0 }

  static async favorite(targetId: string, active: boolean): Promise<void> {
    if (!CloudSyncService.loggedIn()) return
    const body = new FavoriteSync(); body.id = `favorite-${targetId}`; body.targetId = targetId; body.active = active
    const response = await HttpClient.post<FavoriteSync>('/biz/zxznh.xcl.huawei/favorites', body)
    AppStorage.setOrCreate('lastSyncError', response.code === 0 ? '' : response.message)
  }

  static async artwork(work: UserArtwork): Promise<void> {
    if (!CloudSyncService.loggedIn()) return
    work.id = work.artworkId
    const response = await HttpClient.post<UserArtwork>('/biz/zxznh.xcl.huawei/artworks', work)
    AppStorage.setOrCreate('lastSyncError', response.code === 0 ? '' : response.message)
  }

  static async game(record: GameRecord): Promise<void> {
    if (!CloudSyncService.loggedIn()) return
    record.id = record.recordId
    const response = await HttpClient.post<GameRecord>('/biz/zxznh.xcl.huawei/game-records', record)
    AppStorage.setOrCreate('lastSyncError', response.code === 0 ? '' : response.message)
  }

  static async learning(articleId: string): Promise<void> {
    if (!CloudSyncService.loggedIn()) return
    const body = new LearningSync(); body.id = `learning-${articleId}`; body.articleId = articleId
    const response = await HttpClient.post<LearningSync>('/biz/zxznh.xcl.huawei/learning-records', body)
    AppStorage.setOrCreate('lastSyncError', response.code === 0 ? '' : response.message)
  }

  static async browsing(exhibitionId: string, progress: number): Promise<void> {
    if (!CloudSyncService.loggedIn()) return
    const body = new BrowsingSync(); body.id = `browsing-${exhibitionId}`; body.exhibitionId = exhibitionId; body.progress = progress
    const response = await HttpClient.post<BrowsingSync>('/biz/zxznh.xcl.huawei/browsing-records', body)
    AppStorage.setOrCreate('lastSyncError', response.code === 0 ? '' : response.message)
  }
}
