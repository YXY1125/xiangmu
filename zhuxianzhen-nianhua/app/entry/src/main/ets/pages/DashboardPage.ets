import { Theme } from '../components/design-system/Theme'
import { CultureCatalog } from '../data/CultureCatalog'
import { ArtworkLayer, CharacterProfile, CreativeTemplate, UserArtwork } from '../models/CultureModels'
import { AssetResolver } from '../utils/AssetResolver'
import { LocalDataStore } from '../services/LocalDataStore'
import { ArtworkExportService } from '../services/ArtworkExportService'
import { common } from '@kit.AbilityKit'
import { ContentService } from '../services/ContentService'
import { EditorGeometry } from '../editor/EditorGeometry'
import { EditorLayer } from '../editor/EditorLayer'
import { ArtworkLayerView } from '../editor/ArtworkLayerView'
import { CREATIVE_BACKGROUNDS, CreativeBackground } from '../data/CreativeBackgrounds'
import { BackService } from '../services/BackService'

const MODEL_WIDTH: number = 900

class EditorSnapshot {
  title: string = ''
  layers: ArtworkLayer[] = []
  backgroundId: string = 'paper-cream'
  canvasHeight: number = 900
}

@Component
export struct DashboardPage {
  @State editing: boolean = false
  @State selectedTemplate: CreativeTemplate | null = null
  @State savedWorks: UserArtwork[] = []
  onRequireAuth: () => void = () => {}
  @State templates: CreativeTemplate[] = CultureCatalog.templates()

  aboutToAppear(): void {
    this.reloadWorks()
    if ((AppStorage.get<string>('reopenArtwork') ?? '').length > 0) {
      this.selectedTemplate = null
      this.editing = true
      AppStorage.setOrCreate('tabBarHidden', true)
    }
    ContentService.templates().then((items: CreativeTemplate[]) => { if (items.length >= 20) this.templates = items })
  }

