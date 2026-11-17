import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeApi } from '../services/CoffeeApi'
import { CoffeeMetricCard } from '../components/design-system/CoffeeMetricCard'

@Component
export struct LabPage {
  @StorageLink('coffeeDataRevision') @Watch('onRevision') revision: number = 0
  @StorageLink('accessToken') @Watch('onSessionChanged') accessToken: string = ''
  @State brewCount: number = 0
  @State evaluationCount: number = 0
  onRequireAuth: () => void = () => {}
  aboutToAppear(): void { this.loadSummary() }
  private onRevision(): void { this.loadSummary() }
  private onSessionChanged(): void { this.loadSummary() }
  private loadSummary(): void {
    if (this.accessToken.length === 0) { this.brewCount = 0; this.evaluationCount = 0; return }
    CoffeeApi.growth().then((result) => { if (result.code === 0 && result.data !== undefined) { this.brewCount = result.data.brewCount; this.evaluationCount = result.data.evaluationCount } })
  }
  private privateRoute(url: string): void { if (this.accessToken.length === 0) { this.onRequireAuth(); return }; AppRouter.push(this.getUIContext(), { url: url }) }
  build() {
    Scroll() {
      Column({ space: 18 }) {
        Text('制作实验室').fontSize(30).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
        Stack() {
          Image($r('app.media.banner_brewing_lab')).width('100%').height(272).objectFit(ImageFit.Cover)
          Column().width('100%').height(272)
            .linearGradient({ angle: 90, colors: [['#E6241B17', 0], ['#66241B17', 0.7], ['#11241B17', 1]] })
          Column({ space: 10 }) {
            Text('BREW CALCULATOR').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#F3EBDD').width('100%')
            Text('粉、水、时间\n都应该能被解释').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#F3EBDD').width('100%')
            Text('输入粉量和比例，实时得到总水量与分段注水建议。').fontSize(13).fontColor('#EFE1CE').width('100%')
            Button('打开冲煮计算器').backgroundColor('#B47A43').fontColor(Color.White).borderRadius(22)
              .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/BrewCalculatorPage' }))
          }.width('100%').height(272).padding(22).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Start)
        }.width('100%').height(272).clip(true).borderRadius(26)
        Text('制作方式').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
        Row({ space: 8 }) {
          CoffeeMetricCard({ label: '制作记录', value: this.brewCount }).layoutWeight(1)
          CoffeeMetricCard({ label: '风味测评', value: this.evaluationCount }).layoutWeight(1)
        }.width('100%')
        ForEach(['手冲咖啡', '意式浓缩', '冷萃咖啡', '法压壶', '摩卡壶', '爱乐压'], (method: string, index: number) => {
          Row() {
            Text(`${index + 1}`.padStart(2, '0')).fontSize(12).fontColor(Theme.colors().brandPrimary).width(34)
            Column({ space: 3 }) { Text(method).fontSize(17).fontWeight(FontWeight.Bold); Text(index === 0 ? '闷蒸 · 分段注水 · 流速控制' : '器具 · 参数 · 步骤 · 常见错误').fontSize(12).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(24).fontColor(Theme.colors().brandPrimary)
          }.padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(17)
            .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/BrewingGuidePage', params: { method: method } }))
        })
        Row({ space: 10 }) {
          Button('新建制作记录').layoutWeight(1).height(48).backgroundColor(Theme.colors().brandPrimary).borderRadius(18)
            .onClick(() => this.privateRoute('pages/BrewRecordEditPage'))
          Button('风味测评').layoutWeight(1).height(48).fontColor(Theme.colors().brandPrimary).backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
            .onClick(() => this.privateRoute('pages/FlavorEvaluationPage'))
        }.width('100%').margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
