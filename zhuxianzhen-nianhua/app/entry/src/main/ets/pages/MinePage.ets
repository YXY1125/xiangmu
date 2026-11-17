import { Theme } from '../components/design-system/Theme'
import { AuthService } from '../services/AuthService'
import { LocalDataStore } from '../services/LocalDataStore'
import { GameRecord, UserArtwork, CharacterProfile, CultureArticle, Exhibition, MySpaceSnapshot } from '../models/CultureModels'
import { LegalDocKind, LegalDocOverlay } from '../components/legal/LegalDocOverlay'
import { CultureCatalog } from '../data/CultureCatalog'
import { ContentService } from '../services/ContentService'
import { AssetResolver } from '../utils/AssetResolver'
import { CharacterDetail } from '../components/culture/CharacterDetail'
import { ArticleDetail } from '../components/culture/ArticleDetail'
import { HttpClient } from '../services/HttpClient'
import { EmptyPayload } from '../models/ApiModels'
import { BackService } from '../services/BackService'

interface StatBinding { value: string; label: string }
interface MenuBinding { title: string; desc: string; target: string }
interface InfoBinding { title: string; desc: string }
interface ContentBinding { title: string; media: string; description: string; onTap: () => void }

@Component
export struct MinePage {
  @Prop appName: string = '朱仙镇年画'
  @StorageLink('accessToken') accessToken: string = ''
  @StorageLink('currentUsername') currentUsername: string = ''
  @StorageLink('syncStatus') syncStatus: string = ''
  @StorageLink('businessDataRevision') @Watch('onBusinessDataChanged') businessDataRevision: number = 0
  @StorageLink('currentUserId') @Watch('onOwnerChanged') currentUserId: string = ''
  @State syncing: boolean = false
  private backId: number = 0
  private visible: boolean = false
  private reloadVersion: number = 0
  @State statisticsMessage: string = ''
  @State favorites: number = 0
  @State artworks: UserArtwork[] = []
  @State records: GameRecord[] = []
  @State learned: number = 0
  @State panel: string = ''
  @State legalKind: LegalDocKind = 'privacy'
  @State showLegal: boolean = false
  @State favoriteIds: string[] = []
  @State learnedIds: string[] = []
  @State characters: CharacterProfile[] = CultureCatalog.characters()
  @State articles: CultureArticle[] = CultureCatalog.articles()
  @State exhibitions: Exhibition[] = CultureCatalog.exhibitions()
  @State selectedCharacter: CharacterProfile | null = null
  @State selectedArticle: CultureArticle | null = null
  @State accountMessage: string = ''
  onOpenLogin: () => void = () => {}
  onLogout: () => void = () => {}
  onRequireAuth: () => void = () => {}
  onOpenCreate: () => void = () => {}
  onOpenGallery: () => void = () => {}

  aboutToAppear(): void {
    this.visible = true
    this.backId = BackService.register(() => {
      if (this.panel.length > 0) { this.panel = ''; AppStorage.setOrCreate('tabBarHidden', false); return true }
      return false
    })
    this.reload()
    ContentService.characters().then((items: CharacterProfile[]) => { if (items.length > 0) this.characters = items })
    ContentService.articles().then((items: CultureArticle[]) => { if (items.length > 0) this.articles = items })
    ContentService.exhibitions().then((items: Exhibition[]) => { if (items.length > 0) this.exhibitions = items })
  }

  aboutToDisappear(): void {
    this.visible = false
    this.reloadVersion++
    BackService.remove(this.backId)
  }

  private reload(): void {
    if (!this.visible) return
    const version = ++this.reloadVersion
    const owner = LocalDataStore.ownerId()
    LocalDataStore.mySpaceSnapshot().then((snapshot: MySpaceSnapshot) => {
      if (!this.visible || version !== this.reloadVersion || owner !== LocalDataStore.ownerId() || snapshot.ownerId !== owner) return
      this.favoriteIds = snapshot.favoriteIds
      this.favorites = snapshot.favoriteIds.length
      this.artworks = snapshot.artworks
      this.records = snapshot.gameRecords
      this.learnedIds = snapshot.learningIds
      this.learned = snapshot.learningIds.length
      this.statisticsMessage = ''
    }).catch(() => {
      if (this.visible && version === this.reloadVersion && owner === LocalDataStore.ownerId()) {
        this.statisticsMessage = '个人记录读取失败，点击重试；已保存数据不会被清除'
      }
    })
  }

  private onBusinessDataChanged(): void { this.reload() }

  private onOwnerChanged(): void {
    this.reloadVersion++
    this.favoriteIds = []; this.favorites = 0; this.artworks = []; this.records = []
    this.learnedIds = []; this.learned = 0; this.statisticsMessage = ''
    this.selectedCharacter = null; this.selectedArticle = null; this.panel = ''
    this.reload()
  }