  private reloadWorks(): void {
    LocalDataStore.artworks().then((items: UserArtwork[]) => this.savedWorks = items)
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Column({ space: 3 }) {
            Text('创意工坊').fontSize(30).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
            Text('把传统纹样变成你的作品').fontSize(13).fontColor(Theme.colors().textSecondary)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('自由创作').height(42).fontSize(13).fontColor('#FFFFFF')
            .backgroundColor(Theme.colors().brandPrimary).borderRadius(21).onClick(() => {
              this.selectedTemplate = null
              this.editing = true
              AppStorage.setOrCreate('tabBarHidden', true)
            })
        }.padding({ left: 16, right: 16, top: 16, bottom: 10 }).width('100%')
        Scroll() {
          Column({ space: 22 }) {
            Stack({ alignContent: Alignment.BottomStart }) {
              Image(AssetResolver.media('banner_craft')).width('100%').height(220).objectFit(ImageFit.Cover).borderRadius(24)
              Column({ space: 5 }) {
                Text('数字创意工具').fontSize(12).fontColor('#FFF1C9')
                Text('从一张宣纸开始').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                Text('角色 · 纹样 · 贴纸 · 文字 · 图层').fontSize(12).fontColor('#FFFFFF')
              }.padding(16).alignItems(HorizontalAlign.Start).width('100%').backgroundColor('rgba(56,45,42,0.48)')
            }.width('100%')
            Text('模板中心 · 20 套').fontSize(21).fontWeight(FontWeight.Bold).width('100%')
            Grid() {
              ForEach(this.templates, (item: CreativeTemplate) => {
                GridItem() {
                  Column({ space: 8 }) {
                    Stack({ alignContent: Alignment.Center }) {
                      Column().width('100%').height(142).backgroundColor(this.templateBackground(item.background)).borderRadius(18)
                      if (item.background.indexOf('bg_') === 0) {
                        Image(AssetResolver.media(item.background)).width('100%').height(142).objectFit(ImageFit.Cover).borderRadius(18)
                      }
                      if (item.defaultAsset.length > 0) {
                        Image(AssetResolver.media(item.defaultAsset)).width('90%').height(136).objectFit(ImageFit.Contain)
                      } else {
                        Text('＋').fontSize(42).fontColor(Theme.colors().brandPrimary)
                      }
                    }.width('100%')
                    Text(item.name).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
                    Text(`${item.category} · ${item.ratio}`).fontSize(11).fontColor(Theme.colors().textSecondary).width('100%')
                  }.width('100%').alignItems(HorizontalAlign.Start).onClick(() => {
                    this.selectedTemplate = item
                    this.editing = true
                    AppStorage.setOrCreate('tabBarHidden', true)
                  })
                }
              }, (item: CreativeTemplate) => item.id)
            }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(18).width('100%')
            Text('我的作品').fontSize(21).fontWeight(FontWeight.Bold).width('100%')
            if (this.savedWorks.length === 0) {
              Column({ space: 8 }) {
                Text('还没有作品').fontSize(16).fontWeight(FontWeight.Medium)
                Text('保存后可再次打开并恢复全部图层').fontSize(12).fontColor(Theme.colors().textSecondary)
              }.padding(28).width('100%').backgroundColor(Theme.colors().surfaceCard).borderRadius(20)
            } else {
              ForEach(this.savedWorks, (work: UserArtwork) => {
                Row({ space: 12 }) {
                  if (work.thumbnailPath.length > 0) {
                    Image('file://' + work.thumbnailPath).width(68).height(68).objectFit(ImageFit.Cover).borderRadius(14)
                  } else {
                    Column() { Text('画').fontSize(30).fontColor(Theme.colors().brandPrimary) }
                      .width(68).height(68).justifyContent(FlexAlign.Center).backgroundColor('#F0DFC1').borderRadius(14)
                  }
                  Column({ space: 5 }) {
                    Text(work.title).fontSize(16).fontWeight(FontWeight.Bold)
                    Text(`${work.layers.length + work.textObjects.length} 个图层 · ${work.canvasWidth}×${work.canvasHeight}`)
                      .fontSize(11).fontColor(Theme.colors().textSecondary)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text('再次编辑 ›').fontSize(12).fontColor(Theme.colors().brandPrimary)
                }.padding(12).backgroundColor(Theme.colors().surfaceCard).borderRadius(18).width('100%')
                  .onClick(() => {
                    this.selectedTemplate = null
                    this.editing = true
                    AppStorage.setOrCreate('tabBarHidden', true)
                    AppStorage.setOrCreate('reopenArtwork', JSON.stringify(work))
                  })
              }, (work: UserArtwork) => work.artworkId)
            }
          }.padding({ left: 16, right: 16, bottom: 30 }).width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
      if (this.editing) {
        ArtworkEditor({
          template: this.selectedTemplate,
          onBack: () => { this.editing = false; AppStorage.setOrCreate('tabBarHidden', false); this.reloadWorks() },
          onSaved: () => this.reloadWorks()
        })
      }
    }.width('100%').height('100%')
  }

  private templateBackground(id: string): string {
    if (id === 'paper-red') return '#E9B3A3'
    if (id === 'paper-gold') return '#EAD3A3'
    if (id === 'paper-teal') return '#BED4C9'
    return '#F2E5CB'
  }
}

@Component
struct ArtworkEditor {
  private backId: number = 0
  @Prop template: CreativeTemplate | null = null
  @State title: string = '我的年画'
  @State backgroundId: string = 'paper-cream'
  @State layers: EditorLayer[] = []
  @State selectedId: string = ''
  @State history: string[] = []
  @State future: string[] = []
  @State panel: number = 0
  @State message: string = ''
  @State artworkId: string = ''
  @State panX: number = 0
  @State panY: number = 0
  @State canvasHeight: number = 900
  @State workspaceWidth: number = 366
  @State workspaceHeight: number = 380
  @State zoom: number = 1
  @State textDraft: string = '新春纳福'
  @State previewing: boolean = false
  @State saving: boolean = false
  @State exporting: boolean = false
  private createdAt: number = 0
  private savedState: string = ''
  private currentExportPath: string = ''
  private currentThumbnailPath: string = ''
  onBack: () => void = () => {}
  onSaved: () => void = () => {}
  private characters: CharacterProfile[] = CultureCatalog.characters()

