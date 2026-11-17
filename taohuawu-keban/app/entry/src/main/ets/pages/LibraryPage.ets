import { Relation, Notification, Artwork, Creation, Template, Publication } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { AuthService } from '../services/AuthService'
import { SessionStore } from '../services/SessionStore'
import { ArtImage } from '../components/ArtImage'
import { CreationCanvas } from '../components/CreationCanvas'
import { LoadState } from '../components/LoadState'

@Component
export struct LibraryPage {
  @Prop kind: string = 'favorites'
  @State relations: Relation[] = []
  @State notifications: Notification[] = []
  @State artworks: Artwork[] = []
  @State creations: Creation[] = []
  @State publications: Publication[] = []
  @State loading: boolean = true
  @State error: string = ''
  @State nextCursor: string = ''
  @StorageLink('sessionRevision') @Watch('sessionChanged') revision: number = 0
  @StorageLink('artDataRevision') @Watch('sessionChanged') dataRevision: number = 0
  private requestId: number = 0
  onBack: () => void = () => {}
  onLogin: () => void = () => {}
  onOpen: (kind: string, id: string) => void = () => {}
  onEdit: (template: Template, creationId: string) => void = () => {}
  onPublish: (id: string) => void = () => {}
  aboutToAppear(): void { this.reload() }
  private sessionChanged(): void { this.reload(false) }
  private recordCount(): number { return this.relations.length + this.notifications.length + this.artworks.length + this.creations.length + this.publications.length }
  private async reload(append: boolean = false): Promise<void> {
    const request = ++this.requestId; const session = SessionStore.revision()
    if (!append) { this.relations = []; this.notifications = []; this.artworks = []; this.creations = []; this.publications = []; this.nextCursor = '' }
    if (!AuthService.isLoggedIn()) { this.loading = false; return }
    this.loading = true; this.error = ''
    try {
      if (this.kind === 'publications') {
        const values = await ArtService.publications()
        if (request === this.requestId && session === SessionStore.revision()) this.publications = values
      } else if (this.kind === 'notifications') {
        const values = await ArtService.notifications()
        if (request === this.requestId && session === SessionStore.revision()) this.notifications = values
      } else if (this.kind === 'creations') {
        const values = await ArtService.draftCreations()
        if (request === this.requestId && session === SessionStore.revision()) this.creations = values
      } else if (this.kind === 'likes') {
        const page = await ArtService.myLikes(append ? this.nextCursor : '')
        if (request === this.requestId && session === SessionStore.revision()) {
          this.artworks = append ? this.artworks.concat(page.items.filter(a => !this.artworks.some(old => old.id === a.id))) : page.items
          this.nextCursor = page.nextCursor
        }
      } else if (this.kind === 'artworks') {
        const values = await ArtService.savedCreations()
        if (request === this.requestId && session === SessionStore.revision()) this.creations = values
      } else if (this.kind === 'versions') {
        const values = await ArtService.myArtworks()
        if (request === this.requestId && session === SessionStore.revision()) this.artworks = values
      } else {
        const values = await ArtService.relations(this.kind)
        if (request === this.requestId && session === SessionStore.revision()) this.relations = values
      }
    } catch (error) { if (request === this.requestId && session === SessionStore.revision()) this.error = (error as ArtError).message || '记录读取失败' }
    finally { if (request === this.requestId) this.loading = false }
  }
  private async read(id: string): Promise<void> {
    try { await ArtService.readNotification(id); await this.reload() }
    catch (error) { this.error = (error as ArtError).message || '标记已读失败' }
  }
  build() {
    Column({ space: 16 }) {
      Row() {
        Button('返回').id('library-back').backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.onBack())
        Blank()
        Text(this.kind === 'publications' ? '发布审核记录' : this.kind === 'notifications' ? '消息通知' : this.kind === 'creations' ? '我的草稿' : this.kind === 'artworks' ? '我的作品' : this.kind === 'versions' ? '作品发布版本' : this.kind === 'likes' ? '我的喜欢' : this.kind === 'history' ? '最近浏览' : '我的收藏')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#493B3A')
      }.width('100%')
      if (!AuthService.isLoggedIn()) {
        LoadState({ emptyText: '登录后查看自己的记录', emptyImage: 'empty_favorites' })
        Button('登录 / 注册').backgroundColor('#A93635').onClick(() => this.onLogin())
      } else if ((this.loading || this.error) && this.recordCount() === 0) {
        LoadState({ loading: this.loading, message: this.error, onRetry: () => this.reload() }).layoutWeight(1)
        if (this.error && this.kind === 'creations') Button('进入工坊恢复本机副本').backgroundColor('#FBE0E7').fontColor('#A93635').onClick(() => this.onEdit(new Template(), ''))
      }
      else if (this.recordCount() === 0) {
        LoadState({ emptyText: '这里还没有记录', emptyImage: this.kind === 'notifications' ? 'empty_notifications' : this.kind === 'creations' ? 'empty_drafts' : 'empty_favorites' }).layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 14 }) {
            if (this.error) Text(this.error).fontSize(13).fontColor('#A93635').onClick(() => this.reload(this.kind === 'likes' && !!this.nextCursor))
            ForEach(this.publications, (item: Publication) => {
              Column({ space: 10 }) {
                Text(item.status === 'approved' ? '审核通过' : item.status === 'submitted' ? '审核中' : item.status === 'rejected' ? '审核未通过' : '已下架').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A')
                if (item.reason) Text(item.reason).fontSize(14).fontColor('#76615E').lineHeight(24)
                Text(item.updatedAt).fontSize(12).fontColor('#76615E')
                Button('查看作品版本').backgroundColor('#A93635').onClick(() => this.onOpen('artwork', item.artworkId))
              }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor('#FFFFFF').borderRadius(18)
            }, (item: Publication) => item.id)
            ForEach(this.relations, (item: Relation) => {
              Row({ space: 12 }) {
                ArtImage({ imageKey: item.available ? item.imageKey : 'empty_search', fit: ImageFit.Contain }).width(80).height(88).backgroundColor('#FBE0E7').borderRadius(14)
                Column({ space: 6 }) {
                  Text(item.title).fontSize(17).fontColor('#493B3A')
                  Text(item.updatedAt).fontSize(12).fontColor('#76615E')
                  if (this.kind === 'favorites') Button('取消收藏').fontSize(12).backgroundColor('#FBE0E7').fontColor('#A93635').onClick(() => {
                    ArtService.favorite(item.targetType, item.targetId, false).then(() => this.reload()).catch((error: ArtError) => { this.error = error.message || '取消失败，请重试' })
                  })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').onClick(() => { if (item.available) this.onOpen(item.targetType, item.targetId); else this.error = '该内容当前不可用，原始记录仍保留；可取消收藏关系。' })
            }, (item: Relation) => item.id)
            ForEach(this.notifications, (item: Notification) => {
              Column({ space: 8 }) {
                Text(item.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#493B3A')
                Text(item.body).fontSize(14).fontColor('#76615E')
                if (!item.readAt) Button('标记已读').fontSize(12).onClick(() => this.read(item.id))
                else Text('已读').fontSize(12).fontColor('#53785D')
              }.width('100%').padding(16).alignItems(HorizontalAlign.Start).backgroundColor('#FFFFFF').borderRadius(16)
            }, (item: Notification) => item.id)
            ForEach(this.creations, (item: Creation) => {
              Column({ space: 8 }) {
                CreationCanvas({ document: item.document }).borderRadius(18).clip(true)
                Text(item.title).id('creation-title-' + item.id).fontSize(17).fontColor('#493B3A')
                Text(item.status === 'completed' ? '已保存作品' : '草稿').fontSize(13).fontColor('#76615E')
                Button('继续编辑').backgroundColor('#A93635').onClick(() => this.onEdit(new Template(), item.id))
                if (item.status === 'completed') Button('创建发布版本').backgroundColor('#FBE0E7').fontColor('#A93635').onClick(() => this.onPublish(item.id))
              }.width('100%')
            }, (item: Creation) => item.id + ':' + item.revision)
            ForEach(this.artworks, (item: Artwork) => {
              Column({ space: 8 }) {
                CreationCanvas({ document: item.document }).borderRadius(18).clip(true)
                Text(item.title).fontSize(17).fontColor('#493B3A')
                Text(item.reviewStatus === 'official' ? '官方作品' : item.reviewStatus === 'approved' ? '已公开' : item.reviewStatus === 'submitted' ? '审核中' : item.reviewStatus === 'rejected' ? '审核未通过' : item.reviewStatus === 'offline' ? '已下架' : '私人版本').fontSize(13).fontColor('#76615E')
              }.width('100%').onClick(() => this.onOpen('artwork', item.id))
            }, (item: Artwork) => item.id)
            if (this.kind === 'likes' && this.nextCursor) Button(this.loading ? '加载中…' : '加载更多喜欢').enabled(!this.loading).backgroundColor('#A93635').onClick(() => this.reload(true))
          }.width('100%').padding({ bottom: 24 })
        }.id('library-scroll').layoutWeight(1).edgeEffect(EdgeEffect.Spring)
      }
    }.width('100%').height('100%').padding(20).backgroundColor('#FFF8F0')
  }
}
