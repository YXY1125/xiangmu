import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { AuthService } from '../services/AuthService'
import { CoffeeApi } from '../services/CoffeeApi'
@Entry
@Component
struct SettingsPage {
  @State closing: boolean = false

  private handle(action: string): void {
    if (action.startsWith('pages/')) {
      AppRouter.push(this.getUIContext(), { url: action })
      return
    }
    if (action === 'cache') {
      this.getUIContext().showAlertDialog({
        title: '清除缓存',
        message: '当前版本不保存可删除的图片缓存，业务记录不会被清除。',
        confirm: { value: '知道了', action: () => {} }
      })
      return
    }
    this.getUIContext().showAlertDialog({
      title: '确认注销账号？',
      message: '账号身份信息将匿名化，历史业务记录归档并保留必要审计信息。此操作不可撤销。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认注销', fontColor: Theme.colors().danger, action: () => this.closeAccount() }
    })
  }

  private async closeAccount(): Promise<void> {
    if (this.closing) return
    this.closing = true
    const result = await CoffeeApi.closeAccount()
    this.closing = false
    if (result.code === 0) {
      await AuthService.logout()
      AppRouter.replace(this.getUIContext(), { url: 'pages/Index' })
      return
    }
    this.getUIContext().showAlertDialog({ title: '注销未完成', message: result.message, confirm: { value: '知道了', action: () => {} } })
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
        Text('系统设置').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 })
      }.width('100%').margin({ bottom: 8 })
      this.Item('用户协议', '查看当前协议版本', 'pages/UserAgreementPage')
      this.Item('隐私政策', '个人信息与第三方共享说明', 'pages/PrivacyPolicyPage')
      this.Item('清除缓存', '只清除可恢复缓存，不删除业务记录', 'cache')
      this.Item(this.closing ? '正在注销…' : '注销账号', '身份信息匿名化，业务记录归档', 'close')
      Text('开发者：黑龙江省云富信息科技有限公司')
        .fontSize(11).lineHeight(18).fontColor(Theme.colors().textSecondary).margin({ top: 16 })
    }.padding(16).width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder Item(title: string, subtitle: string, action: string) {
    Row() {
      Column({ space: 3 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium)
        Text(subtitle).fontSize(11).fontColor(Theme.colors().textSecondary)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(24).fontColor(Theme.colors().brandPrimary)
    }.padding(16).backgroundColor(Theme.colors().surfaceCard).borderRadius(17).onClick(() => this.handle(action))
  }
}
