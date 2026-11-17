import { Theme } from '../components/design-system/Theme'
import { AuthService } from '../services/AuthService'
import { AccessConfig } from '../config/AccessConfig'
import { LoginPage } from './LoginPage'
import { MainTabPage } from './MainTabPage'

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
  @StorageLink('sessionRevision') sessionRevision: number = 0
  @StorageLink('companyName') company: string = '黑龙江省众富信息科技有限公司'
  @StorageLink('appDisplayName') appName: string = '桃花坞刻版'
  @StorageLink('appTagline') tagline: string = '让传统年画，变成可爱的动漫世界。'

  aboutToAppear(): void {
    this.refreshStage()
  }

  private refreshStage(): void {
    if (AccessConfig.mode() === 'login_required' && !AuthService.isLoggedIn()) {
      this.stage = AppStage.Login
      this.showLoginOverlay = false
      return
    }
    this.stage = AppStage.Main
    this.showLoginOverlay = false
  }

  private openLogin(): void {
    if (AccessConfig.mode() === 'login_required') {
      this.stage = AppStage.Login
    } else {
      this.showLoginOverlay = true
    }
  }
  onBackPress(): boolean {
    if (this.showLoginOverlay) { this.showLoginOverlay = false; return true }
    if (AppStorage.get<boolean>('canHandleAppBack') === true) {
      AppStorage.setOrCreate('navigationBackRequest', (AppStorage.get<number>('navigationBackRequest') ?? 0) + 1)
      return true
    }
    return false
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
          ForEach([this.sessionRevision], (revision: number) => {
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
