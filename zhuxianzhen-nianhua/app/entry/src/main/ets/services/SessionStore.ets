import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'SessionStore'
const STORE_NAME = 'app_session'
const KEY_TOKEN = 'accessToken'
const KEY_USER = 'currentUsername'
const KEY_USER_ID = 'currentUserId'
const KEY_PRIVACY = 'privacyAccepted'

/**
 * 可靠会话持久化：preferences + flush。
 * 勿仅依赖 PersistentStorage（杀进程易丢）。
 */
export class SessionStore {
  private static pref: preferences.Preferences | null = null
  private static ready: boolean = false

  static isReady(): boolean {
    return SessionStore.ready
  }

  static async init(context: common.UIAbilityContext): Promise<void> {
    try {
      SessionStore.pref = await preferences.getPreferences(context, STORE_NAME)
      const tokenValue = await SessionStore.pref.get(KEY_TOKEN, '')
      const userValue = await SessionStore.pref.get(KEY_USER, '')
      const userIdValue = await SessionStore.pref.get(KEY_USER_ID, '')
      const privacyValue = await SessionStore.pref.get(KEY_PRIVACY, false)
      const userId: string = typeof userIdValue === 'string' ? userIdValue : ''
      const token: string = userId.length > 0 && typeof tokenValue === 'string' ? tokenValue : ''
      const username: string = typeof userValue === 'string' ? userValue : ''
      const privacy: boolean = privacyValue === true
      AppStorage.setOrCreate(KEY_TOKEN, token)
      AppStorage.setOrCreate(KEY_USER, username)
      AppStorage.setOrCreate(KEY_USER_ID, userId)
      AppStorage.setOrCreate(KEY_PRIVACY, privacy)
      SessionStore.ready = true
      hilog.info(0x0000, TAG, 'session restored, hasToken=%{public}s', `${token.length > 0}`)
    } catch {
      AppStorage.setOrCreate(KEY_TOKEN, '')
      AppStorage.setOrCreate(KEY_USER, '')
      AppStorage.setOrCreate(KEY_USER_ID, '')
      AppStorage.setOrCreate(KEY_PRIVACY, false)
      SessionStore.ready = true
      hilog.error(0x0000, TAG, 'session init failed, using empty')
    }
  }

  static async saveSession(token: string, username: string, userId: string): Promise<void> {
    if (SessionStore.pref === null) throw new Error('会话存储未就绪，请重试')
    try {
      await SessionStore.pref.put(KEY_TOKEN, token)
      await SessionStore.pref.put(KEY_USER, username)
      await SessionStore.pref.put(KEY_USER_ID, userId)
      await SessionStore.pref.flush()
    } catch {
      throw new Error('会话保存失败，请检查存储空间')
    }
    AppStorage.setOrCreate(KEY_TOKEN, token)
    AppStorage.setOrCreate(KEY_USER, username)
    AppStorage.setOrCreate(KEY_USER_ID, userId)
    AppStorage.setOrCreate('sessionExpired', false)
    AppStorage.setOrCreate('reopenArtwork', '')
    AppStorage.setOrCreate('requestedExhibition', '')
    AppStorage.setOrCreate('syncStatus', '')
    AppStorage.setOrCreate('lastSyncError', '')
  }

  static async clearSession(): Promise<void> {
    AppStorage.setOrCreate('reopenArtwork', '')
    AppStorage.setOrCreate('requestedExhibition', '')
    AppStorage.setOrCreate('syncStatus', '')
    AppStorage.setOrCreate('lastSyncError', '')
    AppStorage.setOrCreate('tabBarHidden', false)
    AppStorage.setOrCreate(KEY_TOKEN, '')
    AppStorage.setOrCreate(KEY_USER, '')
    AppStorage.setOrCreate(KEY_USER_ID, '')
    await SessionStore.putString(KEY_TOKEN, '')
    await SessionStore.putString(KEY_USER, '')
    await SessionStore.putString(KEY_USER_ID, '')
  }

  static async savePrivacyAccepted(accepted: boolean): Promise<void> {
    AppStorage.setOrCreate(KEY_PRIVACY, accepted)
    await SessionStore.putBool(KEY_PRIVACY, accepted)
  }

  private static async putString(key: string, value: string): Promise<void> {
    if (SessionStore.pref === null) {
      return
    }
    await SessionStore.pref.put(key, value)
    await SessionStore.pref.flush()
  }

  private static async putBool(key: string, value: boolean): Promise<void> {
    if (SessionStore.pref === null) {
      return
    }
    await SessionStore.pref.put(key, value)
    await SessionStore.pref.flush()
  }
}
