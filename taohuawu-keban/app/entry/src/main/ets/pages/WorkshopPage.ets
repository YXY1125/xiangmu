import { Template, Creation } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { AuthService } from '../services/AuthService'
import { SessionStore } from '../services/SessionStore'
import { CreationCanvas } from '../components/CreationCanvas'
import { LoadState } from '../components/LoadState'

@Component
export struct WorkshopPage {
  @State templates: Template[] = []
  @State drafts: Creation[] = []
  @State loading: boolean = true
  @State error: string = ''
  @State draftError: string = ''
  @StorageLink('sessionRevision') @Watch('reload') revision: number = 0
  @StorageLink('artDataRevision') @Watch('reload') dataRevision: number = 0
  onEdit: (template: Template, creationId: string) => void = () => {}
  onLogin: () => void = () => {}
  private requestId: number = 0
  aboutToAppear(): void { this.reload() }
  private async reload(): Promise<void> {
    const request = ++this.requestId; const session = SessionStore.revision()
    this.loading = true; this.error = ''; this.drafts = []; this.draftError = ''
    try {
      const templates = await ArtService.templates()
      if (request === this.requestId && session === SessionStore.revision()) this.templates = templates
      if (AuthService.isLoggedIn()) {
        try {
          const drafts = await ArtService.creations()
          if (request === this.requestId && session === SessionStore.revision()) this.drafts = drafts
        } catch { if (request === this.requestId && session === SessionStore.revision()) this.draftError = '个人创作暂时读取失败；仍可使用下方模板，或重新加载。' }
      }
    } catch (error) { if (request === this.requestId && session === SessionStore.revision()) this.error = (error as ArtError).message || '工坊读取失败' }
    finally { if (request === this.requestId) this.loading = false }
  }
  private edit(template: Template, id: string): void {
    if (!AuthService.isLoggedIn()) this.onLogin()
    else this.onEdit(template, id)
  }
  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('动漫创作实验室').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%')
        Text('选一张底稿，把灵感印成自己的作品。').fontSize(14).fontColor('#76615E').width('100%')
        if (this.loading || this.error) LoadState({ loading: this.loading, message: this.error, onRetry: () => this.reload() })
        else {
          if (this.draftError) Text(this.draftError).fontSize(13).fontColor('#A93635').width('100%').onClick(() => this.reload())
          if (this.drafts.length > 0) {
            Text('继续创作').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%')
            ForEach(this.drafts, (draft: Creation) => {
              Row({ space: 12 }) {
                CreationCanvas({ document: draft.document }).width(80).height(100)
                Column({ space: 7 }) {
                  Text(draft.title || '未命名作品').fontSize(16).fontColor('#493B3A')
                  Text(draft.status === 'draft' ? '草稿' : '已保存作品').fontSize(12).fontColor('#76615E')
                  Text(draft.updatedAt).fontSize(11).fontColor('#76615E')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Text('编辑').fontSize(14).fontColor('#A93635')
              }.width('100%').padding(12).backgroundColor('#FFFFFF').borderRadius(16).onClick(() => this.edit(new Template(), draft.id))
            }, (draft: Creation) => draft.id + ':' + draft.revision)
          }
          Text('从模板开始').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%')
          if (this.templates.length === 0) {
            LoadState({ emptyText: '暂时没有可用模板，请稍后刷新', emptyImage: 'empty_drafts' })
            Button('重新加载模板').id('workshop-empty-retry').backgroundColor('#A93635').onClick(() => this.reload())
          }
          ForEach(this.templates, (template: Template) => {
            Column({ space: 10 }) {
              CreationCanvas({ document: template.document }).width('100%').borderRadius(20).clip(true)
              Row() {
                Text(template.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A').layoutWeight(1)
                Button('使用模板').id('use-template-' + template.id).backgroundColor('#A93635').onClick(() => this.edit(template, ''))
              }.width('100%')
            }.width('100%').margin({ bottom: 10 })
          }, (template: Template) => template.id)
        }
      }.width('100%').padding(20)
    }.id('workshop-scroll').width('100%').height('100%').align(Alignment.TopStart).backgroundColor('#FFF8F0').edgeEffect(EdgeEffect.Spring)
  }
}
