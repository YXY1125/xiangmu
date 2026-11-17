import { UserProfile } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { AuthService } from '../services/AuthService'
import { SessionStore } from '../services/SessionStore'
import { PrivacyService } from '../services/PrivacyService'
import { LegalDocKind, LegalDocOverlay } from '../components/legal/LegalDocOverlay'
import { ArtImage } from '../components/ArtImage'
import { LoadState } from '../components/LoadState'
import { ExportService } from '../services/ExportService'
import { common } from '@kit.AbilityKit'

@Component
export struct MinePage {
  @State profile: UserProfile = new UserProfile()
  @State loading: boolean = false
  @State error: string = ''
  @State profileError: string = ''
  @State settings: boolean = false
  @State editing: boolean = false
  @State busy: boolean = false
  @State legal: string = ''
  @State legalKind: LegalDocKind = 'privacy'
  @Prop @Watch('requestBack') backRequest: number = 0
  @StorageLink('sessionRevision') @Watch('reload') revision: number = 0
  @StorageLink('artDataRevision') @Watch('reload') dataRevision: number = 0
  private requestId: number = 0
  onOpen: (kind: string, id: string) => void = () => {}
  onLogin: () => void = () => {}
  onLogout: () => void = () => {}
  onBackRoot: () => void = () => {}
  aboutToAppear(): void { this.reload() }
  private requestBack(): void {
    if (this.legal) this.legal = ''
    else if (this.editing) { this.editing = false; this.reload() }
    else if (this.settings) this.settings = false
    else this.onBackRoot()
  }
  private clearExportCache(): void {
    AlertDialog.show({ title: '清除分享缓存', message: '请先结束正在进行的分享。仅删除本应用的临时分享PNG，不删除作品、草稿、账号或已经导出的文件。',
      primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '清除缓存', action: () => {
        this.busy = true
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext
        ExportService.clearTemporaryExports(context).then((count: number) => { this.error = `已清除 ${count} 个临时分享文件` })
          .catch(() => { this.error = '缓存清理未完成，请重试；作品与草稿未被删除' }).finally(() => { this.busy = false })
      } } })
  }
  private async reload(): Promise<void> {
    const request = ++this.requestId; const session = SessionStore.revision()
    this.profile = new UserProfile(); this.profileError = ''
    if (!AuthService.isLoggedIn()) { this.loading = false; return }
    this.loading = true
    try { const value = await ArtService.personalProfile(); if (request === this.requestId && session === SessionStore.revision()) this.profile = value }
    catch (error) { if (request === this.requestId && session === SessionStore.revision()) this.profileError = (error as ArtError).message || '个人资料读取失败' }
    finally { if (request === this.requestId) this.loading = false }
  }
  private async saveProfile(): Promise<void> {
    this.busy = true; this.error = ''
    try { await ArtService.updateProfile(this.profile); this.editing = false; await this.reload() }
    catch (error) { this.error = (error as ArtError).message || '资料保存失败' }
    finally { this.busy = false }
  }
  private logout(): void {
    AlertDialog.show({ title: '退出当前账号', message: '作品和草稿仍保留在当前账号中。', primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '退出登录', action: () => { AuthService.logout().then(() => this.onLogout()).catch(() => { this.error = '会话清除失败，请重试' }) } } })
  }
  private deleteAccount(): void {
    AlertDialog.show({ title: '确认注销账号', message: '注销后账号将不可使用，个人信息与业务记录按隐私政策处理。此操作不可撤回。',
      primaryButton: { value: '保留账号', action: () => {} }, secondaryButton: { value: '确认注销', action: () => {
        this.busy = true
        PrivacyService.deleteAccount().then((ok: boolean) => { this.busy = false; if (ok) this.onLogout(); else this.error = '注销未完成，请重试' })
          .catch(() => { this.busy = false; this.error = '注销请求失败，请重试' })
      } } })
  }
  @Builder row(title: string, kind: string) {
    Row() {
      Text(title).fontSize(16).fontColor('#493B3A').layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor(['#8B716B'])
    }.width('100%').height(54).border({ width: { bottom: .5 }, color: '#EADBD1' }).onClick(() => this.onOpen(kind, ''))
  }
  build() {
    Stack() {
      Scroll() {
        Column({ space: 16 }) {
          Row() {
            Text(this.settings ? '设置与隐私' : '个人艺术空间').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#493B3A').layoutWeight(1)
            Button(this.settings ? '返回' : '设置').backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => { this.settings = !this.settings })
          }.width('100%')
          if (this.error) Text(this.error).fontSize(14).fontColor('#A93635').width('100%')
          if (this.settings) {
            Button('用户协议').width('100%').backgroundColor('#FFFFFF').fontColor('#493B3A').onClick(() => { this.legalKind = 'agreement'; this.legal = 'agreement' })
            Button('隐私政策').width('100%').backgroundColor('#FFFFFF').fontColor('#493B3A').onClick(() => { this.legalKind = 'privacy'; this.legal = 'privacy' })
            Button('个人信息收集清单').width('100%').backgroundColor('#FFFFFF').fontColor('#493B3A').onClick(() => { this.legalKind = 'personalInfo'; this.legal = 'personalInfo' })
            Button('第三方及系统能力清单').width('100%').backgroundColor('#FFFFFF').fontColor('#493B3A').onClick(() => { this.legalKind = 'thirdParty'; this.legal = 'thirdParty' })
            Button('清除分享缓存').width('100%').backgroundColor('#F9EDE2').fontColor('#493B3A').enabled(!this.busy).onClick(() => this.clearExportCache())
            Text('开发主体：黑龙江省众富信息科技有限公司').fontSize(12).fontColor('#76615E').width('100%')
            Text('华为开发者账号名称：黑龙江省众富信息科技有限公司').fontSize(12).fontColor('#76615E').width('100%')
            if (AuthService.isLoggedIn()) {
              Button('退出登录').width('100%').backgroundColor('#FBE0E7').fontColor('#A93635').enabled(!this.busy).onClick(() => this.logout())
              Button('注销账号').width('100%').backgroundColor('#A93635').enabled(!this.busy).onClick(() => this.deleteAccount())
            }
          } else if (!AuthService.isLoggedIn()) {
            LoadState({ emptyText: '登录后保存自己的作品、草稿与收藏', emptyImage: 'empty_favorites' })
            Button('登录 / 注册').id('mine-login').width('100%').backgroundColor('#A93635').onClick(() => this.onLogin())
          } else if (this.loading || this.profileError) LoadState({ loading: this.loading, message: this.profileError, onRetry: () => this.reload() })
          else {
            Row({ space: 16 }) {
              ArtImage({ imageKey: this.profile.avatarKey || 'ip_taoyao', fit: ImageFit.Contain }).width(82).height(82).backgroundColor('#FBE0E7').borderRadius(24)
              Column({ space: 6 }) {
                Text(this.profile.nickname || AuthService.currentUsername()).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#493B3A')
                Text(this.profile.bio || '把今天的灵感，印成自己的小世界。').fontSize(13).fontColor('#76615E')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%').margin({ top: 16, bottom: 8 })
            Button(this.editing ? '取消编辑' : '编辑个人资料').backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => { this.editing = !this.editing })
            if (this.editing) {
              TextInput({ text: this.profile.nickname, placeholder: '昵称' }).maxLength(30).onChange((value: string) => { this.profile.nickname = value })
              TextInput({ text: this.profile.bio, placeholder: '简介' }).maxLength(160).onChange((value: string) => { this.profile.bio = value })
              Row({ space: 8 }) {
                ForEach(['ip_taoyao', 'ip_tuantuan_rabbit', 'ip_jilin_qilin', 'ip_afu_doll', 'ip_feili_koi', 'ip_ruiling_flower'], (key: string) => {
                  ArtImage({ imageKey: key, fit: ImageFit.Contain }).width(42).height(48).border({ width: this.profile.avatarKey === key ? 2 : 0, color: '#A93635' })
                    .onClick(() => { const p = new UserProfile(); p.userId = this.profile.userId; p.nickname = this.profile.nickname; p.bio = this.profile.bio; p.avatarKey = key; this.profile = p })
                })
              }
              Button('保存资料').enabled(!this.busy).backgroundColor('#A93635').onClick(() => this.saveProfile())
            }
            Row({ space: 12 }) {
              Column({ space: 4 }) { Text(`${this.profile.workCount}`).id('mine-work-count').fontSize(24).fontWeight(FontWeight.Bold); Text('作品').fontSize(12) }.id('mine-open-works').layoutWeight(1).onClick(() => this.onOpen('artworks', ''))
              Column({ space: 4 }) { Text(`${this.profile.draftCount}`).id('mine-draft-count').fontSize(24).fontWeight(FontWeight.Bold); Text('草稿').fontSize(12) }.id('mine-open-drafts').layoutWeight(1).onClick(() => this.onOpen('creations', ''))
              Column({ space: 4 }) { Text(`${this.profile.favoriteCount}`).id('mine-favorite-count').fontSize(24).fontWeight(FontWeight.Bold); Text('收藏').fontSize(12) }.layoutWeight(1).onClick(() => this.onOpen('favorites', ''))
            }.width('100%').padding(20).backgroundColor('#FBE0E7').borderRadius(20)
            this.row('我的作品', 'artworks')
            this.row('作品发布版本', 'versions')
            this.row('发布审核记录', 'publications')
            this.row('我的草稿', 'creations')
            this.row('我的收藏', 'favorites')
            this.row('我的喜欢', 'likes')
            this.row('最近浏览', 'history')
            this.row('消息通知', 'notifications')
            this.row('意见反馈', 'feedback')
          }
        }.width('100%').padding(20)
      }.id('mine-scroll').width('100%').height('100%').align(Alignment.TopStart).edgeEffect(EdgeEffect.Spring)
      if (this.legal) LegalDocOverlay({ kind: this.legalKind, onClose: () => { this.legal = '' } })
    }.width('100%').height('100%').backgroundColor('#FFF8F0')
  }
}