  aboutToAppear(): void {
    this.backId = BackService.register(() => { this.requestExit(); return true })
    const reopen = AppStorage.get<string>('reopenArtwork') ?? ''
    if (reopen.length > 0) {
      try {
        const work = JSON.parse(reopen) as UserArtwork
        this.artworkId = work.artworkId
        this.title = work.title
        this.backgroundId = work.backgroundId
        this.canvasHeight = work.canvasHeight > 0 ? work.canvasHeight : 900
        this.createdAt = work.createdAt
        this.currentExportPath = work.exportPath
        this.currentThumbnailPath = work.thumbnailPath
        this.layers = work.layers.concat(work.textObjects).map((layer: ArtworkLayer) => EditorLayer.from(layer)).sort((a: EditorLayer, b: EditorLayer) => a.zIndex - b.zIndex)
      } catch {
        this.message = '作品配置异常，已创建空白画布'
      }
      AppStorage.setOrCreate('reopenArtwork', '')
    } else if (this.template !== null) {
      this.backgroundId = this.template.background
      this.canvasHeight = EditorGeometry.heightForRatio(this.template.ratio)
      this.title = this.template.name
      if (this.template.defaultAsset.length > 0) {
        this.addLayer(this.template.defaultAsset, this.template.defaultAsset.indexOf('char_') === 0 ? 'character' : 'motif', '')
      }
    }
    this.savedState = this.serializedState()
  }

  aboutToDisappear(): void { BackService.remove(this.backId) }

  private canvasScale(): number {
    return EditorGeometry.fitScale(MODEL_WIDTH, this.canvasHeight, this.workspaceWidth, this.workspaceHeight, this.zoom)
  }

  private serializedState(): string {
    const state = new EditorSnapshot()
    state.title = this.title
    state.layers = this.layers
    state.backgroundId = this.backgroundId
    state.canvasHeight = this.canvasHeight
    return JSON.stringify(state)
  }

  private restoreState(raw: string): void {
    const state = JSON.parse(raw) as EditorSnapshot
    this.title = state.title
    // ForEach keeps children by layerId: retain the same observed object for existing layers.
    this.layers = state.layers.map((layer: ArtworkLayer) => {
      const existing = this.layers.find((item: EditorLayer) => item.layerId === layer.layerId)
      if (existing !== undefined) { existing.copyFrom(layer); return existing }
      return EditorLayer.from(layer)
    })
    this.backgroundId = state.backgroundId
    this.canvasHeight = state.canvasHeight
    this.selectedId = ''
  }

  private snapshot(): void {
    this.history.push(this.serializedState())
    if (this.history.length > 30) this.history.shift()
    this.future = []
  }

  private addLayer(assetId: string, type: string, text: string): void {
    this.snapshot()
    const layer = new EditorLayer()
    layer.layerId = `layer-${Date.now()}-${this.layers.length}`
    layer.assetId = assetId
    layer.layerType = type
    layer.text = text
    layer.x = 300
    layer.y = (this.canvasHeight - 260) / 2
    layer.width = type === 'text' ? 300 : 260
    layer.height = type === 'text' ? 90 : 260
    layer.zIndex = this.layers.length + 1
    this.layers = this.layers.concat([layer])
    this.selectedId = layer.layerId
  }

  private updateSelected(dx: number, dy: number): void {
    const index = this.layers.findIndex((item: ArtworkLayer) => item.layerId === this.selectedId)
    if (index < 0) return
    const copy = this.layers.slice()
    copy[index].x = EditorGeometry.boundedPosition(copy[index].x, dx, this.canvasScale(), copy[index].width, MODEL_WIDTH)
    copy[index].y = EditorGeometry.boundedPosition(copy[index].y, dy, this.canvasScale(), copy[index].height, this.canvasHeight)
    this.layers = copy
  }

