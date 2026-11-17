import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { GameRecord, UserArtwork, MySpaceSnapshot } from '../models/CultureModels'
import { HttpClient } from './HttpClient'
import { EmptyPayload } from '../models/ApiModels'
import { SyncJob, PrivateList, FavoriteState, LearningState, BrowsingState, PrivateSnapshot } from '../models/SyncModels'

const STORE_NAME = 'zxznh_local_business_v1'

export class LocalDataStore {
  private static pref: preferences.Preferences | null = null
  private static owner: string = 'guest'
  private static pending: Promise<void> = Promise.resolve()
  private static synchronizing: boolean = false

  private static serial<T>(job: () => Promise<T>): Promise<T> {
    const result = LocalDataStore.pending.then(job)
    LocalDataStore.pending = result.then(() => {}).catch(() => {})
    return result
  }

  static async init(context: common.UIAbilityContext): Promise<void> {
    LocalDataStore.pref = await preferences.getPreferences(context, STORE_NAME)
    LocalDataStore.refreshOwner()
    if (AppStorage.get<number>('businessDataRevision') === undefined) AppStorage.setOrCreate('businessDataRevision', 0)
  }

  static refreshOwner(): void {
    const current = AppStorage.get<string>('currentUserId') ?? ''
    LocalDataStore.owner = current.length > 0 ? `zxznh:user:${encodeURIComponent(current)}` : 'zxznh:guest'
  }

  static ownerId(): string {
    LocalDataStore.refreshOwner()
    return LocalDataStore.owner
  }

  private static publishChange(owner: string): void {
    if (owner !== LocalDataStore.ownerId()) return
    AppStorage.setOrCreate('businessDataRevision', (AppStorage.get<number>('businessDataRevision') ?? 0) + 1)
  }

  static async mySpaceSnapshot(): Promise<MySpaceSnapshot> {
    const owner = LocalDataStore.ownerId()
    return LocalDataStore.serial<MySpaceSnapshot>(async (): Promise<MySpaceSnapshot> => {
      if (LocalDataStore.pref === null) throw new Error('本地数据服务尚未初始化')
      const snapshot = new MySpaceSnapshot()
      snapshot.ownerId = owner
      snapshot.favoriteIds = await LocalDataStore.favorites(owner)
      const works = await LocalDataStore.read('artworks', owner)
      const games = await LocalDataStore.read('gameRecords', owner)
      snapshot.artworks = works.length === 0 ? [] : JSON.parse(works) as UserArtwork[]
      snapshot.gameRecords = games.length === 0 ? [] : JSON.parse(games) as GameRecord[]
      if (!Array.isArray(snapshot.artworks) || !Array.isArray(snapshot.gameRecords)) throw new Error('个人记录格式异常')
      snapshot.learningIds = await LocalDataStore.learningIds(owner)
      return snapshot
    })
  }

  private static key(name: string, owner: string): string {
    return JSON.stringify([owner, name])
  }

  private static async read(name: string, owner: string = LocalDataStore.ownerId()): Promise<string> {
    if (LocalDataStore.pref === null) {
      return ''
    }
    const value = await LocalDataStore.pref.get(LocalDataStore.key(name, owner), '')
    return typeof value === 'string' ? value : ''
  }

  private static async write(name: string, value: string, owner: string): Promise<void> {
    if (LocalDataStore.pref === null) {
      throw new Error('本地数据服务尚未初始化')
    }
    await LocalDataStore.pref.put(LocalDataStore.key(name, owner), value)
    await LocalDataStore.pref.flush()
  }

  static async favorites(owner: string = LocalDataStore.ownerId()): Promise<string[]> {
    const value = await LocalDataStore.read('favorites', owner)
    return value.length === 0 ? [] : value.split('|').filter((id: string) => id.length > 0)
  }

