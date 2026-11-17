import { Creation, ArtworkVersionRequest } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { SessionStore } from '../services/SessionStore'
import { CreationCanvas } from '../components/CreationCanvas'
import { LoadState } from '../components/LoadState'

@Component
export struct PublishPage {
  @Prop creationId: string = ''
  @State creation: Creation = new Creation()
  @State description: string = ''
  @State declaration: string = ''
  @State agreed: boolean = false
  @State loading: boolean = true
  @State busy: boolean = false
  @State error: string = ''
  @State receipt: string = ''
  @State artworkId: string = ''
  @StorageLink('sessionRevision') @Watch('sessionChanged') revision: number = 0
  private ownerRevision: number = -1
  onBack: () => void = () => {}
  private sessionChanged(): void { if (this.ownerRevision >= 0 && this.ownerRevision !== SessionStore.revision()) this.onBack() }
  aboutToAppear(): void { this.load() }
  private async load(): Promise<void> {
    this.ownerRevision = SessionStore.revision(); this.loading = true; this.error = ''
    try {
      const value = await ArtService.getCreation(this.creationId)
      if (this.ownerRevision !== SessionStore.revision()) return
      this.creation = value
      if (value.status !== 'completed') this.error = '请先在工坊保存正式作品，再创建发布版本。'
    } catch (error) { if (this.ownerRevision === SessionStore.revision()) this.error = (error as ArtError).message || '作品读取失败' }
    finally { this.loading = false }
  }
  private async submit(): Promise<void> {
    if (!this.agreed || !this.declaration.trim()) { this.error = '请填写版权来源并主动确认发布授权'; return }
    this.busy = true; this.error = ''
    try {
      if (!this.artworkId) {
        const body = new ArtworkVersionRequest(); body.description = this.description; body.copyrightDeclaration = this.declaration
        const artwork = await ArtService.createArtwork(this.creationId, body)
        if (this.ownerRevision !== SessionStore.revision()) return
        this.artworkId = artwork.id
      }
      const publication = await ArtService.submitArtwork(this.artworkId)
      if (this.ownerRevision === SessionStore.revision()) this.receipt = `已提交审核，编号 ${publication.id}。审核通过前仅自己可见；后续编辑创作不会更改这个发布版本。`
    } catch (error) { if (this.ownerRevision === SessionStore.revision()) this.error = (error as ArtError).message || '提交未完成，可重试' }
    finally { this.busy = false }
  }
  build() {
    Column({ space: 14 }) {
      Row() {
        Button('返回').backgroundColor('#F9EDE2').fontColor('#493B3A').enabled(!this.busy).onClick(() => this.onBack())
        Blank()
        Text('发布到灵感集市').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#493B3A')
      }.width('100%')
      if (this.loading) LoadState({ loading: true }).layoutWeight(1)
      else Scroll() {
        Column({ space: 16 }) {
          CreationCanvas({ document: this.creation.document }).borderRadius(20).clip(true)
          Text(this.creation.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%')
          if (this.receipt) {
            Text(this.receipt).fontSize(16).fontColor('#53785D').lineHeight(26)
            Button('完成').width('100%').backgroundColor('#A93635').onClick(() => this.onBack())
          } else if (this.creation.status === 'completed') {
            TextArea({ text: this.description, placeholder: '介绍你的灵感（选填）' }).height(100).maxLength(1000).enabled(!this.artworkId)
              .onChange((value: string) => { this.description = value })
            TextArea({ text: this.declaration, placeholder: '说明素材来源、原创部分及使用授权' }).height(120).maxLength(2000).enabled(!this.artworkId)
              .onChange((value: string) => { this.declaration = value })
            Text('作品使用了工坊授权素材时，请如实注明组合创作；不要声称素材本身由你绘制。').fontSize(13).fontColor('#76615E').lineHeight(22)
            Row({ space: 10 }) {
              Checkbox({ name: 'publication-rights' }).select(this.agreed).selectedColor('#A93635').onChange((value: boolean) => { this.agreed = value })
              Text('我确认拥有发布权限，并授权在作品广场展示此版本。').fontSize(14).fontColor('#493B3A').layoutWeight(1)
            }.width('100%')
            Button(this.busy ? '正在提交…' : '提交审核').width('100%').backgroundColor('#A93635').enabled(!this.busy && this.agreed && this.declaration.trim().length > 0).onClick(() => this.submit())
          }
          if (this.error) Text(this.error).fontSize(14).fontColor('#A93635').width('100%')
        }.width('100%').padding({ bottom: 24 })
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%').padding(20).backgroundColor('#FFF8F0')
  }
}
