import { Theme } from '../components/design-system/Theme'
import { StudioAsset } from '../components/StudioAsset'
import { FlowerChallenge, FlowerTheme, PagePayload, StudioObject, StudioSnapshot } from '../models/FlowerModels'
import { FlowerApiService } from '../services/FlowerApiService'
import { SessionStore } from '../services/SessionStore'

class MaterialChoice {
  key: string = ''
  id: string = ''
  name: string = ''
  atlasKey: string = ''
  atlasIndex: number = 0
  static all(): MaterialChoice[] {
    const values: MaterialChoice[] = []
    const keys = ['rose', 'tulip', 'lily', 'peony', 'babys_breath', 'eucalyptus']
    const ids = ['rose', 'tulip', 'lily', 'peony', 'gypsophila', 'eucalyptus']
    const names = ['玫瑰', '郁金香', '百合', '牡丹', '满天星', '尤加利叶']
    keys.forEach((key: string, index: number) => {
      const value = new MaterialChoice(); value.key = key; value.id = ids[index]; value.name = names[index]; values.push(value)
    })
    const decorNames = ['牛皮纸包装', '粉色丝带', '珍珠装饰', '祝福卡片']
    const decorIds = ['decor-wrap', 'decor-ribbon', 'decor-pearl', 'decor-card']
    decorNames.forEach((name: string, index: number) => { const value = new MaterialChoice(); value.key = 'decor'; value.id = decorIds[index]; value.name = name; value.atlasKey = 'decorations'; value.atlasIndex = index; values.push(value) })
    return values
  }
}

@Component
export struct WorkshopPage {
  @Prop seedMaterialIds: string[] = []
  @Prop initialWorkId: string = ''
  @Prop initialWorkTitle: string = ''
  @Prop initialSnapshotJson: string = ''
  @State private objects: StudioObject[] = []
  @State private selectedId: string = ''
  @State private canvasBackground: string = 'cream'
  @State private container: string = 'vase'
  @State private notice: string = '选择花材开始创作'
  @State private preview: boolean = false
  @State private saving: boolean = false
  @State private mode: string = 'free'
  @State private themeName: string = '自由创作'
  @State private challengeId: string = ''
  @State private themes: FlowerTheme[] = []
  @State private challenges: FlowerChallenge[] = []
  @State private canvasRevision: number = 0
  private history: string[] = []
  private future: string[] = []
  private choices: MaterialChoice[] = MaterialChoice.all()
  private gestureStartX: number = 0
  private gestureStartY: number = 0
  private gestureStartScale: number = 1
  private gestureStartRotation: number = 0
  private gestureActive: boolean = false
  onRequireAuth: () => void = () => {}
  onDataChanged: () => void = () => {}

  aboutToAppear(): void {
    FlowerApiService.themes().then((response) => { if (response.code === 0 && response.data !== undefined) this.themes = (response.data as PagePayload<FlowerTheme>).items })
    FlowerApiService.challenges().then((response) => { if (response.code === 0 && response.data !== undefined) this.challenges = (response.data as PagePayload<FlowerChallenge>).items })
    if (this.initialSnapshotJson.length > 0 && this.restore(this.initialSnapshotJson)) {
      this.notice = `继续编辑 · ${this.initialWorkTitle}`
      return
    }
    SessionStore.readLocalState('flower_studio_draft').then((raw: string) => {
      if (raw.length > 0 && this.restore(raw)) this.notice = `已恢复草稿 · ${this.objects.length} 个图层`
      if (this.seedMaterialIds.length > 0) {
        this.seedMaterialIds.forEach((id: string) => {
          const found = this.choices.find((choice: MaterialChoice) => choice.id === id)
          if (found !== undefined) this.add(found)
          else FlowerApiService.material(id).then((response) => {
            if (response.code === 0 && response.data !== undefined) {
              const choice = new MaterialChoice(); choice.id = response.data.id; choice.name = response.data.name; choice.key = 'atlas'; choice.atlasKey = response.data.atlasKey; choice.atlasIndex = response.data.atlasIndex
              this.add(choice)
            } else this.notice = response.message
          })
        })
      }
    })
  }