  static async toggleFavorite(id: string): Promise<boolean> {
    const owner = LocalDataStore.ownerId()
    return LocalDataStore.serial<boolean>(async (): Promise<boolean> => {
    const values = await LocalDataStore.favorites(owner)
    const index = values.indexOf(id)
    let active = false
    if (index >= 0) {
      values.splice(index, 1)
    } else {
      values.push(id)
      active = true
    }
    await LocalDataStore.write('favorites', values.join('|'), owner)
    LocalDataStore.publishChange(owner)
    const state = new FavoriteState()
    state.id = 'favorite-' + id; state.targetId = id; state.active = active
    await LocalDataStore.enqueue('favorites', state.id, state, owner)
    return active
    })
  }

  static async artworks(owner: string = LocalDataStore.ownerId()): Promise<UserArtwork[]> {
    const value = await LocalDataStore.read('artworks', owner)
    if (value.length === 0) {
      return []
    }
    try {
      return JSON.parse(value) as UserArtwork[]
    } catch {
      return []
    }
  }

  static async saveArtwork(artwork: UserArtwork): Promise<void> {
    const owner = LocalDataStore.ownerId()
    return LocalDataStore.serial<void>(async (): Promise<void> => {
    const values = await LocalDataStore.artworks(owner)
    artwork.ownerId = owner
    artwork.clientCreatedAt = artwork.createdAt
    artwork.clientUpdatedAt = artwork.updatedAt
    const index = values.findIndex((item: UserArtwork) => item.artworkId === artwork.artworkId)
    if (index >= 0) {
      values[index] = artwork
    } else {
      values.push(artwork)
    }
    await LocalDataStore.write('artworks', JSON.stringify(values), owner)
    LocalDataStore.publishChange(owner)
    artwork.id = artwork.artworkId
    await LocalDataStore.enqueue('artworks', artwork.id, artwork, owner)
    })
  }

  static async gameRecords(owner: string = LocalDataStore.ownerId()): Promise<GameRecord[]> {
    const value = await LocalDataStore.read('gameRecords', owner)
    if (value.length === 0) {
      return []
    }
    try {
      return JSON.parse(value) as GameRecord[]
    } catch {
      return []
    }
  }

  static async saveGameRecord(record: GameRecord): Promise<void> {
    const owner = LocalDataStore.ownerId()
    return LocalDataStore.serial<void>(async (): Promise<void> => {
    const values = await LocalDataStore.gameRecords(owner)
    record.ownerId = owner
    const index = values.findIndex((item: GameRecord) => item.recordId === record.recordId)
    if (index >= 0) values[index] = record
    else values.push(record)
    await LocalDataStore.write('gameRecords', JSON.stringify(values), owner)
    LocalDataStore.publishChange(owner)
    record.id = record.recordId
    await LocalDataStore.enqueue('game-records', record.id, record, owner)
    })
  }

  static async markLearned(articleId: string): Promise<void> {
    const owner = LocalDataStore.ownerId()
    return LocalDataStore.serial<void>(async (): Promise<void> => {
    const value = await LocalDataStore.read('learning', owner)
    const ids = value.length === 0 ? [] : value.split('|')
    if (ids.indexOf(articleId) < 0) {
      ids.push(articleId)
      await LocalDataStore.write('learning', ids.join('|'), owner)
      LocalDataStore.publishChange(owner)
      const state = new LearningState()
      state.id = 'learning-' + articleId; state.articleId = articleId
      await LocalDataStore.enqueue('learning-records', state.id, state, owner)
    }
    })
  }

  static async learningCount(): Promise<number> {
    return (await LocalDataStore.learningIds()).length
  }

  static async learningIds(owner: string = LocalDataStore.ownerId()): Promise<string[]> {
    const value = await LocalDataStore.read('learning', owner)
    return value.length === 0 ? [] : value.split('|')
  }

  static async saveBrowsingProgress(exhibitionId: string, progress: number): Promise<void> {
    const owner = LocalDataStore.ownerId()
    return LocalDataStore.serial<void>(async (): Promise<void> => {
    await LocalDataStore.write(`exhibition_${exhibitionId}`, `${progress}`, owner)
    LocalDataStore.publishChange(owner)
    const state = new BrowsingState()
    state.id = 'browsing-' + exhibitionId; state.exhibitionId = exhibitionId; state.progress = progress
    await LocalDataStore.enqueue('browsing-records', state.id, state, owner)
    })
  }

