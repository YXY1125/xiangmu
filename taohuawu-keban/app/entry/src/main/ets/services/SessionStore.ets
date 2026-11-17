import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'SessionStore'
const STORE_NAME = 'app_session'
const KEY_TOKEN = 'accessToken'
const KEY_USER = 'currentUsername'
const KEY_SUBJECT = 'currentUserId'
const KEY_PRIVACY = 'privacyAccepted'
const KEY_ENVELOPE = 'trustedSessionV1'

class SessionEnvelope {
  token: string = ''
  username: string = ''
  userId: string = ''
}

/**
 * 可靠会话持久化：preferences + flush。
 * 勿仅依赖 PersistentStorage（杀进程易丢）。
 */
export class SessionStore {
  private static pref: preferences.Preferences | null = null
  private static ready: boolean = false
  private static writes: Promise<void> = Promise.resolve()
  private static enqueue(operation: () => Promise<void>): Promise<void> {
    const task = SessionStore.writes.catch(() => {}).then(operation)
    SessionStore.writes = task
    return task
  }

  static isReady(): boolean {
    return SessionStore.ready
  }

  static revision(): number { return AppStorage.get<number>('sessionRevision') ?? 0 }
  static userId(): string { return AppStorage.get<string>(KEY_SUBJECT) ?? '' }
  private static changed(): void { AppStorage.setOrCreate('sessionRevision', SessionStore.revision() + 1) }

  static async init(context: common.UIAbilityContext): Promise<void> {
    try {
      SessionStore.pref = await preferences.getPreferences(context, STORE_NAME)
      const encoded = await SessionStore.pref.get(KEY_ENVELOPE, '')
      let envelope = new SessionEnvelope()
      if (typeof encoded === 'string' && encoded.length > 0) envelope = JSON.parse(encoded) as SessionEnvelope
      const privacyValue = await SessionStore.pref.get(KEY_PRIVACY, false)
      const subject: string = typeof envelope.userId === 'string' ? envelope.userId : ''
      const token: string = typeof envelope.token === 'string' && subject.length > 0 ? envelope.token : ''
      const username: string = typeof envelope.username === 'string' ? envelope.username : ''
      const privacy: boolean = privacyValue === true
      AppStorage.setOrCreate(KEY_TOKEN, token)
      AppStorage.setOrCreate(KEY_USER, username)
      AppStorage.setOrCreate(KEY_SUBJECT, subject)
      SessionStore.changed()
      AppStorage.setOrCreate(KEY_PRIVACY, privacy)
      SessionStore.ready = true
      hilog.info(0x0000, TAG, 'session restored, hasToken=%{public}s', `${token.length > 0}`)
    } catch {
      AppStorage.setOrCreate(KEY_TOKEN, '')
      AppStorage.setOrCreate(KEY_USER, '')
      AppStorage.setOrCreate(KEY_SUBJECT, '')
      SessionStore.changed()
      AppStorage.setOrCreate(KEY_PRIVACY, false)
      SessionStore.ready = true
      hilog.error(0x0000, TAG, 'session init failed, using empty')
    }
  }

  static async saveSession(token: string, username: string, userId: string): Promise<void> {
    const revision = SessionStore.revision()
    const envelope = new SessionEnvelope(); envelope.token = token; envelope.username = username; envelope.userId = userId
    await SessionStore.enqueue(async () => {
      if (SessionStore.pref === null || revision !== SessionStore.revision()) throw new Error('Session changed')
      await SessionStore.pref.put(KEY_ENVELOPE, JSON.stringify(envelope))
      await SessionStore.pref.flush()
      if (revision !== SessionStore.revision()) throw new Error('Session changed')
      AppStorage.setOrCreate(KEY_TOKEN, token)
      AppStorage.setOrCreate(KEY_USER, username)
      AppStorage.setOrCreate(KEY_SUBJECT, userId)
      AppStorage.setOrCreate('trackingGranted', false)
      SessionStore.changed()
    })
  }

  static async clearSession(): Promise<void> {
    AppStorage.setOrCreate(KEY_TOKEN, '')
    AppStorage.setOrCreate(KEY_USER, '')
    AppStorage.setOrCreate(KEY_SUBJECT, '')
    AppStorage.setOrCreate('trackingGranted', false)
    SessionStore.changed()
    await SessionStore.enqueue(async () => {
      if (SessionStore.pref === null) throw new Error('Session preferences unavailable')
      await SessionStore.pref.put(KEY_ENVELOPE, '')
      await SessionStore.pref.flush()
    })
  }

  static async savePrivacyAccepted(accepted: boolean): Promise<void> {
    await SessionStore.putBool(KEY_PRIVACY, accepted)
    AppStorage.setOrCreate(KEY_PRIVACY, accepted)
  }

  private static async putBool(key: string, value: boolean): Promise<void> {
    if (SessionStore.pref === null) {
      throw new Error('Session preferences unavailable')
    }
    await SessionStore.pref.put(key, value)
    await SessionStore.pref.flush()
  }
}