  private addMaterialIds(ids: string[]): void {
    ids.forEach((id: string) => {
      const found = this.choices.find((choice: MaterialChoice) => choice.id === id)
      if (found !== undefined) this.add(found)
      else FlowerApiService.material(id).then((response) => {
        if (response.code === 0 && response.data !== undefined) {
          const choice = new MaterialChoice(); choice.id = response.data.id; choice.name = response.data.name; choice.key = 'atlas'; choice.atlasKey = response.data.atlasKey; choice.atlasIndex = response.data.atlasIndex; this.add(choice)
        }
      })
    })
  }

  private snapshot(): StudioSnapshot {
    const value = new StudioSnapshot(); value.background = this.canvasBackground; value.container = this.container; value.objects = this.objects
    return value
  }

  private serialize(): string { return JSON.stringify(this.snapshot()) }

  private restore(raw: string): boolean {
    try {
      const source = JSON.parse(raw) as StudioSnapshot
      const restored: StudioObject[] = []
      source.objects.forEach((item: StudioObject) => {
        const value = new StudioObject()
        value.materialId = item.materialId; value.objectId = item.objectId; value.name = item.name; value.assetKey = item.assetKey
        value.atlasKey = item.atlasKey ?? ''; value.atlasIndex = item.atlasIndex ?? 0
        value.x = item.x; value.y = item.y; value.scale = item.scale; value.rotation = item.rotation; value.zIndex = item.zIndex
        restored.push(value)
      })
      this.canvasBackground = source.background; this.container = source.container; this.objects = restored
      this.selectedId = restored.length > 0 ? restored[restored.length - 1].objectId : ''
      this.canvasRevision++
      return true
    } catch { return false }
  }

  private checkpoint(): void {
    this.history.push(this.serialize())
    if (this.history.length > 30) this.history.shift()
    this.future = []
  }

  private add(choice: MaterialChoice): void {
    this.checkpoint()
    const item = new StudioObject()
    item.materialId = choice.id; item.objectId = `${choice.id}_${Date.now()}`; item.name = choice.name; item.assetKey = choice.key; item.atlasKey = choice.atlasKey; item.atlasIndex = choice.atlasIndex
    item.x = 72 + (this.objects.length % 4) * 30; item.y = 70 + (this.objects.length % 3) * 26
    item.scale = choice.key === 'eucalyptus' ? 0.65 : 0.72; item.rotation = this.objects.length % 2 === 0 ? -8 : 9; item.zIndex = this.objects.length + 1
    this.objects = this.objects.concat([item]); this.selectedId = item.objectId; this.canvasRevision++; this.notice = `已添加${choice.name}`; void this.persist()
  }

  private selected(): StudioObject | undefined { return this.objects.find((item: StudioObject) => item.objectId === this.selectedId) }

  private copyObject(source: StudioObject): StudioObject {
    const target = new StudioObject()
    target.materialId = source.materialId; target.objectId = source.objectId; target.name = source.name
    target.assetKey = source.assetKey; target.atlasKey = source.atlasKey; target.atlasIndex = source.atlasIndex
    target.x = source.x; target.y = source.y; target.scale = source.scale; target.rotation = source.rotation; target.zIndex = source.zIndex
    return target
  }

  private updateTransform(objectId: string, x: number, y: number, scale: number, rotation: number): void {
    this.objects = this.objects.map((source: StudioObject) => {
      const target = this.copyObject(source)
      if (target.objectId === objectId) {
        target.x = x; target.y = y; target.scale = scale; target.rotation = rotation
      }
      return target
    })
    this.canvasRevision++
  }

  private beginTransform(item: StudioObject): void {
    this.gestureStartX = item.x; this.gestureStartY = item.y
    this.gestureStartScale = item.scale; this.gestureStartRotation = item.rotation
    this.selectedId = item.objectId
    if (!this.gestureActive) { this.gestureActive = true; this.checkpoint() }
  }

  private endTransform(): void { this.gestureActive = false; void this.persist() }

  private deleteSelected(): void {
    if (this.selectedId.length === 0) { this.notice = '请先选中一个素材'; return }
    this.checkpoint(); this.objects = this.objects.filter((item: StudioObject) => item.objectId !== this.selectedId)
    this.objects.forEach((item: StudioObject, index: number) => item.zIndex = index + 1)
    this.selectedId = this.objects.length > 0 ? this.objects[this.objects.length - 1].objectId : ''; this.canvasRevision++; this.notice = '已删除素材'; void this.persist()
  }

