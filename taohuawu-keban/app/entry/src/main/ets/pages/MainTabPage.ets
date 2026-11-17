import { HomePage } from './HomePage'
import { CollectionPage } from './CollectionPage'
import { WorkshopPage } from './WorkshopPage'
import { EditorPage } from './EditorPage'
import { DetailPage } from './DetailPage'
import { LibraryPage } from './LibraryPage'
import { MinePage } from './MinePage'
import { PublishPage } from './PublishPage'
import { FeedbackPage } from './FeedbackPage'
import { AuthorPage } from './AuthorPage'
import { MessagesPage } from './MessagesPage'
import { Template, CanvasLayer } from '../models/ArtModels'
import { AuthService } from '../services/AuthService'
import { ArtService, ArtError } from '../services/ArtService'
import { SessionStore } from '../services/SessionStore'
import { NavigationHistory } from '../models/NavigationHistory'

@Component
export struct MainTabPage {
  @Prop company: string = ''
  @Prop appName: string = ''
  @Prop tagline: string = ''
  @State @Watch('syncBackHandling') tab: number = 0
  @State @Watch('syncBackHandling') route: string = ''
  @State itemId: string = ''
  @State selectedTemplate: Template = new Template()
  @State navigationError: string = ''
  @StorageProp('allowDevHttp') localDevelopment: boolean = false
  @StorageLink('navigationBackRequest') @Watch('handleBack') backRequest: number = 0
  @State editorBackRequest: number = 0
  @State mineBackRequest: number = 0
  private navigation: NavigationHistory = new NavigationHistory()
  aboutToAppear(): void { this.syncBackHandling() }
  private syncBackHandling(): void { AppStorage.setOrCreate('canHandleAppBack', this.route.length > 0 || this.tab !== 0) }
  private handleBack(): void {
    if (this.route === 'editor') this.editorBackRequest++
    else if (!this.route && this.tab === 4) this.mineBackRequest++
    else this.goBack()
  }
  private goBack(): void {
    const previous = this.navigation.pop()
    if (previous !== undefined) { this.itemId = previous.id; this.tab = previous.tab; this.route = previous.kind }
    else { this.route = ''; this.tab = 0 }
    this.syncBackHandling()
  }
  private pushRoute(kind: string, id: string): void {
    this.navigation.push(this.route, this.itemId, this.tab); this.itemId = id; this.route = kind
  }
  private rootTab(index: number): void { this.navigation.clear(); this.itemId = ''; this.route = ''; this.tab = index }
  private publish(id: string): void {
    if (this.route === 'editor') this.itemId = id
    this.pushRoute('publish', id)
  }
  onOpenLogin: () => void = () => {}
  onLogout: () => void = () => {}
  onRequireAuth: () => void = () => {}
  private open(kind: string, id: string): void {
    if (kind === 'catalog') { this.rootTab(1); return }
    if (kind === 'search') { this.pushRoute('search', ''); return }
    if (kind === 'workshop') { this.rootTab(2); return }
    if (kind === 'mine') { this.rootTab(4); return }
    if (kind === 'plaza') { this.rootTab(3); return }
    if (kind === 'character' || kind === 'artwork' || kind === 'article' || kind === 'category' || kind === 'knowledge' || kind === 'author') {
      this.pushRoute(kind, id); return
    }
    if (['notifications', 'favorites', 'history', 'artworks', 'creations', 'versions', 'likes', 'feedback', 'publications'].indexOf(kind) >= 0) {
      if (!AuthService.isLoggedIn()) { this.onRequireAuth(); return }
      this.pushRoute(kind, id)
    }
  }
  private edit(template: Template, id: string): void {
    if (!AuthService.isLoggedIn()) { this.onRequireAuth(); return }
    this.selectedTemplate = template; this.pushRoute('editor', id)
  }
  private async createFromCharacter(id: string): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.onRequireAuth(); return }
    this.navigationError = ''
    const session = SessionStore.revision()
    try {
      const character = await ArtService.getCharacter(id)
      const materials = await ArtService.materials()
      const templates = await ArtService.templates()
      if (session !== SessionStore.revision()) return
      const material = materials.find(m => m.imageKey === character.imageKey && m.kind === 'character')
      if (material === undefined || templates.length === 0) throw new Error('该角色暂没有可用创作素材')
      const template = new Template(); template.id = templates[0].id; template.name = `${character.name}的桃花印记`; template.document = ArtService.document(templates[0].document)
      const layer = new CanvasLayer(); layer.id = `character_${Date.now()}`; layer.materialId = material.id; layer.imageKey = material.imageKey
      template.document.layers = [layer]; this.edit(template, '')
    } catch (error) { this.navigationError = (error as ArtError).message || '创作素材暂不可用，请重试' }
  }
  private icon(index: number): Resource {
    if (index === 0) return $r('sys.symbol.house')
    if (index === 1) return $r('sys.symbol.book')
    if (index === 2) return $r('sys.symbol.paintbrush')
    if (index === 3) return $r('sys.symbol.square_grid_2x2')
    return $r('sys.symbol.person')
  }
  build() {
    Column() {
      if (this.localDevelopment) Text('本地联调 · 文件存储 · 非生产服务').fontSize(11).fontColor('#A93635').width('100%').padding(5).backgroundColor('#FBE0E7')
      if (this.navigationError) Text(this.navigationError).fontSize(13).fontColor('#A93635').padding(8).onClick(() => { this.navigationError = '' })
      if (this.route === 'editor') {
        EditorPage({ template: this.selectedTemplate, creationId: this.itemId, backRequest: this.editorBackRequest,
          onBack: () => this.goBack(),
          onPublish: (id: string) => this.publish(id) }).layoutWeight(1)
      } else if (this.route === 'publish') {
        PublishPage({ creationId: this.itemId, onBack: () => this.goBack() }).layoutWeight(1)
      } else if (this.route === 'feedback') {
        FeedbackPage({ onBack: () => this.goBack() }).layoutWeight(1)
      } else if (this.route === 'notifications') {
        MessagesPage({ onBack: () => this.goBack(), onOpen: (kind: string, id: string) => this.open(kind, id) }).layoutWeight(1)
      } else if (this.route === 'author') {
        AuthorPage({ authorId: this.itemId, onBack: () => this.goBack(), onOpen: (id: string) => this.open('artwork', id) }).layoutWeight(1)
      } else if (this.route === 'character' || this.route === 'article' || this.route === 'artwork') {
        DetailPage({ kind: this.route, itemId: this.itemId, onBack: () => this.goBack(), onLogin: () => this.onRequireAuth(), onAuthor: (id: string) => this.open('author', id),
          onOpen: (kind: string, id: string) => this.open(kind, id),
          onCreate: (id: string) => this.createFromCharacter(id) }).layoutWeight(1)
      } else if (this.route === 'category' || this.route === 'knowledge' || this.route === 'search') {
        Column() {
          Button('返回').onClick(() => this.goBack()).margin(12)
          CollectionPage({ mode: this.route === 'knowledge' ? 'knowledge' : this.route === 'search' ? 'search' : 'catalog', initialCategory: this.itemId,
            onOpen: (kind: string, id: string) => this.open(kind, id) }).layoutWeight(1)
        }.layoutWeight(1)
      } else if (this.route) {
        LibraryPage({ kind: this.route, onBack: () => this.goBack(), onLogin: () => this.onRequireAuth(),
          onOpen: (kind: string, id: string) => this.open(kind, id), onEdit: (template: Template, id: string) => this.edit(template, id),
          onPublish: (id: string) => this.publish(id) }).layoutWeight(1)
      } else if (this.tab === 0) HomePage({ onOpen: (kind: string, id: string) => this.open(kind, id) }).layoutWeight(1)
      else if (this.tab === 1) CollectionPage({ mode: 'catalog', onOpen: (kind: string, id: string) => this.open(kind, id) }).layoutWeight(1)
      else if (this.tab === 2) WorkshopPage({ onEdit: (template: Template, id: string) => this.edit(template, id), onLogin: () => this.onRequireAuth() }).layoutWeight(1)
      else if (this.tab === 3) CollectionPage({ mode: 'plaza', onOpen: (kind: string, id: string) => this.open(kind, id) }).layoutWeight(1)
      else MinePage({ backRequest: this.mineBackRequest, onBackRoot: () => this.rootTab(0), onOpen: (kind: string, id: string) => this.open(kind, id), onLogin: () => this.onRequireAuth(), onLogout: () => this.onLogout() }).layoutWeight(1)
      if (this.route !== 'editor' && this.route !== 'publish' && this.route !== 'character' && this.route !== 'article' && this.route !== 'artwork') {
        Row() {
          ForEach(['首页', '图鉴', '工坊', '广场', '我的'], (title: string, index: number) => {
            Column({ space: 3 }) {
              SymbolGlyph(this.icon(index)).fontSize(22).fontColor([this.tab === index ? '#A93635' : '#8B716B'])
              Text(title).fontSize(11).fontColor(this.tab === index ? '#A93635' : '#76615E')
            }.layoutWeight(1).height(56).justifyContent(FlexAlign.Center).borderRadius(14)
              .backgroundColor(this.tab === index ? '#FBE0E7' : '#FFF8F0').onClick(() => this.rootTab(index))
          })
        }.id('thwkb-main-tabs').width('100%').padding({ left: 10, right: 10, top: 6, bottom: 6 }).backgroundColor('#FFF8F0')
      }
    }.width('100%').height('100%').backgroundColor('#FFF8F0')
  }
}