  private dragUpdate(event: GestureEvent): void {
    const dx = event.offsetX - this.panX
    const dy = event.offsetY - this.panY
    this.panX = event.offsetX
    this.panY = event.offsetY
    this.updateSelected(dx, dy)
  }

  private alterSelected(scaleDelta: number, rotationDelta: number): void {
    const index = this.layers.findIndex((item: ArtworkLayer) => item.layerId === this.selectedId)
    if (index < 0) return
    this.snapshot()
    const copy = this.layers.slice()
    const factor = scaleDelta === 0 ? 1 : scaleDelta > 0 ? 1.12 : 1 / 1.12
    const nextWidth = Math.max(60, Math.min(800, copy[index].width * factor))
    copy[index].height = copy[index].height * nextWidth / copy[index].width
    copy[index].width = nextWidth
    copy[index].x = EditorGeometry.boundedPosition(copy[index].x, 0, this.canvasScale(), copy[index].width, MODEL_WIDTH)
    copy[index].y = EditorGeometry.boundedPosition(copy[index].y, 0, this.canvasScale(), copy[index].height, this.canvasHeight)
    copy[index].rotation = (copy[index].rotation + rotationDelta) % 360
    this.layers = copy
  }

  private moveZ(delta: number): void {
    const index = this.layers.findIndex((item: ArtworkLayer) => item.layerId === this.selectedId)
    if (index < 0) return
    this.snapshot()
    const copy = this.layers.slice()
    const nextIndex = Math.max(0, Math.min(copy.length - 1, index + delta))
    const selected = copy.splice(index, 1)[0]
    copy.splice(nextIndex, 0, selected)
    copy.forEach((item: ArtworkLayer, position: number) => { item.zIndex = position + 1 })
    this.layers = copy
  }

  private removeSelected(): void {
    if (this.selectedId.length === 0) return
    this.snapshot()
    this.layers = this.layers.filter((item: ArtworkLayer) => item.layerId !== this.selectedId)
    this.selectedId = ''
  }

  private undo(): void {
    if (this.history.length === 0) return
    this.future.push(this.serializedState())
    this.restoreState(this.history.pop() ?? this.serializedState())
  }

  private redo(): void {
    if (this.future.length === 0) return
    this.history.push(this.serializedState())
    this.restoreState(this.future.pop() ?? this.serializedState())
  }

  private buildArtwork(exportPath: string = this.currentExportPath): UserArtwork {
    const work = new UserArtwork()
    work.artworkId = this.artworkId.length > 0 ? this.artworkId : `artwork-${Date.now()}`
    work.title = this.title.trim().length > 0 ? this.title.trim() : '未命名作品'
    work.canvasWidth = MODEL_WIDTH
    work.canvasHeight = this.canvasHeight
    work.backgroundId = this.backgroundId
    work.layers = this.layers.filter((item: ArtworkLayer) => item.layerType !== 'text')
    work.textObjects = this.layers.filter((item: ArtworkLayer) => item.layerType === 'text')
    work.createdAt = this.createdAt > 0 ? this.createdAt : Date.now()
    work.updatedAt = Date.now()
    work.exportPath = exportPath
    work.thumbnailPath = this.currentThumbnailPath
    return work
  }

  private async save(): Promise<boolean> {
    if (this.saving || this.exporting) return false
    this.saving = true
    const owner = LocalDataStore.ownerId()
    this.selectedId = ''
    const work = this.buildArtwork()
    try {
      await new Promise<void>((resolve) => { setTimeout(() => resolve(), 100) })
      const thumbnail = await ArtworkExportService.capture('artworkCanvas', getContext(this) as common.UIAbilityContext, MODEL_WIDTH, this.canvasHeight)
      if (owner !== LocalDataStore.ownerId()) return false
      if (thumbnail.length > 0) { work.thumbnailPath = thumbnail; this.currentThumbnailPath = thumbnail }
      await LocalDataStore.saveArtwork(work)
      this.artworkId = work.artworkId
      this.createdAt = work.createdAt
      this.savedState = this.serializedState()
      this.message = thumbnail.length > 0 ? '作品配置已保存，可再次编辑' : '作品配置已保存，预览图暂不可用'
      this.onSaved()
      return true
    } catch {
      this.message = '保存失败，请检查本地存储空间'
      return false
    } finally {
      this.saving = false
    }
  }