  private moveLayer(delta: number): void {
    const current = this.objects.findIndex((item: StudioObject) => item.objectId === this.selectedId)
    if (current < 0) { this.notice = '请先选中一个素材'; return }
    const target = Math.max(0, Math.min(this.objects.length - 1, current + delta))
    if (target === current) { this.notice = delta > 0 ? '已经在最上层' : '已经在最下层'; return }
    this.checkpoint()
    const reordered = this.objects.map((item: StudioObject) => this.copyObject(item))
    const moving = reordered.splice(current, 1)[0]
    reordered.splice(target, 0, moving)
    reordered.forEach((item: StudioObject, index: number) => item.zIndex = index + 1)
    this.objects = reordered; this.canvasRevision++; this.notice = delta > 0 ? '图层已上移' : '图层已下移'; void this.persist()
  }

  private undo(): void {
    const raw = this.history.pop(); if (raw === undefined) { this.notice = '没有可撤销的操作'; return }
    this.future.push(this.serialize()); this.restore(raw); this.notice = '已撤销'; void this.persist()
  }

  private redo(): void {
    const raw = this.future.pop(); if (raw === undefined) { this.notice = '没有可重做的操作'; return }
    this.history.push(this.serialize()); this.restore(raw); this.notice = '已重做'; void this.persist()
  }

  private clear(): void { if (this.objects.length === 0) return; this.checkpoint(); this.objects = []; this.selectedId = ''; this.canvasRevision++; this.notice = '画布已清空'; void this.persist() }

  private async persist(): Promise<void> { await SessionStore.saveLocalState('flower_studio_draft', this.serialize()) }

  private async save(status: string): Promise<void> {
    const token = AppStorage.get<string>('accessToken') ?? ''
    if (token.length === 0) { this.onRequireAuth(); return }
    if (this.objects.length === 0) { this.notice = '请先完成一件花艺作品'; return }
    this.saving = true
    const title = this.initialWorkTitle.length > 0 ? this.initialWorkTitle : `我的花艺 · ${new Date().toLocaleDateString()}`
    const response = this.initialWorkId.length > 0 ? await FlowerApiService.updateWork(this.initialWorkId, title, status, this.snapshot(), this.themeName, this.challengeId) : await FlowerApiService.saveWork(title, status, this.snapshot(), this.themeName, this.challengeId)
    this.saving = false
    if (response.code === 0) {
      this.notice = status === 'published' ? '作品已发布到花园' : '草稿已同步保存'
      this.onDataChanged()
    } else this.notice = response.message
  }

