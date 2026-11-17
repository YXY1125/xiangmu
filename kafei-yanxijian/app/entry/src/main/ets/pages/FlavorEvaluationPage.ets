import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { FlavorScores } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'
import { AuthService } from '../services/AuthService'
import { FlavorScoreSlider } from '../components/design-system/FlavorScoreSlider'
@Entry
@Component
struct FlavorEvaluationPage {
  @State bean: string = ''
  @State method: string = '手冲'
  @State tags: string[] = []
  @State acidity: number = 3
  @State sweetness: number = 3
  @State bitterness: number = 3
  @State body: number = 3
  @State aroma: number = 3
  @State aftertaste: number = 3
  @State overall: number = 3
  @State note: string = ''
  @State message: string = ''
  @State saving: boolean = false
  private toggle(tag: string): void { this.tags = this.tags.includes(tag) ? this.tags.filter((v: string) => v !== tag) : this.tags.concat([tag]) }
  private scores(): FlavorScores { const s = new FlavorScores(); s.acidity = this.acidity; s.sweetness = this.sweetness; s.bitterness = this.bitterness; s.body = this.body; s.aroma = this.aroma; s.aftertaste = this.aftertaste; s.overall = this.overall; return s }
  private async save(): Promise<void> { if (!AuthService.isLoggedIn()) { this.message = '请先登录后保存测评'; return }; if (this.bean.trim().length === 0) { this.message = '请填写咖啡豆'; return }; if (this.saving) return; this.saving = true; const result = await CoffeeApi.saveEvaluation(this.bean.trim(), this.method, this.tags, this.scores(), this.note.trim()); this.saving = false; if (result.code === 0) { AppRouter.push(this.getUIContext(), { url: 'pages/FlavorReportPage', params: { average: this.scores().average(), tags: this.tags.join('、') } }) } else { this.message = result.message } }
  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
          Text('风味测评').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 })
        }.width('100%')
        Stack() {
          Image($r('app.media.cover_flavor_cupping')).width('100%').height(176).objectFit(ImageFit.Cover)
          Column().width('100%').height(176)
            .linearGradient({ angle: 180, colors: [['#00241B17', 0.25], ['#B3241B17', 1]] })
          Column({ space: 4 }) {
            Text('SENSORY NOTES').fontSize(10).fontWeight(FontWeight.Bold).fontColor('#F3EBDD')
            Text('记录你真实感受的强度').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          }.width('100%').height(176).padding(16).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Start)
        }.width('100%').height(176).clip(true).borderRadius(22)
        TextInput({ text: this.bean, placeholder: '咖啡豆 / 批次' })
          .height(48).backgroundColor(Theme.colors().surfaceCard).borderRadius(16)
          .onChange((v: string) => { this.bean = v })
        Text('风味标签（可多选）').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(['柑橘','柠檬','橙子','莓果','蓝莓','草莓','花香','茉莉','蜂蜜','焦糖','巧克力','坚果','香料','茶感'], (tag: string) => {
            Text(tag).fontSize(12)
              .fontColor(this.tags.includes(tag) ? Color.White : Theme.colors().textPrimary)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .margin({ right: 7, bottom: 7 })
              .backgroundColor(this.tags.includes(tag) ? Theme.colors().brandPrimary : Theme.colors().surfaceCard)
              .borderRadius(15).onClick(() => this.toggle(tag))
          })
        }.width('100%')
        Text('七维评分 · 1 低 / 5 高').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
        FlavorScoreSlider({ label: '酸度强度', value: $acidity })
        FlavorScoreSlider({ label: '甜感', value: $sweetness })
        FlavorScoreSlider({ label: '苦味强度', value: $bitterness })
        FlavorScoreSlider({ label: '醇厚度', value: $body })
        FlavorScoreSlider({ label: '香气', value: $aroma })
        FlavorScoreSlider({ label: '余韵', value: $aftertaste })
        FlavorScoreSlider({ label: '整体满意度', value: $overall })
        TextArea({ text: this.note, placeholder: '写下个人感受；本评分不是统一专业杯测分数' })
          .height(110).backgroundColor(Theme.colors().surfaceCard).borderRadius(17)
          .onChange((v: string) => { this.note = v })
        if (this.message.length > 0) {
          Text(this.message).fontSize(13).fontColor(Theme.colors().danger).width('100%')
        }
        Button(this.saving ? '正在保存并同步…' : '保存并生成报告').enabled(!this.saving).width('100%').backgroundColor(Theme.colors().brandPrimary).borderRadius(20).onClick(() => this.save())
        Text('各维度仅表达个人感受强度，不能替代专业杯测标准。').fontSize(10).fontColor(Theme.colors().textTertiary).margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
