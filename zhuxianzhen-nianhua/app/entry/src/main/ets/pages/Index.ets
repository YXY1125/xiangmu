import { Theme } from '../components/design-system/Theme'
import { AuthService } from '../services/AuthService'
import { AccessConfig } from '../config/AccessConfig'
import { LoginPage } from './LoginPage'
import { MainTabPage } from './MainTabPage'
import { BackService } from '../services/BackService'

enum AppStage {
  Login = 0,
  Main = 1
}

/**
 * 启动流：不再单独展示隐私授权首屏。
 * open_optional → 可直接进首页；login_required → 登录页。
 * 隐私同意勾选在登录/注册页完成。
 */
@Entry
@Component
struct Index {
  @State stage: AppStage = AppStage.Main
  @State showLoginOverlay: boolean = false
  @State containerVersion: number = 0
  @StorageLink('sessionExpired') @Watch('onSessionExpired') sessionExpired: boolean = false
  @StorageLink('companyName') company: string = '黑龙江省众富信息科技有限公司'
  @StorageLink('appDisplayName') appName: string = '朱仙镇年画'
  @StorageLink('appTagline') tagline: string = '让古老年画在指尖焕新'

  aboutToAppear(): void {
    this.refreshStage()
  }

  onBackPress(): boolean {
    if (BackService.dispatch()) return true
    if (this.showLoginOverlay) { this.showLoginOverlay = false; return true }
    return false
  }

  private refreshStage(): void {
    this.containerVersion++
    if (AccessConfig.mode() === 'login_required' && !AuthService.isLoggedIn()) {
      this.stage = AppStage.Login
      this.showLoginOverlay = false
      return
    }
    this.stage = AppStage.Main
    this.showLoginOverlay = false
  }

  private onSessionExpired(): void {
    if (this.sessionExpired) { this.containerVersion++; this.openLogin() }
  }

  private openLogin(): void {
    if (AccessConfig.mode() === 'login_required') {
      this.stage = AppStage.Login
    } else {
      this.showLoginOverlay = true
    }
  }

  build() {
    Stack() {
      Column() {
        if (this.stage === AppStage.Login) {
          LoginPage({
            allowRegister: AccessConfig.allowRegister(),
            allowSkip: false,
            onSuccess: () => this.refreshStage()
          })
        } else {
          ForEach([this.containerVersion], (_revision: number) => {
          MainTabPage({
            company: this.company,
            appName: this.appName,
            tagline: this.tagline,
            onOpenLogin: () => this.openLogin(),
            onLogout: () => this.refreshStage(),
            onRequireAuth: () => this.openLogin()
          })
          }, (revision: number) => `${revision}`)
        }
      }
      .width('100%')
      .height('100%')

      if (this.showLoginOverlay) {
        LoginPage({
          allowRegister: AccessConfig.allowRegister(),
          allowSkip: AccessConfig.guestBrowse(),
          onSuccess: () => {
            this.showLoginOverlay = false
            this.refreshStage()
          },
          onSkip: () => {
            this.showLoginOverlay = false
          }
        })
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.colors().surfacePage)
      }
    }
    .width('100%')
    .height('100%')
  }
}
