import { CanvasDocument, CanvasLayer, Template, Creation, Material } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { SessionStore } from '../services/SessionStore'
import { DraftStore } from '../services/DraftStore'
import { CreationCanvas } from '../components/CreationCanvas'
import { ArtImage } from '../components/ArtImage'
import { LoadState } from '../components/LoadState'
import { common } from '@kit.AbilityKit'
import { ExportService } from '../services/ExportService'
import { CanvasEditing } from '../models/CanvasEditing'

@Component
export struct EditorPage {
  @Prop template: Template = new Template()
  @Prop creationId: string = ''
  @Prop @Watch('requestBack') backRequest: number = 0
  @State document: CanvasDocument = new CanvasDocument()
  @State title: string = ''
  @State selectedId: string = ''
  @State tool: string = 'character'
  @State materials: Material[] = []
  @State loading: boolean = true
  @State error: string = ''
  @State notice: string = ''
  @State busy: boolean = false
  @State text: string = '花开好运'
  @State dirty: boolean = false
  @State replace: boolean = false
  @State undoStack: string[] = []
  @State workspaceWidth: number = 300
  @State workspaceHeight: number = 440
  @StorageLink('sessionRevision') @Watch('onSessionChange') revision: number = 0
  private record: Creation = new Creation()
  private ownerRevision: number = -1
  private dragSnapshot: string = ''
  private resizeSnapshot: string = ''
  onBack: () => void = () => {}
  onSaved: () => void = () => {}
  onPublish: (id: string) => void = () => {}
  aboutToAppear(): void { this.load() }
  private requestBack(): void { this.back() }
  private onSessionChange(): void {
    if (this.ownerRevision >= 0 && this.ownerRevision !== SessionStore.revision()) {
      this.document = new CanvasDocument(); this.materials = []; this.onBack()
    }
  }
  private async load(): Promise<void> {
    this.ownerRevision = SessionStore.revision(); this.loading = true; this.error = ''
    try {
      const materials = await ArtService.materials()
      const record = this.creationId ? await ArtService.getCreation(this.creationId) : new Creation()
      if (this.ownerRevision !== SessionStore.revision()) return
      this.materials = materials; this.record = record; this.title = record.title || this.template.name || '我的桃花印记'
      this.document = ArtService.document(this.creationId ? record.document : this.template.document)
      if (!this.creationId) this.record.templateId = this.template.id
      this.record.document = this.document
      this.ensureSelection()
    } catch (error) { if (this.ownerRevision === SessionStore.revision()) this.error = (error as ArtError).message || '创作内容加载失败' }
    finally { this.loading = false }
  }
  private checkpoint(): void {
    this.undoStack = this.undoStack.concat([JSON.stringify(this.document)]).slice(-30)
  }
  private changed(): void {
    this.document = CanvasEditing.refresh(this.document)
    this.dirty = true; this.notice = ''
  }
  private ensureSelection(): void {
    if (!this.document.layers.some(layer => layer.id === this.selectedId)) {
      this.selectedId = this.document.layers.length ? this.document.layers[this.document.layers.length - 1].id : ''
    }
  }
  private selectedScale(): number { return this.document.layers.find(layer => layer.id === this.selectedId)?.scale ?? .6 }
  private selectedRotation(): number { return this.document.layers.find(layer => layer.id === this.selectedId)?.rotation ?? 0 }
  private previewWidth(): number { return Math.min(this.workspaceWidth, Math.max(80, this.workspaceHeight * .48) * .8) }
  private select(id: string): void {
    this.finishTransforms()
    this.selectedId = id
    const layer = this.document.layers.find(l => l.id === id)
    if (layer !== undefined && layer.kind === 'text') { this.tool = 'text'; this.text = layer.text }
  }
  private choose(material: Material): void {
    this.checkpoint()
    if (material.kind === 'background') this.document.backgroundKey = material.imageKey
    else {
      const selected = this.document.layers.find(l => l.id === this.selectedId)
      if (this.replace && selected !== undefined && selected.kind === 'image') {
        selected.materialId = material.id; selected.imageKey = material.imageKey; this.replace = false
      } else {
        if (this.document.layers.length >= 60) { this.notice = '最多放置 60 个图层'; return }
        const layer = new CanvasLayer(); layer.id = `layer_${Date.now()}_${this.document.layers.length}`
        layer.materialId = material.id; layer.imageKey = material.imageKey; layer.scale = material.kind === 'character' ? .6 : .28
        this.document.layers = this.document.layers.concat([layer]); this.selectedId = layer.id
      }
    }
    this.changed()
  }
  private move(id: string, x: number, y: number, done: boolean): void {
    if (!this.document.layers.some(layer => layer.id === id) || this.busy) return
    if (!this.dragSnapshot) this.dragSnapshot = JSON.stringify(this.document)
    this.document = CanvasEditing.move(this.document, id, x, y); this.dirty = true; this.notice = ''
    if (done) this.finishTransforms()
  }
  private resize(value: number, mode: SliderChangeMode): void {
    const layer = this.document.layers.find(l => l.id === this.selectedId)
    if (layer === undefined || this.busy) return
    if (!this.resizeSnapshot) this.resizeSnapshot = JSON.stringify(this.document)
    this.document = CanvasEditing.resize(this.document, this.selectedId, value); this.dirty = true; this.notice = ''
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.finishTransforms()
    }
  }
  private finishTransforms(): void {
    const current = JSON.stringify(this.document)
    for (const snapshot of [this.dragSnapshot, this.resizeSnapshot]) {
      if (snapshot && snapshot !== current) this.undoStack = this.undoStack.concat([snapshot]).slice(-30)
    }
    this.dragSnapshot = ''; this.resizeSnapshot = ''
  }
  private stepScale(delta: number): void {
    this.finishTransforms(); this.resize(this.selectedScale() + delta, SliderChangeMode.Click)
  }
  private addText(): void {
    if (!this.text.trim()) { this.notice = '先输入祝福文字'; return }
    this.checkpoint()
    const existing = this.document.layers.find(l => l.id === this.selectedId && l.kind === 'text')
    if (existing !== undefined) existing.text = this.text.slice(0, 80)
    else {
      if (this.document.layers.length >= 60) { this.notice = '最多放置60个图层'; return }
      const layer = new CanvasLayer(); layer.id = `text_${Date.now()}`; layer.kind = 'text'; layer.text = this.text.slice(0, 80)
      layer.y = .82; layer.scale = .7; this.document.layers = this.document.layers.concat([layer]); this.selectedId = layer.id
    }
    this.changed()
  }
  private color(value: string): void {
    const layer = this.document.layers.find(l => l.id === this.selectedId)
    if (layer !== undefined && layer.kind === 'text') { this.checkpoint(); layer.color = value; this.changed() }
  }
  private palette(value: string): void {
    this.checkpoint(); this.document.colorTheme = value
    const color = value === 'sage' ? '#53785D' : value === 'ink' ? '#493B3A' : '#A93635'
    for (const layer of this.document.layers) if (layer.kind === 'text') layer.color = color
    this.changed()
  }
  private rotateSelection(): void {
    const layer = this.document.layers.find(l => l.id === this.selectedId)
    if (layer !== undefined) {
      this.finishTransforms(); this.checkpoint(); this.document = CanvasEditing.rotate(this.document, this.selectedId); this.dirty = true; this.notice = ''
    }
  }
  private remove(): void { this.finishTransforms(); this.checkpoint(); this.document.layers = this.document.layers.filter(l => l.id !== this.selectedId); this.ensureSelection(); this.changed() }
  private bringForward(): void {
    const layer = this.document.layers.find(l => l.id === this.selectedId)
    if (layer !== undefined) { this.checkpoint(); this.document.layers = this.document.layers.filter(l => l.id !== layer.id).concat([layer]); this.changed() }
  }
  private undo(): void {
    this.finishTransforms()
    if (this.undoStack.length === 0) return
    const raw = this.undoStack[this.undoStack.length - 1]
    this.undoStack = this.undoStack.slice(0, -1); this.document = ArtService.document(JSON.parse(raw) as CanvasDocument); this.ensureSelection(); this.dirty = true; this.notice = ''
  }
  private async save(status: string): Promise<void> {
    if (this.document.layers.some(layer => layer.kind === 'text' && layer.text.trim().length === 0)) { this.notice = '请补充空白文字图层，或将其删除后再保存'; return }
    if (this.busy || this.ownerRevision !== SessionStore.revision()) return
    this.finishTransforms()
    this.busy = true; this.notice = ''
    this.record.title = this.title.trim() || '我的桃花印记'; this.record.document = this.document; this.record.status = status
    let localSaved: boolean = false
    try { await DraftStore.save(this.record); localSaved = true } catch { /* Cloud save must remain available. */ }
    try {
      const saved = await ArtService.saveCreation(this.record)
      if (this.ownerRevision !== SessionStore.revision()) return
      this.record = saved; this.document = saved.document; this.dirty = false
      try { await DraftStore.save(saved) } catch { /* The confirmed cloud result remains authoritative. */ }
      this.notice = status === 'draft' ? '草稿已同步保存' : '作品已保存，可继续编辑'; this.onSaved()
    } catch (error) { if (this.ownerRevision === SessionStore.revision()) this.notice = `${(error as ArtError).message || '保存失败'}；${localSaved ? '已保留本机副本，可重试同步' : '本机副本也未能保存，请保留页面并重试'}` }
    finally { this.busy = false }
  }
  private async restoreLocal(): Promise<void> {
    try {
      const record = await DraftStore.restore()
      if (this.ownerRevision !== SessionStore.revision()) return
      if (record === undefined) { this.notice = '当前账号没有本地恢复副本'; if (this.error) this.error = '当前账号没有本机副本，请检查网络后重新加载'; return }
      this.checkpoint(); this.record = record; this.document = record.document; this.ensureSelection(); this.title = record.title; this.error = ''; this.loading = false; this.dirty = true; this.notice = '已恢复当前账号本机副本，保存需服务端确认；素材目录不可用时仍可调整已有图层。'
    } catch { this.notice = '本地副本读取失败'; if (this.error) this.error = '本机副本读取失败，请检查网络后重试' }
  }
  private back(): void {
    if (!this.dirty) { this.onBack(); return }
    AlertDialog.show({ title: '尚未保存修改', message: '离开后未保存的修改不会同步。', primaryButton: { value: '继续编辑', action: () => {} },
      secondaryButton: { value: '离开', action: () => this.onBack() } })
  }
  private async exportImage(share: boolean): Promise<void> {
    if (this.busy) return
    const selected = this.selectedId
    this.busy = true; this.notice = ''; this.selectedId = ''
    try {
      await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 80) })
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const snapshotScale = this.document.width / vp2px(this.previewWidth())
      if (share) { await ExportService.share(context, 'creationExportCanvas', this.title, snapshotScale); this.notice = '已打开系统分享面板' }
      else { const saved = await ExportService.save(context, 'creationExportCanvas', this.title, snapshotScale); this.notice = saved ? 'PNG 图片已导出' : '已取消导出' }
    } catch { this.notice = '导出或分享未完成，请重试' }
    finally { this.selectedId = selected; this.busy = false }
  }
  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Button('返回').backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.back())
        Text('创作工坊').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A').layoutWeight(1)
        Button('撤销').id('editor-undo').enabled(this.undoStack.length > 0 && !this.busy).backgroundColor('#FBE0E7').fontColor('#A93635').onClick(() => this.undo())
      }.width('100%')
      if (this.loading || this.error) {
        LoadState({ loading: this.loading, message: this.error, onRetry: () => this.load() }).layoutWeight(1)
        if (this.error) Button('尝试恢复当前账号本机副本').backgroundColor('#FBE0E7').fontColor('#A93635').onClick(() => this.restoreLocal())
      }
      else {
        Column({ space: 6 }) {
            CreationCanvas({ document: this.document, selectedId: this.selectedId, interactive: true,
              onSelect: (id: string) => this.select(id), onMove: (id: string, x: number, y: number, done: boolean) => this.move(id, x, y, done) })
              .id('creationExportCanvas').width(this.previewWidth()).height(this.previewWidth() * 1.25).borderRadius(12).clip(true)
            Row({ space: 6 }) {
              Button('−').id('editor-scale-down').width(44).height(44).fontSize(22).backgroundColor('#F9EDE2').fontColor('#493B3A')
                .enabled(!!this.selectedId && !this.busy).onClick(() => this.stepScale(-.1))
              Slider({ value: this.document.layers.find(l => l.id === this.selectedId)?.scale ?? .6, min: .08, max: 1.5, step: .01 })
                .id('editor-scale-slider').layoutWeight(1).enabled(!!this.selectedId && !this.busy).onChange((value: number, mode: SliderChangeMode) => this.resize(value, mode))
              Text(Math.round(this.selectedScale() * 100) + '%').id('editor-scale-value').width(38).fontSize(12).fontColor('#493B3A')
              Button('+').id('editor-scale-up').width(44).height(44).fontSize(22).backgroundColor('#F9EDE2').fontColor('#493B3A')
                .enabled(!!this.selectedId && !this.busy).onClick(() => this.stepScale(.1))
            }.width('100%')
            Row({ space: 6 }) {
              Button('置顶').id('editor-layer-front').layoutWeight(1).height(44).enabled(!!this.selectedId && !this.busy).fontSize(12).backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.bringForward())
              Button('旋转 ' + this.selectedRotation() + '°').id('editor-rotate').layoutWeight(1.4).height(44).fontSize(12).backgroundColor('#FBE0E7').fontColor('#A93635').enabled(!!this.selectedId && !this.busy).onClick(() => this.rotateSelection())
              Button('删除').id('editor-layer-remove').layoutWeight(1).height(44).enabled(!!this.selectedId && !this.busy).fontSize(12).backgroundColor('#F9EDE2').fontColor('#A93635').onClick(() => this.remove())
            }.width('100%')
            if (!this.selectedId) Text('先添加角色、贴纸或文字，再调整图层').fontSize(12).fontColor('#76615E')
            Scroll() {
              Column({ space: 12 }) {
            Scroll() {
              Row({ space: 6 }) {
                ForEach(['character', 'background', 'sticker', 'text', 'seal'], (tool: string) => {
                  Button(tool === 'character' ? '角色' : tool === 'background' ? '背景' : tool === 'sticker' ? '贴纸' : tool === 'text' ? '文字' : '印章')
                    .backgroundColor(this.tool === tool ? '#A93635' : '#F9EDE2').fontColor(this.tool === tool ? '#FFFFFF' : '#493B3A')
                    .onClick(() => { this.tool = tool })
                })
              }
            }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
            if (this.tool === 'text') {
              TextInput({ text: this.text, placeholder: '输入祝福文字' }).onChange((value: string) => {
                this.text = value
                const selected = this.document.layers.find(l => l.id === this.selectedId && l.kind === 'text')
                if (selected !== undefined) { selected.text = value; this.changed() }
              }).maxLength(80)
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                ForEach(['#493B3A', '#D95C52', '#A93635', '#53785D', '#FFF8F0'], (color: string) => {
                  Button().width(44).height(44).margin({ right: 6, bottom: 6 }).backgroundColor(color).border({ width: 1, color: '#BBA49B' }).onClick(() => this.color(color))
                })
                Button('添加文字').fontSize(12).onClick(() => this.addText())
              }.width('100%')
            } else {
              if (this.document.layers.some(layer => layer.id === this.selectedId && layer.kind === 'image') && this.tool !== 'background') Button(this.replace ? '点击下方素材进行替换' : '替换选中素材').onClick(() => { this.replace = !this.replace })
              Scroll() {
                Row({ space: 10 }) {
                  ForEach(this.materials.filter(m => this.tool === 'seal' ? m.imageKey === 'sticker_seal' : m.kind === this.tool), (material: Material) => {
                    Column({ space: 4 }) {
                      ArtImage({ imageKey: material.imageKey, fit: ImageFit.Contain }).width(76).height(82).backgroundColor('#F9EDE2').borderRadius(12)
                      Text(material.name).fontSize(11).fontColor('#76615E').maxLines(1)
                    }.width(80).onClick(() => this.choose(material))
                  }, (material: Material) => material.id)
                }
              }.height(110).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
            }
            TextInput({ text: this.title, placeholder: '作品名称' }).id('editor-title').onChange((value: string) => { this.title = value; this.dirty = true }).maxLength(60).height(44)
            Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
              Text('配色印框').fontSize(12).fontColor('#76615E')
              ForEach(['peach', 'sage', 'ink'], (palette: string) => {
                Button(palette === 'peach' ? '桃花' : palette === 'sage' ? '豆青' : '墨印').fontSize(12)
                  .backgroundColor(this.document.colorTheme === palette ? '#A93635' : '#F9EDE2').fontColor(this.document.colorTheme === palette ? '#FFFFFF' : '#493B3A')
                  .onClick(() => this.palette(palette))
              })
            }.width('100%')
            Button('恢复本机副本').fontSize(12).backgroundColor('#F9EDE2').fontColor('#76615E').onClick(() => this.restoreLocal())
            Row({ space: 12 }) {
              Button('导出 PNG').layoutWeight(1).enabled(!this.busy).backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.exportImage(false))
              Button('系统分享').layoutWeight(1).enabled(!this.busy).backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.exportImage(true))
            }.width('100%')
            Button('创建发布版本').width('100%').backgroundColor('#FBE0E7').fontColor('#A93635').enabled(!this.busy)
              .onClick(() => {
                if (!this.record.id || this.record.status !== 'completed' || this.dirty) this.notice = '请先保存当前正式作品，再创建发布版本'
                else this.onPublish(this.record.id)
              })
          }.width('100%').padding({ bottom: 16 })
            }.id('editor-scroll').layoutWeight(1).edgeEffect(EdgeEffect.Spring)
        }.width('100%').layoutWeight(1).enabled(!this.busy).onAreaChange((oldArea: Area, area: Area) => {
          this.workspaceWidth = Number(area.width); this.workspaceHeight = Number(area.height)
        })
        if (this.notice) Text(this.notice).id('editor-notice').fontSize(13).fontColor('#A93635').width('100%').padding(8).backgroundColor('#FBE0E7')
        Row({ space: 12 }) {
          Button('保存草稿').id('editor-save-draft').layoutWeight(1).backgroundColor('#FBE0E7').fontColor('#A93635').enabled(!this.busy).onClick(() => this.save('draft'))
          Button(this.busy ? '保存中…' : '保存作品').id('editor-save-completed').layoutWeight(1).backgroundColor('#A93635').enabled(!this.busy).onClick(() => this.save('completed'))
        }.width('100%')
      }
    }.width('100%').height('100%').padding(16).backgroundColor('#FFF8F0')
  }
}
