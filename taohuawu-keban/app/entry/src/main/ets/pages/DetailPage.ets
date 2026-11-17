import { ArtImage } from '../components/ArtImage'
import { LoadState } from '../components/LoadState'
import { Character, KnowledgeArticle, Artwork, SourceReference, ReportRequest } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { AuthService } from '../services/AuthService'
import { SessionStore } from '../services/SessionStore'
import { CreationCanvas } from '../components/CreationCanvas'
import { ExportService } from '../services/ExportService'
import { common } from '@kit.AbilityKit'

@Component
export struct DetailPage {
  @Prop kind: string = 'character'
  @Prop @Watch('reload') itemId: string = ''
  @State character: Character = new Character()
  @State article: KnowledgeArticle = new KnowledgeArticle()
  @State artwork: Artwork = new Artwork()
  @State loading: boolean = true
  @State error: string = ''
  @State actionError: string = ''
  @State busy: boolean = false
  @State reporting: boolean = false
  @State reportReason: string = 'copyright'
  @State reportText: string = ''
  @State reportReceipt: string = ''
  @State related: Artwork[] = []
  @State similar: Character[] = []
  @State recommendationError: string = ''
  @StorageLink('sessionRevision') @Watch('reload') revision: number = 0
  onBack: () => void = () => {}
  onCreate: (materialId: string) => void = () => {}
  onLogin: () => void = () => {}
  onAuthor: (id: string) => void = () => {}
  onOpen: (kind: string, id: string) => void = () => {}
  private requestId: number = 0
  aboutToAppear(): void { this.reload() }
  private async reload(): Promise<void> {
    const request = ++this.requestId; const session = SessionStore.revision()
    this.loading = true; this.error = ''; this.actionError = ''; this.related = []; this.similar = []; this.recommendationError = ''; this.reporting = false; this.reportReceipt = ''
    try {
      if (this.kind === 'character') {
        const value = await ArtService.getCharacter(this.itemId)
        if (request === this.requestId && session === SessionStore.revision()) {
          this.character = value
          this.recommend(value, request, session)
        }
      } else if (this.kind === 'article') {
        const value = await ArtService.getArticle(this.itemId)
        if (request === this.requestId && session === SessionStore.revision()) this.article = value
      } else {
        const value = await ArtService.getArtwork(this.itemId)
        if (request === this.requestId && session === SessionStore.revision()) this.artwork = value
      }
      if (AuthService.isLoggedIn() && request === this.requestId && session === SessionStore.revision()) {
        ArtService.history(this.kind, this.itemId).catch(() => {})
      }
    } catch (error) { if (request === this.requestId && session === SessionStore.revision()) this.error = (error as ArtError).message || '详情读取失败' }
    finally { if (request === this.requestId) this.loading = false }
  }
  private saved(): boolean { return this.kind === 'character' ? this.character.favorite : this.kind === 'article' ? this.article.favorite : this.artwork.favorite }
  private async recommend(character: Character, request: number, session: number): Promise<void> {
    try {
      const similar = await ArtService.characters(character.categoryId, '')
      if (request === this.requestId && session === SessionStore.revision()) this.similar = similar.filter(c => c.id !== character.id).slice(0, 4)
    } catch { if (request === this.requestId && session === SessionStore.revision()) this.recommendationError = '相似角色暂时读取失败，可重新加载。' }
    for (const id of character.relatedArtworkIds.slice(0, 4)) {
      if (request !== this.requestId || session !== SessionStore.revision()) return
      try {
        const value = await ArtService.getArtwork(id)
        if (request === this.requestId && session === SessionStore.revision()) this.related = this.related.concat([value])
      } catch { if (request === this.requestId && session === SessionStore.revision()) this.recommendationError = '部分关联作品暂不可用。' }
    }
  }
  private async share(): Promise<void> {
    this.busy = true; this.actionError = ''
    try { await ExportService.share(getContext(this) as common.UIAbilityContext, 'artworkDetailCanvas', this.artwork.title) }
    catch { this.actionError = '未能打开系统分享，请重试' }
    finally { this.busy = false }
  }
  private async toggleFavorite(): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.onLogin(); return }
    this.busy = true; this.actionError = ''
    try { await ArtService.favorite(this.kind, this.itemId, !this.saved()); await this.reload() }
    catch (error) { this.actionError = (error as ArtError).message || '收藏失败' }
    finally { this.busy = false }
  }
  private async toggleLike(): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.onLogin(); return }
    this.busy = true; this.actionError = ''
    try { await ArtService.like(this.itemId, !this.artwork.liked); await this.reload() }
    catch (error) { this.actionError = (error as ArtError).message || '点赞失败' }
    finally { this.busy = false }
  }
  private async report(): Promise<void> {
    this.busy = true; this.actionError = ''
    try {
      const body = new ReportRequest(); body.reasonCode = this.reportReason; body.description = this.reportText
      const result = await ArtService.reportArtwork(this.itemId, body)
      this.reportReceipt = `举报已受理，编号 ${result.id}`; this.reporting = false; this.reportText = ''
    } catch (error) { this.actionError = (error as ArtError).message || '举报未提交，请重试' }
    finally { this.busy = false }
  }
  @Builder section(title: string, body: string) {
    if (body.length > 0) {
      Column({ space: 8 }) {
        Text(title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A')
        Text(body).fontSize(16).lineHeight(26).fontColor('#76615E')
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 22 })
    }
  }
  @Builder sources(values: SourceReference[]) {
    if (values.length > 0) {
      Column({ space: 10 }) {
        Text('资料来源').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A')
        ForEach(values, (source: SourceReference) => {
          Column({ space: 4 }) {
            Text(source.title).fontSize(14).fontColor('#493B3A')
            Text(source.publisher).fontSize(12).fontColor('#76615E')
            Text(source.url).fontSize(12).fontColor('#53785D').copyOption(CopyOptions.LocalDevice)
          }.width('100%').alignItems(HorizontalAlign.Start)
        }, (s: SourceReference) => s.url)
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor('#EEF3E9').borderRadius(18).margin({ top: 24 })
    }
  }
  build() {
    Column() {
      Row() {
        Button('返回').backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.onBack())
        Blank()
        Text(this.kind === 'character' ? '角色图鉴' : this.kind === 'article' ? '年画小课堂' : '作品详情').fontSize(16).fontColor('#493B3A')
      }.width('100%').padding(16)
      if (this.loading || this.error) LoadState({ loading: this.loading, message: this.error, onRetry: () => this.reload() }).layoutWeight(1)
      else {
        Scroll() {
          Column({ space: 8 }) {
            if (this.kind === 'character') {
              ArtImage({ imageKey: this.character.imageKey, fit: ImageFit.Contain }).height(350).backgroundColor('#FBE0E7').borderRadius(24)
              Text(this.character.name).fontSize(30).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%').margin({ top: 14 })
              Text(`${this.character.categoryName}  ${this.character.originalNotice}`).fontSize(13).fontColor('#A93635').width('100%')
              this.section('角色故事 · 原创设定', this.character.story)
              this.section('文化灵感', this.character.culturalMeaning)
              this.section('设计灵感', this.character.inspiration)
              this.section('色彩与造型', `${this.character.colorDescription}\n${this.character.designDescription}`)
              this.sources(this.character.sources)
              if (this.related.length > 0) {
                Text('角色的相关作品').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%').margin({ top: 20 })
                ForEach(this.related, (art: Artwork) => {
                  Row({ space: 12 }) {
                    CreationCanvas({ document: art.document }).width(64).height(80).borderRadius(10).clip(true)
                    Text(art.title).fontSize(15).fontColor('#493B3A').layoutWeight(1)
                  }.width('100%').onClick(() => this.onOpen('artwork', art.id))
                }, (art: Artwork) => art.id)
              }
              if (this.similar.length > 0) {
                Text('还可以认识它们').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%').margin({ top: 20 })
                ForEach(this.similar, (character: Character) => {
                  Row({ space: 12 }) {
                    ArtImage({ imageKey: character.imageKey, fit: ImageFit.Contain }).width(64).height(72)
                    Text(character.name).fontSize(16).fontColor('#493B3A')
                  }.width('100%').onClick(() => this.onOpen('character', character.id))
                }, (character: Character) => character.id)
              }
              if (this.recommendationError) Text(this.recommendationError).fontSize(13).fontColor('#76615E')
            } else if (this.kind === 'article') {
              ArtImage({ imageKey: this.article.coverKey }).height(210).borderRadius(20).clip(true)
              Text(this.article.title).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%').margin({ top: 16 })
              Text('文化资料').fontSize(12).fontColor('#53785D').width('100%')
              Text(this.article.body).fontSize(16).lineHeight(28).fontColor('#493B3A').width('100%').margin({ top: 16 })
              this.sources(this.article.sources)
            } else {
              CreationCanvas({ document: this.artwork.document }).id('artworkDetailCanvas').borderRadius(20).clip(true)
              Text(this.artwork.title).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%')
              Text(`${this.artwork.origin === 'official' ? '官方作品' : '用户原创'}  ${this.artwork.authorName}`).fontSize(14).fontColor('#76615E').width('100%')
                .onClick(() => this.onAuthor(this.artwork.authorId))
              this.section('作品介绍', this.artwork.description)
              this.section('版权与素材来源', this.artwork.copyrightSource)
              Button('分享作品图片').backgroundColor('#FBE0E7').fontColor('#A93635').enabled(!this.busy).onClick(() => this.share())
              if (this.reportReceipt) Text(this.reportReceipt).fontSize(13).fontColor('#53785D')
              Button(this.reporting ? '取消举报' : '举报作品').backgroundColor('#F9EDE2').fontColor('#76615E').onClick(() => {
                if (!AuthService.isLoggedIn()) this.onLogin(); else this.reporting = !this.reporting
              })
              if (this.reporting) {
                Text('选择举报原因，补充说明有助于审核。').fontSize(14).fontColor('#76615E').width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(['copyright', 'inappropriate', 'misleading', 'other'], (reason: string) => {
                    Button(reason === 'copyright' ? '版权问题' : reason === 'inappropriate' ? '不当内容' : reason === 'misleading' ? '误导信息' : '其他问题')
                      .fontSize(12).margin(4).backgroundColor(this.reportReason === reason ? '#A93635' : '#F9EDE2').fontColor(this.reportReason === reason ? '#FFFFFF' : '#493B3A')
                      .onClick(() => { this.reportReason = reason })
                  })
                }.width('100%')
                TextArea({ text: this.reportText, placeholder: '请说明具体问题，不要填写无关个人信息' }).height(100).maxLength(1000).onChange((value: string) => { this.reportText = value })
                Button('提交举报').enabled(!this.busy).backgroundColor('#A93635').onClick(() => this.report())
              }
            }
          }.width('100%').padding({ left: 20, right: 20, bottom: 30 }).alignItems(HorizontalAlign.Start)
        }.layoutWeight(1).edgeEffect(EdgeEffect.Spring)
        if (this.actionError) Text(this.actionError).fontSize(13).fontColor('#A93635').padding(8)
        Row({ space: 12 }) {
          Button(this.saved() ? '已收藏' : '收藏').backgroundColor('#FBE0E7').fontColor('#A93635').layoutWeight(1).enabled(!this.busy).onClick(() => this.toggleFavorite())
          if (this.kind === 'character') Button('带去创作').backgroundColor('#A93635').layoutWeight(1).onClick(() => this.onCreate(this.character.id))
          if (this.kind === 'artwork') Button(`${this.artwork.liked ? '已喜欢' : '喜欢'} ${this.artwork.likeCount}`).backgroundColor('#A93635').layoutWeight(1).enabled(!this.busy).onClick(() => this.toggleLike())
        }.width('100%').padding(16)
      }
    }.width('100%').height('100%').backgroundColor('#FFF8F0')
  }
}
