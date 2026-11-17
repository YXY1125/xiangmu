import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeApi } from '../services/CoffeeApi'
import { UserSummary } from '../models/CoffeeModels'

@Component
export struct MinePage {
  @Prop appName: string = '咖啡研习间'
  onOpenLogin: () => void = () => {}
  onLogout: () => void = () => {}
  @StorageLink('coffeeDataRevision') @Watch('onRevision') revision: number = 0
  @StorageLink('accessToken') @Watch('onSessionChanged') accessToken: string = ''
  @State summary: UserSummary = new UserSummary()
  private requestSerial: number = 0

  aboutToAppear(): void {
    this.loadSummary()
  }
  private onRevision(): void { this.loadSummary() }
  private onSessionChanged(): void { this.loadSummary() }
  private loadSummary(): void {
    const serial = ++this.requestSerial
    if (this.accessToken.length === 0) { this.summary = new UserSummary(); return }
    CoffeeApi.growth().then((result) => { if (serial === this.requestSerial && result.code === 0 && result.data !== undefined) this.summary = result.data })
  }

  private levelName(): string {
    if (this.summary.experience >= 1200) return '咖啡研习大师'
    if (this.summary.experience >= 700) return '精品咖啡探索家'
    if (this.summary.experience >= 360) return '进阶研习者'
    if (this.summary.experience >= 160) return '咖啡爱好者'
    if (this.summary.experience >= 60) return '初阶探索者'
    return '咖啡新手'
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('我的咖啡档案').fontSize(30).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
        if (this.accessToken.length === 0) {
          Column({ space: 12 }) {
            Image($r('app.media.app_icon')).width(72).height(72).borderRadius(20)
            Text('登录后建立长期咖啡档案').fontSize(18).fontWeight(FontWeight.Bold)
            Text('制作、配方、测评、收藏与成长数据将按账号隔离。').fontSize(13).fontColor(Theme.colors().textSecondary).textAlign(TextAlign.Center)
            Button('登录 / 注册').backgroundColor(Theme.colors().brandPrimary).borderRadius(22).onClick(() => this.onOpenLogin())
          }.padding(24).backgroundColor(Theme.colors().surfaceCard).borderRadius(24).width('100%')
        } else {
          Row() {
            Image($r('app.media.app_icon')).width(62).height(62).borderRadius(18)
            Column({ space: 4 }) { Text(this.levelName()).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#F3EBDD'); Text(`${this.summary.experience} 经验 · 由真实行为累计`).fontSize(12).fontColor('#D8C7B2') }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
            Text('›').fontSize(24).fontColor('#F3EBDD')
          }.padding(18).backgroundColor('#241B17').borderRadius(22).onClick(() => AppRouter.push(this.getUIContext(), { url: 'pages/ProfilePage' }))
        }

        this.Menu('学习记录', '已完成知识、进度与打卡', 'pages/LearningRecordPage')
        this.Menu('制作记录', '参数、器具、感受与历史对比', 'pages/BrewHistoryPage')
        this.Menu('我的收藏', '知识、配方与器具', 'pages/FavoritePage')
        this.Menu('我的配方', '版本、收藏与归档', 'pages/RecipeEditPage')
        this.Menu('我的测评', '七维评分与风味偏好', 'pages/FlavorReportPage')
        this.Menu('成长统计', '等级、趋势与成就', 'pages/GrowthPage')
        this.Menu('系统设置', '协议、隐私、缓存与账号', 'pages/SettingsPage')
        if (this.accessToken.length > 0) {
          Button('退出登录').width('100%').height(46).fontColor(Theme.colors().danger).backgroundColor(Theme.colors().surfaceCard).borderRadius(18).margin({ bottom: 24 }).onClick(() => this.onLogout())
        }
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder Menu(title: string, subtitle: string, url: string) {
    Row() {
      Column({ space: 3 }) { Text(title).fontSize(16).fontWeight(FontWeight.Medium); Text(subtitle).fontSize(11).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(24).fontColor(Theme.colors().brandPrimary)
    }.padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(17).onClick(() => {
      if (url !== 'pages/SettingsPage' && this.accessToken.length === 0) {
        this.onOpenLogin()
        return
      }
      AppRouter.push(this.getUIContext(), { url: url })
    })
  }
}
