import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'

@Entry
@Component
struct BrewingGuidePage {
  @State method: string = '手冲咖啡'
  aboutToAppear(): void { const params = AppRouter.getParams(this.getUIContext()) as Record<string, Object>; this.method = params && params['method'] ? `${params['method']}` : '手冲咖啡' }
  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Text(this.method).fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }) }.width('100%')
        Text('理解变量，再复刻味道').fontSize(13).fontColor(Theme.colors().brandPrimary).width('100%')
        this.Section('所需器具', '磨豆机、电子秤、计时器、适配冲煮方式的器具与清洁用水。')
        this.Section('参数起点', '建议从 15g 咖啡粉、1:15 粉水比、92℃ 水温开始，再根据烘焙度与实际流速调整。')
        Text('制作步骤').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
        ForEach(['称量并均匀研磨', '润湿滤纸并预热器具', '加入咖啡粉并整平粉床', '以总水量 20% 闷蒸 30–40 秒', '分段稳定注水，控制液面与流速', '记录总时长并品尝，下一杯只调整一个变量'], (step: string, index: number) => {
          Row() { Text(`${index + 1}`).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White).width(28).height(28).textAlign(TextAlign.Center).backgroundColor(Theme.colors().brandPrimary).borderRadius(14); Text(step).fontSize(14).lineHeight(21).layoutWeight(1).margin({ left: 12 }) }.width('100%').padding(14).backgroundColor(Theme.colors().surfaceCard).borderRadius(16)
        })
        this.Section('常见错误', '一次改变多个变量、只看总时长不看流速、研磨刻度照搬他人、忽略咖啡豆烘焙日期。')
        Button('打开计算器').width('100%').backgroundColor(Theme.colors().brandPrimary).borderRadius(20).onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/BrewCalculatorPage' }))
      }.padding(16).width('100%').margin({ bottom: 24 })
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
  @Builder Section(title: string, body: string) { Column({ space: 8 }) { Text(title).fontSize(18).fontWeight(FontWeight.Bold).width('100%'); Text(body).fontSize(14).lineHeight(22).fontColor(Theme.colors().textSecondary).width('100%') }.padding(18).backgroundColor(Theme.colors().surfaceCard).borderRadius(19).alignItems(HorizontalAlign.Start) }
}