  build() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text('花艺工坊').fontSize(26).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
          Text(this.notice).fontSize(12).fontColor(Theme.colors().textSecondary).maxLines(1)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button(this.preview ? '继续编辑' : '预览').fontSize(12).height(34).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.preview = !this.preview)
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          Scroll() {
            Row({ space: 8 }) {
              this.ModeChip('free', '自由插花')
              this.ModeChip('theme', '主题创作')
              this.ModeChip('challenge', '花束挑战')
              this.ModeChip('editing', '我的作品编辑')
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')

          if (this.mode === 'theme') {
            Scroll() { Row({ space: 10 }) { ForEach(this.themes, (theme: FlowerTheme) => { Column({ space: 5 }) { Text(theme.name).fontSize(14).fontWeight(FontWeight.Bold).width(178); Text(theme.introduction).fontSize(10).fontColor(Theme.colors().textSecondary).maxLines(2).width(178); Text(theme.requirements.join(' · ')).fontSize(9).fontColor('#D98B91').maxLines(2).width(178) }.alignItems(HorizontalAlign.Start).width(194).height(116).padding(8).backgroundColor(this.themeName === theme.name ? '#F4DED7' : '#FFFEFA').borderRadius(16).onClick(() => { this.themeName = theme.name; this.challengeId = ''; this.addMaterialIds(theme.recommendedMaterialIds) }) }, (theme: FlowerTheme) => theme.id) } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
          }
          if (this.mode === 'challenge') {
            Scroll() { Row({ space: 10 }) { ForEach(this.challenges, (challenge: FlowerChallenge) => { Column({ space: 5 }) { Text(challenge.name).fontSize(14).fontWeight(FontWeight.Bold).width(178); Text(challenge.introduction).fontSize(10).fontColor(Theme.colors().textSecondary).maxLines(2).width(178); Text(challenge.requirements.join(' · ')).fontSize(9).fontColor('#D98B91').maxLines(2).width(178) }.alignItems(HorizontalAlign.Start).width(194).height(116).padding(8).backgroundColor(this.challengeId === challenge.id ? '#F4DED7' : '#FFFEFA').borderRadius(16).onClick(() => { this.challengeId = challenge.id; this.themeName = challenge.name; this.addMaterialIds(challenge.recommendedMaterialIds) }) }, (challenge: FlowerChallenge) => challenge.id) } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
          }
          Stack({ alignContent: Alignment.TopStart }) {
            if (this.canvasBackground === 'garden') Image($r('app.media.banner_workshop')).width('100%').height(370).objectFit(ImageFit.Cover).opacity(0.55)
            if (this.canvasBackground === 'cream') Column().width('100%').height(370).linearGradient({ angle: 135, colors: [['#FFF8EE', 0], ['#F4DED7', 1]] })
            Image(this.container === 'basket' ? $r('app.media.container_basket') : $r('app.media.empty_vase')).width(this.container === 'basket' ? 240 : 150).height(170).objectFit(ImageFit.Contain).position({ x: this.container === 'basket' ? 50 : 92, y: 205 })
            if (this.canvasRevision % 2 === 0) this.CanvasObjectsLayer()
            else this.CanvasObjectsLayerAlternate()
          }.width('100%').height(370).borderRadius(24).clip(true).backgroundColor('#FFF8EE')

          if (!this.preview) {
            Row({ space: 8 }) {
              Button('撤销').layoutWeight(1).height(40).fontSize(11).onClick(() => this.undo())
              Button('重做').layoutWeight(1).height(40).fontSize(11).onClick(() => this.redo())
              Button('删除').layoutWeight(1).height(40).fontSize(11).onClick(() => this.deleteSelected())
              Button('清空').layoutWeight(1).height(40).fontSize(11).backgroundColor('#F2D6D6').fontColor('#8A3340').onClick(() => this.clear())
            }.width('100%')
            Row({ space: 10 }) {
              Button(this.canvasBackground === 'cream' ? '花园背景' : '奶油背景').layoutWeight(1).height(42).fontSize(12).onClick(() => { this.checkpoint(); this.canvasBackground = this.canvasBackground === 'cream' ? 'garden' : 'cream'; void this.persist() })
              Button(this.container === 'vase' ? '换花篮' : '换花瓶').layoutWeight(1).height(42).fontSize(12).onClick(() => { this.checkpoint(); this.container = this.container === 'vase' ? 'basket' : 'vase'; void this.persist() })
            }.width('100%')
            Text('花材库').fontSize(18).fontWeight(FontWeight.Bold).width('100%').fontColor(Theme.colors().textPrimary)
            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.choices, (choice: MaterialChoice) => {
                  Column({ space: 5 }) {
                    Image(StudioAssetImage(choice.key)).width(64).height(72).objectFit(ImageFit.Contain)
                    Text(choice.name).fontSize(12).fontColor(Theme.colors().textPrimary)
                  }.width(82).height(104).padding(6).backgroundColor('#FFFEFA').borderRadius(16).onClick(() => this.add(choice))
                }, (choice: MaterialChoice) => choice.id)
              }
            }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
          }

          Row({ space: 10 }) {
            Button(this.saving ? '保存中…' : '保存草稿').layoutWeight(1).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => { if (!this.saving) void this.save('draft') })
            Button(this.saving ? '发布中…' : '发布作品').layoutWeight(1).backgroundColor('#496B55').onClick(() => { if (!this.saving) void this.save('published') })
          }.width('100%')
        }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder ModeChip(value: string, label: string) {
    Text(label).fontSize(11).fontColor(this.mode === value ? '#FFFFFF' : '#496B55').padding({ left: 15, right: 15, top: 8, bottom: 8 }).backgroundColor(this.mode === value ? '#496B55' : '#E2EBDD').borderRadius(99).onClick(() => { this.mode = value; if (value === 'free') { this.themeName = '自由创作'; this.challengeId = '' } })
  }

  @Builder CanvasObject(item: StudioObject) {
    Stack({ alignContent: Alignment.TopStart }) {
      if (item.atlasKey.length > 0) {
        if (item.atlasKey === 'decorations') {
          Image(StudioAsset.atlas(item.atlasKey)).width(448).height(150).objectFit(ImageFit.Fill).draggable(false).position({ x: -item.atlasIndex * 112, y: 0 })
        } else {
          Image(StudioAsset.atlas(item.atlasKey)).width(560).height(224).objectFit(ImageFit.Fill).draggable(false).position({ x: -(item.atlasIndex % 5) * 112, y: -Math.floor(item.atlasIndex / 5) * 112 })
        }
      } else {
        Image(StudioAsset.image(item.assetKey)).width(112).height(150).objectFit(ImageFit.Contain).draggable(false)
      }
    }
      .width(112).height(150).clip(true)
      .position({ x: item.x, y: item.y })
      .scale({ x: item.scale, y: item.scale })
      .rotate({ angle: item.rotation })
      .border({ width: !this.preview && item.objectId === this.selectedId ? 2 : 0, color: '#D98B91' })
      .borderRadius(12)
      .onClick(() => { if (!this.preview) this.selectedId = item.objectId })
      .priorityGesture(GestureGroup(GestureMode.Parallel,
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 2 })
          .onActionStart(() => { if (!this.preview) this.beginTransform(item) })
          .onActionUpdate((event: GestureEvent) => {
            if (!this.preview) this.updateTransform(item.objectId,
              Math.max(-36, Math.min(252, this.gestureStartX + event.offsetX)),
              Math.max(-54, Math.min(250, this.gestureStartY + event.offsetY)),
              this.gestureStartScale, this.gestureStartRotation)
          })
          .onActionEnd(() => { if (!this.preview) this.endTransform() }),
        PinchGesture({ fingers: 2, distance: 3 })
          .onActionStart(() => { if (!this.preview) this.beginTransform(item) })
          .onActionUpdate((event: GestureEvent) => {
            if (!this.preview) this.updateTransform(item.objectId, this.gestureStartX, this.gestureStartY,
              Math.max(0.3, Math.min(1.8, this.gestureStartScale * event.scale)), this.gestureStartRotation)
          })
          .onActionEnd(() => { if (!this.preview) this.endTransform() }),
        RotationGesture({ fingers: 2, angle: 2 })
          .onActionStart(() => { if (!this.preview) this.beginTransform(item) })
          .onActionUpdate((event: GestureEvent) => {
            if (!this.preview) this.updateTransform(item.objectId, this.gestureStartX, this.gestureStartY,
              this.gestureStartScale, this.gestureStartRotation + event.angle)
          })
          .onActionEnd(() => { if (!this.preview) this.endTransform() })
      ))
    if (!this.preview && item.objectId === this.selectedId) {
      Text(item.name).fontSize(10).fontColor('#8A3340').padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .backgroundColor('rgba(255,248,238,0.88)').borderRadius(8)
        .position({ x: item.x, y: Math.max(0, item.y - 18) })
    }
  }

  @Builder CanvasObjectsLayer() {
    ForEach(this.objects, (item: StudioObject) => {
      this.CanvasObject(item)
    }, (item: StudioObject) => item.objectId)
  }

  @Builder CanvasObjectsLayerAlternate() {
    ForEach(this.objects, (item: StudioObject) => {
      this.CanvasObject(item)
    }, (item: StudioObject) => item.objectId)
  }
}

function StudioAssetImage(key: string): Resource {
  if (key === 'tulip') return $r('app.media.material_tulip')
  if (key === 'lily') return $r('app.media.material_lily')
  if (key === 'peony') return $r('app.media.material_peony')
  if (key === 'eucalyptus') return $r('app.media.material_eucalyptus')
  if (key === 'babys_breath') return $r('app.media.material_babys_breath')
  return $r('app.media.material_rose')
}
