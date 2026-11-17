import { PublicAuthor, Artwork } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { SessionStore } from '../services/SessionStore'
import { ArtImage } from '../components/ArtImage'
import { CreationCanvas } from '../components/CreationCanvas'
import { LoadState } from '../components/LoadState'

@Component
export struct AuthorPage {
  @Prop authorId: string = ''
  @State author: PublicAuthor = new PublicAuthor()
  @State loading: boolean = true
  @State error: string = ''
  @StorageLink('sessionRevision') @Watch('load') revision: number = 0
  onBack: () => void = () => {}
  onOpen: (id: string) => void = () => {}
  private requestId: number = 0
  aboutToAppear(): void { this.load() }
  private async load(): Promise<void> {
    const request = ++this.requestId; this.loading = true; this.error = ''; this.author = new PublicAuthor()
    try { const author = await ArtService.author(this.authorId); if (request === this.requestId) this.author = author }
    catch (error) { if (request === this.requestId) this.error = (error as ArtError).message || '作者资料暂不可用' }
    finally { if (request === this.requestId) this.loading = false }
  }
  build() {
    Column({ space: 16 }) {
      Row() { Button('返回').backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.onBack()); Blank(); Text('作者的艺术空间').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#493B3A') }.width('100%')
      if (this.loading || this.error) LoadState({ loading: this.loading, message: this.error, onRetry: () => this.load() }).layoutWeight(1)
      else Scroll() {
        Column({ space: 16 }) {
          ArtImage({ imageKey: this.author.avatarKey, fit: ImageFit.Contain }).width(100).height(100).backgroundColor('#FBE0E7').borderRadius(28)
          Text(this.author.nickname).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#493B3A')
          if (this.author.bio) Text(this.author.bio).fontSize(14).fontColor('#76615E').lineHeight(24)
          Text('已公开作品').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%')
          ForEach(this.author.artworks, (art: Artwork) => {
            Column({ space: 8 }) {
              CreationCanvas({ document: art.document }).borderRadius(20).clip(true)
              Text(art.title).fontSize(18).fontColor('#493B3A').width('100%')
            }.width('100%').onClick(() => this.onOpen(art.id))
          }, (art: Artwork) => art.id)
        }.width('100%').padding({ bottom: 24 })
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%').padding(20).backgroundColor('#FFF8F0')
  }
}