  static async browsingProgress(exhibitionId: string): Promise<number> {
    const value = Number(await LocalDataStore.read('exhibition_' + exhibitionId))
    return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0
  }

  private static async outbox(owner: string): Promise<SyncJob[]> {
    const raw = await LocalDataStore.read('syncOutbox', owner)
    if (raw.length === 0) return []
    try { return JSON.parse(raw) as SyncJob[] } catch { throw new Error('同步队列损坏，本地记录仍保留') }
  }

  private static async enqueue(module: string, id: string, body: object, owner: string): Promise<void> {
    if (owner === 'zxznh:guest') return
    const jobs = await LocalDataStore.outbox(owner)
    const job = new SyncJob()
    job.id = id; job.module = module; job.payload = JSON.stringify(body)
    const existing = jobs.find((item: SyncJob) => item.module === module && item.id === id)
    job.version = existing === undefined ? 1 : existing.version + 1
    await LocalDataStore.write('syncOutbox', JSON.stringify(jobs.filter((item: SyncJob) => item.module !== module || item.id !== id).concat([job])), owner)
    if (owner === LocalDataStore.ownerId()) void LocalDataStore.synchronize()
  }

  private static sameSession(owner: string, token: string): boolean {
    return owner === LocalDataStore.ownerId() && token === (AppStorage.get<string>('accessToken') ?? '')
  }

