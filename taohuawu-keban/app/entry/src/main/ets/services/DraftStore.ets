import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { Creation } from '../models/ArtModels'
import { ArtService } from './ArtService'
import { HttpClient } from './HttpClient'
import { SessionStore } from './SessionStore'

/** Private recovery copy only. It never reports a cloud save as successful. */
export class DraftStore {
  private static store: preferences.Preferences | null = null
  static async init(context: common.UIAbilityContext): Promise<void> {
    DraftStore.store = await preferences.getPreferences(context, 'thwkb_private_drafts')
  }
  private static ownerKey(): string {
    const subject = SessionStore.userId()
    if (subject.length === 0 || HttpClient.getToken().length === 0) throw new Error('请先登录')
    return `${HttpClient.tenantId()}:${subject}:recovery`
  }
  static async save(creation: Creation): Promise<void> {
    const key = DraftStore.ownerKey()
    if (DraftStore.store === null) throw new Error('本地草稿存储尚未就绪')
    await DraftStore.store.put(key, JSON.stringify(creation))
    await DraftStore.store.flush()
  }
  static async restore(): Promise<Creation | undefined> {
    const key = DraftStore.ownerKey()
    const revision = SessionStore.revision()
    if (DraftStore.store === null) throw new Error('本地草稿存储尚未就绪')
    const raw = await DraftStore.store.get(key, '')
    if (revision !== SessionStore.revision()) return undefined
    if (typeof raw !== 'string' || raw.length === 0) return undefined
    return ArtService.creation(JSON.parse(raw) as Creation)
  }
  static async removeCurrent(): Promise<void> {
    const key = DraftStore.ownerKey()
    if (DraftStore.store === null) throw new Error('本地存储尚未就绪')
    await DraftStore.store.delete(key)
    await DraftStore.store.flush()
  }
}