  private requestExit(): void {
    if (this.savedState === this.serializedState()) { this.onBack(); return }
    AlertDialog.show({
      title: '作品还没有保存', message: '保存完整图层后，可以随时继续编辑。',
      primaryButton: { value: '保存并返回', action: () => { this.save().then((saved: boolean) => { if (saved) this.onBack() }) } },
      secondaryButton: { value: '放弃本次未保存修改', action: () => this.onBack() },
      cancel: () => {}
    })
  }

  private changeRatio(ratio: string): void {
    this.snapshot()
    this.canvasHeight = EditorGeometry.heightForRatio(ratio)
    this.layers = this.layers.map((layer: EditorLayer) => {
      layer.y = EditorGeometry.boundedPosition(layer.y, 0, this.canvasScale(), layer.height, this.canvasHeight)
      return layer
    })
  }

  private updateText(): void {
    const index = this.layers.findIndex((item: ArtworkLayer) => item.layerId === this.selectedId && item.layerType === 'text')
    if (index < 0) { this.message = '请先选中文字图层'; return }
    if (this.textDraft.trim().length === 0) { this.message = '请输入文字内容'; return }
    this.snapshot()
    const copy = this.layers.slice()
    copy[index].text = this.textDraft.trim()
    this.layers = copy
  }

  private async exportImage(): Promise<void> {
    if (this.exporting || this.saving) return
    this.exporting = true
    const owner = LocalDataStore.ownerId()
    this.selectedId = ''
    try {
    await new Promise<void>((resolve) => { setTimeout(() => resolve(), 100) })
    this.message = '正在生成图片…'
    const context = getContext(this) as common.UIAbilityContext
    const path = await ArtworkExportService.capture('artworkCanvas', context, MODEL_WIDTH, this.canvasHeight)
    if (owner !== LocalDataStore.ownerId()) return
    if (path.length === 0) {
      this.message = ArtworkExportService.lastError
      return
    }
    const work = this.buildArtwork(path)
    work.thumbnailPath = path
    this.currentThumbnailPath = path
    this.currentExportPath = path
    await LocalDataStore.saveArtwork(work)
    this.artworkId = work.artworkId
    this.createdAt = work.createdAt
    this.savedState = this.serializedState()
    this.onSaved()
    const saved = await ArtworkExportService.saveToAlbum(context, path, work.title)
    this.message = saved ? '作品已保存到系统相册' : ArtworkExportService.lastError
    } catch {
      this.message = '导出未完成，请重试；本地已保存作品不受影响'
    } finally {
      this.exporting = false
    }
  }