  static async synchronize(): Promise<boolean> {
    const owner = LocalDataStore.ownerId()
    const token = AppStorage.get<string>('accessToken') ?? ''
    if (owner === 'zxznh:guest' || token.length === 0 || LocalDataStore.synchronizing) return false
    LocalDataStore.synchronizing = true
    AppStorage.setOrCreate('syncStatus', '正在同步当前账号…')
    try {
      const jobs = await LocalDataStore.serial<SyncJob[]>(() => LocalDataStore.outbox(owner))
      for (const job of jobs) {
        if (!LocalDataStore.sameSession(owner, token)) return false
        const response = await HttpClient.post<EmptyPayload>('/biz/zxznh.xcl.huawei/' + job.module, JSON.parse(job.payload) as Object)
        if (response.code !== 0) throw new Error(response.message)
        if (!LocalDataStore.sameSession(owner, token)) return false
        await LocalDataStore.serial<void>(async (): Promise<void> => {
          const remaining = await LocalDataStore.outbox(owner)
          await LocalDataStore.write('syncOutbox', JSON.stringify(remaining.filter((item: SyncJob) =>
            item.module !== job.module || item.id !== job.id || item.version !== job.version)), owner)
        })
      }
      const data = new PrivateSnapshot()
      if (!LocalDataStore.sameSession(owner, token)) return false
      const favorites = await HttpClient.get<PrivateList<FavoriteState>>('/biz/zxznh.xcl.huawei/favorites')
      if (favorites.code !== 0 || favorites.data === undefined) throw new Error(favorites.message)
      data.favorites = favorites.data.items
      if (!LocalDataStore.sameSession(owner, token)) return false
      const works = await HttpClient.get<PrivateList<UserArtwork>>('/biz/zxznh.xcl.huawei/artworks')
      if (works.code !== 0 || works.data === undefined) throw new Error(works.message)
      data.artworks = works.data.items
      if (!LocalDataStore.sameSession(owner, token)) return false
      const games = await HttpClient.get<PrivateList<GameRecord>>('/biz/zxznh.xcl.huawei/game-records')
      if (games.code !== 0 || games.data === undefined) throw new Error(games.message)
      data.games = games.data.items
      if (!LocalDataStore.sameSession(owner, token)) return false
      const learning = await HttpClient.get<PrivateList<LearningState>>('/biz/zxznh.xcl.huawei/learning-records')
      if (learning.code !== 0 || learning.data === undefined) throw new Error(learning.message)
      data.learning = learning.data.items
      if (!LocalDataStore.sameSession(owner, token)) return false
      const browsing = await HttpClient.get<PrivateList<BrowsingState>>('/biz/zxznh.xcl.huawei/browsing-records')
      if (browsing.code !== 0 || browsing.data === undefined) throw new Error(browsing.message)
      data.browsing = browsing.data.items
      return await LocalDataStore.serial<boolean>(async (): Promise<boolean> => {
        if (!LocalDataStore.sameSession(owner, token)) return false
        if ((await LocalDataStore.outbox(owner)).length > 0) {
          AppStorage.setOrCreate('syncStatus', '有新修改待同步，请再次同步')
          return false
        }
        const localWorks = await LocalDataStore.artworks(owner)
        data.artworks.forEach((work: UserArtwork) => {
          const local = localWorks.find((item: UserArtwork) => item.artworkId === work.artworkId)
          work.ownerId = owner
          work.createdAt = work.clientCreatedAt > 0 ? work.clientCreatedAt : Date.now()
          work.updatedAt = work.clientUpdatedAt > 0 ? work.clientUpdatedAt : work.createdAt
          work.thumbnailPath = local === undefined ? '' : local.thumbnailPath
          work.exportPath = local === undefined ? '' : local.exportPath
        })
        for (const local of localWorks) {
          if (!data.artworks.some((work: UserArtwork) => work.artworkId === local.artworkId)) {
            data.artworks.push(local)
            local.id = local.artworkId
            await LocalDataStore.enqueue('artworks', local.id, local, owner)
          }
        }
        const localGames = await LocalDataStore.gameRecords(owner)
        for (const local of localGames) {
          if (!data.games.some((record: GameRecord) => record.recordId === local.recordId)) {
            data.games.push(local)
            local.id = local.recordId
            await LocalDataStore.enqueue('game-records', local.id, local, owner)
          }
        }
        const localFavorites = await LocalDataStore.favorites(owner)
        for (const id of localFavorites) {
          if (!data.favorites.some((item: FavoriteState) => item.targetId === id)) {
            const state = new FavoriteState()
            state.id = 'favorite-' + id; state.targetId = id; state.active = true
            data.favorites.push(state)
            await LocalDataStore.enqueue('favorites', state.id, state, owner)
          }
        }
        const localLearning = await LocalDataStore.read('learning', owner)
        for (const id of localLearning.split('|').filter((value: string) => value.length > 0)) {
          if (!data.learning.some((item: LearningState) => item.articleId === id)) {
            const state = new LearningState()
            state.id = 'learning-' + id; state.articleId = id
            data.learning.push(state)
            await LocalDataStore.enqueue('learning-records', state.id, state, owner)
          }
        }
        await LocalDataStore.write('favorites', data.favorites.filter((item: FavoriteState) => item.active).map((item: FavoriteState) => item.targetId).join('|'), owner)
        await LocalDataStore.write('artworks', JSON.stringify(data.artworks), owner)
        await LocalDataStore.write('gameRecords', JSON.stringify(data.games), owner)
        await LocalDataStore.write('learning', data.learning.map((item: LearningState) => item.articleId).join('|'), owner)
        for (const item of data.browsing) await LocalDataStore.write('exhibition_' + item.exhibitionId, String(item.progress), owner)
        LocalDataStore.publishChange(owner)
        AppStorage.setOrCreate('syncStatus', (await LocalDataStore.outbox(owner)).length === 0 ? '同步完成，当前账号记录已恢复' : '云端记录已恢复，旧本地记录已加入同步队列')
        return true
      })
    } catch {
      if (LocalDataStore.sameSession(owner, token)) AppStorage.setOrCreate('syncStatus', '同步未完成，本地记录和重试队列已保留')
      return false
    } finally {
      LocalDataStore.synchronizing = false
    }
  }
}
