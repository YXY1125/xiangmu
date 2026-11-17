import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { AuthService } from '../services/AuthService'
import { CoffeeApi } from '../services/CoffeeApi'
import { CoffeeRecord, UserRecipeDraft } from '../models/CoffeeModels'
import { CoffeeMediaService } from '../services/CoffeeMediaService'
import { RemoteCoffeeImage } from '../components/RemoteCoffeeImage'

@Entry
@Component
struct RecipeEditPage {
  @State recordId: string = ''
  @State name: string = ''
  @State bean: string = ''
  @State method: string = '手冲'
  @State ratio: number = 15
  @State temperature: number = 92
  @State steps: string = ''
  @State note: string = ''
  @State message: string = ''
  @State saving: boolean = false
  @State coverKey: string = ''
  @State coverUri: string = ''
  @State uploadingCover: boolean = false

  aboutToAppear(): void {
    const params = AppRouter.getParams(this.getUIContext()) as Record<string, string>
    if (params && params['recordId']) {
      this.recordId = params['recordId']
      CoffeeApi.listUserRecipes().then((result) => {
        if (result.code !== 0 || result.data === undefined) { this.message = result.message; return }
        const row = result.data.items.find((item: CoffeeRecord) => item.id === this.recordId)
        if (!row) { this.message = '没有找到可编辑的配方版本'; return }
        this.name = row.payload.name; this.bean = row.payload.bean; this.method = row.payload.method || '手冲'; this.ratio = row.payload.ratio || 15; this.temperature = row.payload.temperature || 92; this.steps = row.payload.steps; this.note = row.payload.flavor; this.coverKey = row.payload.coverKey
      })
    } else if (params) {
      this.name = params['name'] ?? ''
      this.bean = params['bean'] ?? ''
      this.method = params['method'] ?? '手冲'
      this.ratio = Number(params['ratio'] ?? 15)
      this.temperature = Number(params['temperature'] ?? 92)
      this.steps = params['steps'] ?? ''
      this.note = params['flavor'] ?? ''
    }
  }

  private async save(): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.message = '请先登录后保存个人配方'; return }
    if (this.name.trim().length === 0) { this.message = '请填写配方名称'; return }
    if (this.steps.trim().length === 0) { this.message = '请填写可执行的制作步骤'; return }
    if (this.saving) return
    const draft = new UserRecipeDraft()
    draft.name = this.name.trim(); draft.bean = this.bean.trim(); draft.method = this.method.trim(); draft.ratio = this.ratio; draft.temperature = this.temperature; draft.steps = this.steps.trim(); draft.flavor = this.note.trim(); draft.coverKey = this.coverKey
    this.saving = true
    const result = this.recordId.length > 0 ? await CoffeeApi.updateRecipe(this.recordId, draft) : await CoffeeApi.saveRecipe(draft)
    this.saving = false
    if (result.code === 0 && result.data !== undefined) {
      this.recordId = result.data.id
      this.message = `配方 v${result.data.version} 已保存，统计已同步`
    } else this.message = result.message
  }

  private async pickCover(): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.message = '请先登录后上传配方封面'; return }
    if (this.uploadingCover) return
    this.uploadingCover = true
    this.message = ''
    const result = await CoffeeMediaService.pickAndUpload()
    this.uploadingCover = false
    if (result.error.length > 0) { this.message = result.error; return }
    if (result.key.length === 0) return
    this.coverKey = result.key
    this.coverUri = result.uri
    this.message = '配方封面已安全上传，将随配方保存'
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Text(this.recordId.length > 0 ? '编辑配方版本' : '新建配方').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }) }.width('100%')
        this.Field('配方名称', this.name, '例如：花香耶加 V60', (v: string) => { this.name = v })
        this.Field('咖啡豆', this.bean, '产地 / 品种 / 处理方式', (v: string) => { this.bean = v })
        this.Field('冲煮方式', this.method, '例如：手冲、意式、冷萃', (v: string) => { this.method = v })
        Text('粉水比 1:' + this.ratio).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
        Slider({ value: this.ratio, min: 12, max: 18, step: 1 }).selectedColor(Theme.colors().brandPrimary).onChange((v: number) => { this.ratio = Math.round(v) })
        Text('水温 ' + this.temperature + '℃').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
        Slider({ value: this.temperature, min: 80, max: 98, step: 1 }).selectedColor(Theme.colors().brandPrimary).onChange((v: number) => { this.temperature = Math.round(v) })
        Text('制作步骤').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
        TextArea({ text: this.steps, placeholder: '每行一个步骤，写明注水量与时间' }).height(120).backgroundColor(Theme.colors().surfaceCard).borderRadius(17).onChange((v: string) => { this.steps = v })
        Text('风味与备注').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
        TextArea({ text: this.note, placeholder: '记录风味目标和调整理由' }).height(100).backgroundColor(Theme.colors().surfaceCard).borderRadius(17).onChange((v: string) => { this.note = v })
        if (this.coverUri.length > 0) {
          Image(this.coverUri).width('100%').height(180).objectFit(ImageFit.Cover).borderRadius(18)
        } else if (this.coverKey.length > 0) {
          RemoteCoffeeImage({ imageKey: this.coverKey, label: this.name || '当前配方封面', imageHeight: 180 })
        }
        Button(this.uploadingCover ? '正在上传封面…' : (this.coverKey.length > 0 ? '更换配方封面' : '选择配方封面（可选）'))
          .enabled(!this.uploadingCover && !this.saving).width('100%').height(46).backgroundColor(Theme.colors().brandAccent).borderRadius(18).onClick(() => this.pickCover())
        if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor(this.message.includes('已保存') ? Theme.colors().success : Theme.colors().danger).width('100%') }
        Button(this.saving ? '正在保存…' : (this.recordId.length > 0 ? '保存新版本' : '创建配方')).enabled(!this.saving && !this.uploadingCover).width('100%').backgroundColor(Theme.colors().brandPrimary).borderRadius(20).onClick(() => this.save())
        Text('每次修改创建新版本；历史版本保留且不物理删除。').fontSize(10).fontColor(Theme.colors().textTertiary).margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
  @Builder Field(label: string, value: string, placeholder: string, change: (value: string) => void) { Column({ space: 6 }) { Text(label).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%'); TextInput({ text: value, placeholder: placeholder }).height(48).backgroundColor(Theme.colors().surfaceCard).borderRadius(16).onChange(change) }.width('100%') }
}
