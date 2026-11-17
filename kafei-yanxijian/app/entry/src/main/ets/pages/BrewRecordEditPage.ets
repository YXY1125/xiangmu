import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { BrewRecordDraft } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'
import { AuthService } from '../services/AuthService'
import { CoffeeMediaService } from '../services/CoffeeMediaService'

@Entry
@Component
struct BrewRecordEditPage {
  @State coffeeName: string = ''
  @State bean: string = ''
  @State note: string = ''
  @State dose: number = 15
  @State water: number = 225
  @State temperature: number = 92
  @State durationSeconds: number = 150
  @State method: string = '手冲'
  @State grind: string = '中细研磨'
  @State equipment: string = 'V60'
  @State message: string = ''
  @State saving: boolean = false
  @State imageKey: string = ''
  @State imageUri: string = ''
  @State uploadingImage: boolean = false
  aboutToAppear(): void {
    const params = AppRouter.getParams(this.getUIContext()) as Record<string, Object>
    if (params) {
      this.dose = Number(params['dose'] ?? 15)
      this.water = Number(params['water'] ?? 225)
      this.temperature = Number(params['temperature'] ?? 92)
      if (params['method']) this.method = `${params['method']}`
    }
  }
  private async save(): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.message = '请先登录后保存个人制作记录'; return }
    if (this.coffeeName.trim().length === 0) { this.message = '请填写咖啡名称'; return }
    if (this.saving) return
    const record = new BrewRecordDraft()
    record.coffeeName = this.coffeeName.trim(); record.bean = this.bean.trim(); record.dose = this.dose; record.water = this.water; record.temperature = this.temperature; record.durationSeconds = this.durationSeconds; record.method = this.method.trim(); record.grind = this.grind.trim(); record.equipment = this.equipment.trim(); record.note = this.note.trim(); record.imageKey = this.imageKey
    this.saving = true
    const result = await CoffeeApi.saveBrew(record)
    this.saving = false
    this.message = result.code === 0 ? '制作记录已保存' : result.message
  }
  private async pickImage(): Promise<void> {
    if (!AuthService.isLoggedIn()) { this.message = '请先登录后上传制作图片'; return }
    if (this.uploadingImage) return
    this.uploadingImage = true
    this.message = ''
    const result = await CoffeeMediaService.pickAndUpload()
    this.uploadingImage = false
    if (result.error.length > 0) { this.message = result.error; return }
    if (result.key.length === 0) return
    this.imageKey = result.key
    this.imageUri = result.uri
    this.message = '制作图片已安全上传，将随记录保存'
  }
  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Text('新建制作记录').fontSize(25).fontWeight(FontWeight.Bold).margin({ left: 12 }) }.width('100%')
        this.Field('咖啡名称', this.coffeeName, '例如：周末耶加雪菲', (v: string) => { this.coffeeName = v })
        this.Field('咖啡豆', this.bean, '产地 / 品种 / 处理方式', (v: string) => { this.bean = v })
        this.Field('冲煮方式', this.method, '例如：手冲、法压壶', (v: string) => { this.method = v })
        this.Field('研磨程度', this.grind, '例如：中细研磨', (v: string) => { this.grind = v })
        this.Field('使用器具', this.equipment, '例如：V60、电子秤', (v: string) => { this.equipment = v })
        Row({ space: 8 }) { this.Metric('粉量', `${this.dose}g`); this.Metric('水量', `${this.water}ml`); this.Metric('水温', `${this.temperature}℃`) }.width('100%')
        Text(`冲煮时间 ${this.durationSeconds} 秒`).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
        Slider({ value: this.durationSeconds, min: 30, max: 900, step: 5 }).selectedColor(Theme.colors().brandPrimary).onChange((value: number) => { this.durationSeconds = Math.round(value) })
        Text('实际制作感受').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
        TextArea({ text: this.note, placeholder: '记录香气、流速、口感和下一次调整方向' }).height(130).backgroundColor(Theme.colors().surfaceCard).borderRadius(18).onChange((v: string) => { this.note = v })
        if (this.imageUri.length > 0) {
          Image(this.imageUri).width('100%').height(180).objectFit(ImageFit.Cover).borderRadius(18)
        }
        Button(this.uploadingImage ? '正在上传图片…' : (this.imageKey.length > 0 ? '重新选择制作图片' : '选择制作图片（可选）'))
          .enabled(!this.uploadingImage && !this.saving).width('100%').height(46).backgroundColor(Theme.colors().brandAccent).borderRadius(18).onClick(() => this.pickImage())
        if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor(this.message.includes('已保存') ? Theme.colors().success : Theme.colors().danger).width('100%') }
        Button(this.saving ? '正在保存并同步…' : '保存制作记录').enabled(!this.saving && !this.uploadingImage).width('100%').height(50).backgroundColor(Theme.colors().brandPrimary).borderRadius(20).onClick(() => this.save())
        Text('业务记录仅允许归档或版本化，不提供物理删除。').fontSize(11).fontColor(Theme.colors().textTertiary).margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
  @Builder Field(label: string, value: string, placeholder: string, change: (value: string) => void) { Column({ space: 6 }) { Text(label).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%'); TextInput({ text: value, placeholder: placeholder }).height(48).backgroundColor(Theme.colors().surfaceCard).borderRadius(16).onChange(change) }.width('100%') }
  @Builder Metric(label: string, value: string) { Column({ space: 3 }) { Text(value).fontSize(17).fontWeight(FontWeight.Bold); Text(label).fontSize(10).fontColor(Theme.colors().textSecondary) }.layoutWeight(1).padding(14).backgroundColor('#EAD9C5').borderRadius(16) }
}