  build() {
    Column() {
      Row({ space: 6 }) {
        Button('‹').fontSize(30).width(44).height(44).backgroundColor('transparent').fontColor(Theme.colors().textPrimary)
          .onClick(() => this.requestExit())
        TextInput({ text: this.title }).onChange((value: string) => this.title = value)
          .fontSize(15).backgroundColor('transparent').layoutWeight(1)
        Button(this.saving ? '保存中' : '保存').fontSize(12).height(38).backgroundColor(Theme.colors().brandPrimary).fontColor('#FFFFFF')
          .enabled(!this.saving && !this.exporting).onClick(() => { void this.save() })
        Button(this.exporting ? '导出中' : '导出').fontSize(12).height(38).backgroundColor(Theme.colors().brandAccent).fontColor('#382D2A')
          .enabled(!this.exporting && !this.saving)
          .onClick(() => { void this.exportImage() })
      }.padding({ left: 8, right: 10, top: 8, bottom: 8 }).width('100%')
      Row({ space: 6 }) {
        this.ToolButton('撤销', () => this.undo())
        this.ToolButton('恢复', () => this.redo())
        this.ToolButton('1:1', () => this.changeRatio('1:1'))
        this.ToolButton('3:4', () => this.changeRatio('3:4'))
        this.ToolButton('9:16', () => this.changeRatio('9:16'))
        this.ToolButton(this.previewing ? '编辑' : '预览', () => { this.previewing = !this.previewing; this.selectedId = '' })
      }.padding({ left: 8, right: 8, bottom: 4 }).width('100%').justifyContent(FlexAlign.SpaceBetween)
      Column() {
        Stack() {
          Column().width(MODEL_WIDTH * this.canvasScale()).height(this.canvasHeight * this.canvasScale()).backgroundColor(this.canvasColor()).borderRadius(4)
          if (this.backgroundId.indexOf('bg_') === 0) {
            Image(AssetResolver.media(this.backgroundId)).width(MODEL_WIDTH * this.canvasScale())
              .height(this.canvasHeight * this.canvasScale()).objectFit(ImageFit.Cover).id('selected-' + this.backgroundId)
          }
          ForEach(this.layers, (layer: EditorLayer) => {
            ArtworkLayerView({
              layer: layer, displayScale: this.canvasScale(), selected: this.selectedId === layer.layerId, previewing: this.previewing,
              onSelect: () => { this.selectedId = layer.layerId; this.textDraft = layer.text },
              onLayerPanStart: () => { this.selectedId = layer.layerId; this.snapshot(); this.panX = 0; this.panY = 0 },
              onDragUpdate: (event: GestureEvent) => this.dragUpdate(event)
            })
          }, (layer: EditorLayer) => layer.layerId)
        }.width(MODEL_WIDTH * this.canvasScale()).height(this.canvasHeight * this.canvasScale()).clip(true).id('artworkCanvas')
      }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).backgroundColor('#D9CDB9')
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.workspaceWidth = Number(newArea.width)
          this.workspaceHeight = Number(newArea.height)
        })
      Row({ space: 8 }) {
        Text(`${MODEL_WIDTH}×${this.canvasHeight} · ${Math.round(this.zoom * 100)}%`).fontSize(11).fontColor(Theme.colors().textSecondary)
        Slider({ value: this.zoom, min: 0.4, max: 1, step: 0.1 }).layoutWeight(1)
          .onChange((value: number) => this.zoom = value)
      }.padding({ left: 12, right: 12 }).height(32).width('100%')
      if (this.selectedId.length > 0) {
        Row({ space: 6 }) {
          this.ToolButton('缩小', () => this.alterSelected(-40, 0))
          this.ToolButton('放大', () => this.alterSelected(40, 0))
          this.ToolButton('旋转', () => this.alterSelected(0, 15))
          this.ToolButton('前移', () => this.moveZ(1))
          this.ToolButton('后移', () => this.moveZ(-1))
          this.ToolButton('删除', () => this.removeSelected())
        }.padding({ left: 8, right: 8, top: 6, bottom: 6 }).width('100%').justifyContent(FlexAlign.SpaceBetween)
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(11).fontColor(Theme.colors().success).padding({ left: 12, right: 12 }).width('100%')
      }
      Row() {
        this.PanelButton('背景', 0)
        this.PanelButton('角色', 1)
        this.PanelButton('纹样', 2)
        this.PanelButton('贴纸', 3)
        this.PanelButton('文字', 4)
        this.PanelButton('图层', 5)
      }.height(48).width('100%').backgroundColor(Theme.colors().surfaceCard)
      Scroll() {
        Row({ space: 10 }) {
          if (this.panel === 0) {
            ForEach(CREATIVE_BACKGROUNDS, (item: CreativeBackground) => {
              Column({ space: 2 }) {
                Image(AssetResolver.media(item.id)).width(60).height(48).objectFit(ImageFit.Cover).borderRadius(8)
                Text(item.name).fontSize(10)
              }.width(72).id('choose-' + item.id)
                .onClick(() => { this.snapshot(); this.backgroundId = item.id })
            }, (item: CreativeBackground) => item.id)
            ForEach(['paper-cream', 'paper-red', 'paper-gold', 'paper-teal'], (id: string) => {
              Column() { Text(id === 'paper-cream' ? '宣纸' : id === 'paper-red' ? '朱砂' : id === 'paper-gold' ? '鎏金' : '青绿').fontSize(12) }
                .width(72).height(56).justifyContent(FlexAlign.Center).backgroundColor(this.colorFor(id)).borderRadius(12)
                .onClick(() => { this.snapshot(); this.backgroundId = id })
            }, (id: string) => id)
          } else if (this.panel === 1) {
            ForEach(this.characters, (item: CharacterProfile) => {
              Column({ space: 2 }) {
                Image(AssetResolver.media(item.image)).width(62).height(52).objectFit(ImageFit.Contain)
                Text(item.name).fontSize(10)
              }.width(72).onClick(() => this.addLayer(item.image, 'character', ''))
            }, (item: CharacterProfile) => item.id)
          } else if (this.panel === 2) {
            ForEach(['motif_cloud', 'motif_peony', 'motif_ruyi', 'motif_coin'], (id: string) => {
              Image(AssetResolver.media(id)).width(60).height(60).objectFit(ImageFit.Contain)
                .onClick(() => this.addLayer(id, 'motif', ''))
            }, (id: string) => id)
          } else if (this.panel === 3) {
            ForEach(['福', '春', '吉', '安'], (name: string) => {
              Button(name).width(54).height(54).fontSize(23).backgroundColor(Theme.colors().brandPrimary).fontColor('#FFFFFF')
                .onClick(() => this.addLayer('', 'sticker', name))
            }, (name: string) => name)
          } else if (this.panel === 4) {
            TextInput({ text: this.textDraft, placeholder: '写一句年画祝福' }).width(180).height(44).maxLength(80)
              .onChange((value: string) => this.textDraft = value)
            Button('添加文字').height(46).backgroundColor(Theme.colors().brandPrimary).fontColor('#FFFFFF')
              .onClick(() => { if (this.textDraft.trim().length > 0) this.addLayer('', 'text', this.textDraft.trim()) })
            Button('更新选中').height(46).backgroundColor(Theme.colors().surfaceCard).fontColor(Theme.colors().brandPrimary)
              .onClick(() => this.updateText())
          } else {
            ForEach(this.layers, (layer: ArtworkLayer, index: number) => {
              Button(`${index + 1} ${layer.layerType}`).height(46).fontSize(11)
                .backgroundColor(this.selectedId === layer.layerId ? Theme.colors().brandPrimary : '#F0E1C5')
                .fontColor(this.selectedId === layer.layerId ? '#FFFFFF' : Theme.colors().textPrimary)
                .onClick(() => this.selectedId = layer.layerId)
            }, (layer: ArtworkLayer) => layer.layerId)
          }
        }.padding({ left: 10, right: 10, top: 8, bottom: 12 })
      }.scrollable(ScrollDirection.Horizontal).height(78).scrollBar(BarState.Off).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder
  ToolButton(label: string, action: () => void) {
    Button(label).height(34).fontSize(10).padding({ left: 9, right: 9 })
      .backgroundColor(label === '删除' ? '#F7D9D4' : Theme.colors().surfaceCard)
      .fontColor(label === '删除' ? Theme.colors().danger : Theme.colors().textPrimary).onClick(action)
  }

  @Builder
  PanelButton(label: string, index: number) {
    Text(label).fontSize(12).fontWeight(this.panel === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.panel === index ? Theme.colors().brandPrimary : Theme.colors().textSecondary)
      .layoutWeight(1).height(48).textAlign(TextAlign.Center).padding({ top: 16 }).onClick(() => this.panel = index)
  }

  private canvasColor(): string { return this.colorFor(this.backgroundId) }
  private colorFor(id: string): string {
    if (id === 'paper-red') return '#E7B0A1'
    if (id === 'paper-gold') return '#E7CEA0'
    if (id === 'paper-teal') return '#BBD1C7'
    return '#FFF8E8'
  }
}