  build() {
    Stack() {
      Column() {
        Text('我的').fontSize(30).fontWeight(FontWeight.Bold).width('100%').padding({ left: 16, right: 16, top: 16, bottom: 12 })
        Scroll() {
          Column({ space: 16 }) {
            Row({ space: 14 }) {
              Image($r('app.media.app_icon')).width(52).height(52).borderRadius(17)
              Column({ space: 6 }) {
                Text(this.accessToken.length > 0 ? this.currentUsername : '年画体验者')
                  .fontSize(18).fontWeight(FontWeight.Bold).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.accessToken.length > 0 ? '已登录 · 当前用户数据独立存储' : '游客模式 · 核心创作与游戏均可使用')
                  .fontSize(11).fontColor(Theme.colors().textSecondary)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Button(this.accessToken.length > 0 ? '退出' : '登录').height(38).fontSize(12)
                .backgroundColor(Theme.colors().brandPrimary).fontColor('#FFFFFF').onClick(() => {
                  if (this.accessToken.length > 0) {
                    AlertDialog.show({ title: '退出当前账号？', message: '账号记录会保留，退出后切换为游客空间。',
                      primaryButton: { value: '退出', action: () => { AuthService.logout().then(() => this.onLogout()).catch(() => this.accountMessage = '退出保存失败，请重试') } },
                      secondaryButton: { value: '取消', action: () => {} } })
                  } else this.onOpenLogin()
                })
            }.padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(22).width('100%')
            if (this.accessToken.length > 0) {
              Row({ space: 8 }) {
                Text(this.syncStatus.length > 0 ? this.syncStatus : '当前账号独立同步，游客作品不会自动转入账号')
                  .fontSize(11).fontColor(Theme.colors().textSecondary).layoutWeight(1)
                Button(this.syncing ? '同步中' : '同步记录').height(40).fontSize(12).enabled(!this.syncing)
                  .onClick(() => {
                    this.syncing = true
                    LocalDataStore.synchronize().then(() => { this.syncing = false; this.reload() })
                      .catch(() => { this.syncing = false; this.accountMessage = '同步失败，本地记录保留' })
                  })
              }.width('100%')
            }
            Row() {
              this.Stat({ value: `${this.favorites}`, label: '收藏' })
              this.Stat({ value: `${this.artworks.length}`, label: '创作' })
              this.Stat({ value: `${this.records.length}`, label: '游戏' })
              this.Stat({ value: `${this.learned}`, label: '学习' })
            }.padding({ top: 14, bottom: 14 }).backgroundColor('#F0E1C6').borderRadius(20).width('100%')
            if (this.statisticsMessage.length > 0) {
              Text(this.statisticsMessage).fontSize(12).fontColor(Theme.colors().danger).width('100%')
                .onClick(() => this.reload())
            }
            Text('个人空间').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
            this.Menu({ title: '我的收藏', desc: `${this.favorites} 项已收藏`, target: 'favorites' })
            this.Menu({ title: '我的角色图鉴', desc: '12 位原创角色', target: 'characters' })
            this.Menu({ title: '我的创作', desc: `${this.artworks.length} 件可再次编辑的作品`, target: 'artworks' })
            this.Menu({ title: '我的草稿', desc: '编辑中的作品自动保留配置', target: 'drafts' })
            this.Menu({ title: '我的游戏记录', desc: `${this.records.length} 条成绩`, target: 'records' })
            this.Menu({ title: '我的学习记录', desc: `${this.learned} 篇已阅读`, target: 'learning' })
            this.Menu({ title: '我的成就', desc: this.records.length >= 5 ? '已获得：乐园探索家' : '完成 5 局游戏解锁', target: 'achievements' })
            Text('应用与支持').fontSize(20).fontWeight(FontWeight.Bold).width('100%').margin({ top: 8 })
            this.Menu({ title: '设置', desc: '数据边界、外观与权限说明', target: 'settings' })
            this.Menu({ title: '用户协议', desc: '查看当前草案', target: 'agreement' })
            this.Menu({ title: '隐私政策', desc: '查看当前草案', target: 'privacy' })
            this.Menu({ title: '关于应用', desc: '版本 1.0.0 · 传统文化数字创意体验平台', target: 'about' })
          }.padding({ left: 16, right: 16, bottom: 30 }).width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
      if (this.panel.length > 0) this.Panel()
      if (this.showLegal) {
        LegalDocOverlay({ kind: this.legalKind, onClose: () => { this.showLegal = false; AppStorage.setOrCreate('tabBarHidden', false) } }).width('100%').height('100%')
      }
      if (this.selectedCharacter !== null) {
        CharacterDetail({ profile: this.selectedCharacter, onBack: () => { this.selectedCharacter = null; this.reload() } })
      }
      if (this.selectedArticle !== null) {
        ArticleDetail({ article: this.selectedArticle, onBack: () => { this.selectedArticle = null; this.reload() } })
      }
    }.width('100%').height('100%')
  }

  @Builder
  Stat(data: StatBinding) {
    Column({ space: 4 }) {
      Text(data.value).fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.colors().brandPrimary).id('mine-stat-' + data.label)
      Text(data.label).fontSize(11).fontColor(Theme.colors().textSecondary)
    }.layoutWeight(1)
  }

  @Builder
  Menu(data: MenuBinding) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(data.title).fontSize(16).fontWeight(FontWeight.Medium)
        Text(data.desc).fontSize(11).fontColor(Theme.colors().textSecondary).maxLines(1)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(24).fontColor(Theme.colors().brandPrimary)
    }.padding(14).backgroundColor(Theme.colors().surfaceCard).borderRadius(17).width('100%').onClick(() => {
      if (data.target === 'agreement' || data.target === 'privacy') {
        this.legalKind = data.target === 'agreement' ? 'agreement' : 'privacy'
        this.showLegal = true
      } else this.panel = data.target
      AppStorage.setOrCreate('tabBarHidden', true)
    })
  }

  @Builder
  Panel() {
    Column() {
      Row() {
        Button('‹').fontSize(30).width(44).height(44).backgroundColor('transparent').fontColor(Theme.colors().textPrimary)
          .onClick(() => { this.panel = ''; AppStorage.setOrCreate('tabBarHidden', false) })
        Text(this.panelTitle()).fontSize(21).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(44)
      }.padding({ left: 10, right: 10, top: 10 }).width('100%')
      Scroll() {
        Column({ space: 12 }) {
          if (this.panel === 'records') {
            if (this.records.length === 0) this.Empty('还没有游戏记录')
            ForEach(this.records.slice().reverse(), (item: GameRecord) => {
              this.Info({ title: `${item.gameId} · ${item.score} 分`, desc: `用时 ${item.durationSeconds} 秒 · ${item.detail}` })
            }, (item: GameRecord) => item.recordId)
          } else if (this.panel === 'artworks' || this.panel === 'drafts') {
            if (this.artworks.length === 0) this.Empty('还没有保存的作品')
            ForEach(this.artworks, (item: UserArtwork) => {
              Column() {
                this.Info({ title: item.title, desc: `${item.layers.length + item.textObjects.length} 个图层 · 点击继续编辑` })
              }.onClick(() => { AppStorage.setOrCreate('reopenArtwork', JSON.stringify(item)); this.onOpenCreate() })
            }, (item: UserArtwork) => item.artworkId)
          } else if (this.panel === 'about') {
            Image($r('app.media.app_icon')).width(96).height(96).borderRadius(28)
            Text('朱仙镇年画').fontSize(26).fontWeight(FontWeight.Bold)
            Text('由黑龙江省众富信息科技有限公司开发。以朱仙镇木版年画为文化根基，通过原创角色、数字创作与互动游戏传播传统文化。')
              .fontSize(14).lineHeight(23).fontColor(Theme.colors().textSecondary)
            Text('现代角色与故事均为原创改编，不将生成图像标注为历史文物。').fontSize(12).fontColor(Theme.colors().brandPrimary)
          } else if (this.panel === 'settings') {
            this.Info({ title: '本地数据边界', desc: '游客与每个登录用户使用独立命名空间；图片文件不写入键值存储。' })
            this.Info({ title: '网络与权限', desc: '核心浏览、创作和游戏无需登录；同步功能仅在用户主动登录后使用网络。' })
            this.Info({ title: '业务记录生命周期', desc: '不提供业务记录删除入口；账号注销属于独立隐私权利流程。' })
            if (this.accessToken.length > 0) {
              Button('注销当前账号').height(46).fontColor('#FFFFFF').backgroundColor(Theme.colors().danger)
                .onClick(() => AlertDialog.show({ title: '确认注销账号？', message: '将向服务端申请注销当前账号。此操作不可恢复，请确认后继续。',
                  primaryButton: { value: '确认注销', action: () => { void this.closeAccount() } },
                  secondaryButton: { value: '保留账号', action: () => {} } }))
            }
            if (this.accountMessage.length > 0) Text(this.accountMessage).fontSize(13).fontColor(Theme.colors().danger)
          } else if (this.panel === 'achievements') {
            this.Info({ title: this.records.length >= 1 ? '初见年画 · 已获得' : '初见年画 · 未获得', desc: '完成任意一局游戏' })
            this.Info({ title: this.records.length >= 5 ? '乐园探索家 · 已获得' : '乐园探索家 · 未获得', desc: '完成五局游戏' })
            this.Info({ title: this.learned >= 5 ? '文化小先生 · 已获得' : '文化小先生 · 未获得', desc: '阅读五篇文化文章' })
          } else if (this.panel === 'characters') {
            ForEach(this.characters, (item: CharacterProfile) => {
              this.ContentRow({ title: item.name, media: item.image, description: this.favoriteIds.indexOf(`character:${item.id}`) >= 0 ? '已收藏 · ' + item.series : item.series,
                onTap: () => this.selectedCharacter = item })
            }, (item: CharacterProfile) => item.id)
          } else if (this.panel === 'learning') {
            if (this.learnedIds.length === 0) this.Empty('还没有学习记录，去年画馆读一篇文化文章吧')
            ForEach(this.articles.filter((item: CultureArticle) => this.learnedIds.indexOf(item.id) >= 0), (item: CultureArticle) => {
              this.ContentRow({ title: item.title, media: item.image, description: item.category, onTap: () => this.selectedArticle = item })
            }, (item: CultureArticle) => item.id)
          } else if (this.panel === 'favorites') {
            if (this.favoriteIds.length === 0) this.Empty('还没有收藏，可在角色或文章详情中点击收藏')
            ForEach(this.characters.filter((item: CharacterProfile) => this.favoriteIds.indexOf(`character:${item.id}`) >= 0), (item: CharacterProfile) => {
              this.ContentRow({ title: item.name, media: item.image, description: item.series, onTap: () => this.selectedCharacter = item })
            }, (item: CharacterProfile) => item.id)
            ForEach(this.articles.filter((item: CultureArticle) => this.favoriteIds.indexOf(`article:${item.id}`) >= 0), (item: CultureArticle) => {
              this.ContentRow({ title: item.title, media: item.image, description: item.category, onTap: () => this.selectedArticle = item })
            }, (item: CultureArticle) => item.id)
            ForEach(this.exhibitions.filter((item: Exhibition) => this.favoriteIds.indexOf('exhibition:' + item.id) >= 0), (item: Exhibition) => {
              this.ContentRow({ title: item.title, media: item.image, description: '数字专题展', onTap: () => {
                AppStorage.setOrCreate('requestedExhibition', item.id)
                this.onOpenGallery()
              } })
            }, (item: Exhibition) => item.id)
          }
        }.padding({ left: 16, right: 16, top: 16, bottom: 30 }).width('100%')
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  private async closeAccount(): Promise<void> {
    const response = await HttpClient.delete<EmptyPayload>('/privacy/account')
    if (response.code !== 0) { this.accountMessage = response.message; return }
    await AuthService.logout()
    this.panel = ''
    AppStorage.setOrCreate('tabBarHidden', false)
    this.onLogout()
  }

  @Builder
  ContentRow(data: ContentBinding) {
    Row({ space: 12 }) {
      Image(AssetResolver.media(data.media)).width(68).height(78).objectFit(ImageFit.Contain)
      Column({ space: 6 }) {
        Text(data.title).fontSize(16).fontWeight(FontWeight.Bold).maxLines(2)
        Text(data.description).fontSize(12).fontColor(Theme.colors().textSecondary)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(24).fontColor(Theme.colors().brandPrimary)
    }.padding(12).width('100%').backgroundColor(Theme.colors().surfaceCard).borderRadius(18).onClick(data.onTap)
  }

  @Builder
  Info(data: InfoBinding) {
    Column({ space: 7 }) {
      Text(data.title).fontSize(16).fontWeight(FontWeight.Bold).width('100%')
      Text(data.desc).fontSize(12).lineHeight(20).fontColor(Theme.colors().textSecondary).width('100%')
    }.padding(16).alignItems(HorizontalAlign.Start).backgroundColor(Theme.colors().surfaceCard).borderRadius(17).width('100%')
  }

  @Builder
  Empty(text: string) {
    Text(text).fontSize(14).fontColor(Theme.colors().textSecondary).padding(30).width('100%').textAlign(TextAlign.Center)
  }

  private panelTitle(): string {
    if (this.panel === 'favorites') return '我的收藏'
    if (this.panel === 'characters') return '角色图鉴'
    if (this.panel === 'artworks') return '我的创作'
    if (this.panel === 'drafts') return '我的草稿'
    if (this.panel === 'records') return '游戏记录'
    if (this.panel === 'learning') return '学习记录'
    if (this.panel === 'achievements') return '我的成就'
    if (this.panel === 'settings') return '设置'
    return '关于应用'
  }
}
