import { EmptyPayload } from '../models/ApiModels'
import { HttpClient } from './HttpClient'
import { SessionStore } from './SessionStore'
import { DraftStore } from './DraftStore'

const KEY_PRIVACY = 'privacyAccepted'

export class PrivacyService {
  static isAccepted(): boolean {
    return AppStorage.get<boolean>(KEY_PRIVACY) === true
  }

  static accept(): void {
    AppStorage.setOrCreate(KEY_PRIVACY, true)
  }

  /** 登录/注册勾选同意后持久化 */
  static async acceptAndPersist(): Promise<void> {
    await SessionStore.savePrivacyAccepted(true)
  }

  static async deleteAccount(): Promise<boolean> {
    const revision = SessionStore.revision()
    const res = await HttpClient.delete<EmptyPayload>('/privacy/account', new EmptyPayload())
    if (res.code === 0 && revision === SessionStore.revision()) {
      try { await DraftStore.removeCurrent() } finally { await SessionStore.clearSession() }
    }
    return res.code === 0
  }
}
