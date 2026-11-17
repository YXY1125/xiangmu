import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { BrewMath } from '../services/BrewMath'

@Entry
@Component
struct BrewCalculatorPage {
  @State doseText: string = '15'
  @State ratio: number = 15
  @State temperature: number = 92
  @State method: string = '手冲'

  aboutToAppear(): void {
    const params = AppRouter.getParams(this.getUIContext()) as Record<string, Object>
    if (!params) return
    const ratio = Number(params['ratio'] ?? this.ratio)
    const temperature = Number(params['temperature'] ?? this.temperature)
    if (ratio >= 12 && ratio <= 18) this.ratio = ratio
    if (temperature >= 0 && temperature <= 100) this.temperature = temperature
    if (params['method']) this.method = `${params['method']}`
  }

  private dose(): number {
    const value = Number(this.doseText)
    return Number.isFinite(value) ? value : 0
  }

  private water(): number { return BrewMath.water(this.dose(), this.ratio) }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.Header('冲煮计算器')
        Column({ space: 8 }) {
          Text('咖啡粉重量').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
          TextInput({ text: this.doseText, placeholder: '输入克数' }).type(InputType.Number).height(50).backgroundColor(Theme.colors().surfaceCard).borderRadius(16)
            .onChange((value: string) => { this.doseText = value })
        }.width('100%').alignItems(HorizontalAlign.Start)
        Column({ space: 9 }) {
          Text('粉水比例').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
          Scroll() {
            Row({ space: 6 }) {
              ForEach([12, 13, 14, 15, 16, 17, 18], (value: number) => {
                Text(`1:${value}`).fontSize(11).fontColor(this.ratio === value ? Color.White : Theme.colors().textPrimary)
                  .padding({ left: 12, right: 12, top: 9, bottom: 9 }).backgroundColor(this.ratio === value ? Theme.colors().brandPrimary : Theme.colors().surfaceCard).borderRadius(14)
                  .onClick(() => { this.ratio = value })
              })
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        }.width('100%').alignItems(HorizontalAlign.Start)
        Column({ space: 6 }) {
          Text('建议总水量').fontSize(12).fontColor('#D8C7B2')
          Text(`${this.water()} ml`).fontSize(42).fontWeight(FontWeight.Bold).fontColor('#F3EBDD')
          Text(`${this.dose()}g × ${this.ratio} = ${this.water()}ml`).fontSize(12).fontColor('#D8C7B2')
        }.width('100%').padding(24).backgroundColor('#241B17').borderRadius(24)
        Text('分段注水').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
        Row({ space: 8 }) {
          this.Stage('闷蒸', 20)
          this.Stage('第一段', 30)
          this.Stage('第二段', 50)
        }.width('100%')
        Row() {
          Text('水温').fontSize(15).layoutWeight(1)
          Text(`${this.temperature}℃`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.colors().brandPrimary)
        }.padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(17)
        Slider({ value: this.temperature, min: 80, max: 96, step: 1 }).selectedColor(Theme.colors().brandPrimary).onChange((value: number) => { this.temperature = Math.round(value) })
        Button('以此参数创建制作记录').height(50).width('100%').backgroundColor(Theme.colors().brandPrimary).borderRadius(20)
          .onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/BrewRecordEditPage', params: { dose: this.dose(), water: this.water(), ratio: this.ratio, temperature: this.temperature, method: this.method } }))
      }.padding(16).width('100%').margin({ bottom: 24 })
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder Header(title: string) { Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Text(title).fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }) }.width('100%') }
  @Builder Stage(label: string, percent: number) { Column({ space: 5 }) { Text(label).fontSize(11).fontColor(Theme.colors().textSecondary); Text(`${BrewMath.stageWater(this.water(), percent)}ml`).fontSize(17).fontWeight(FontWeight.Bold); Text(`${percent}%`).fontSize(10).fontColor(Theme.colors().brandPrimary) }.layoutWeight(1).padding({ top: 16, bottom: 16 }).backgroundColor(Theme.colors().surfaceCard).borderRadius(17) }
}
