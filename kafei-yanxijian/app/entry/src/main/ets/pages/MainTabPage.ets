import { Theme } from '../components/design-system/Theme'
import { AppIcon, AppIconName } from '../components/design-system/AppIcon'
import { HomePage } from './HomePage'
import { StudyPage } from './StudyPage'
import { LabPage } from './LabPage'
import { RecipePage } from './RecipePage'
import { MinePage } from './MinePage'
import { AuthService } from '../services/AuthService'

class CoffeeTab {
  index: number = 0
  icon: AppIconName = 'home'
  label: string = ''
  constructor(index: number, icon: AppIconName, label: string) {
    this.index = index
    this.icon = icon
    this.label = label
  }
}

@Component
export struct MainTabPage {
  @State current: number = 0
  @State homeVisitToken: number = 0
  @StorageLink('coffeeDataRevision') revision: number = 0
  @Prop company: string = '黑龙江省众富信息科技有限公司'
  @Prop appName: string = '咖啡研习间'
  @Prop tagline: string = '在知识与萃取之间，建立自己的咖啡档案'
  onOpenLogin: () => void = () => {}
  onLogout: () => void = () => {}
  onRequireAuth: () => void = () => {}
  private tabs: CoffeeTab[] = [
    new CoffeeTab(0, 'home', '首页'),
    new CoffeeTab(1, 'study', '研习'),
    new CoffeeTab(2, 'lab', '实验室'),
    new CoffeeTab(3, 'recipe', '配方'),
    new CoffeeTab(4, 'user', '我的')
  ]

  private selectTab(index: number): void {
    if (index === 0) this.homeVisitToken += 1
    this.current = index
  }

  private async logout(): Promise<void> {
    await AuthService.logout()
    this.onLogout()
  }

  build() {
    Column() {
      if (this.current === 0) {
        HomePage({
          appName: this.appName,
          tagline: this.tagline,
          refreshToken: this.revision + this.homeVisitToken,
          onRequireAuth: () => this.onRequireAuth()
        }).layoutWeight(1)
      } else if (this.current === 1) {
        StudyPage({ onRequireAuth: () => this.onRequireAuth() }).layoutWeight(1)
      } else if (this.current === 2) {
        LabPage({ onRequireAuth: () => this.onRequireAuth() }).layoutWeight(1)
      } else if (this.current === 3) {
        RecipePage({ onRequireAuth: () => this.onRequireAuth() }).layoutWeight(1)
      } else {
        MinePage({
          appName: this.appName,
          onOpenLogin: () => this.onOpenLogin(),
          onLogout: () => { this.logout() }
        }).layoutWeight(1)
      }

      Row() {
        ForEach(this.tabs, (tab: CoffeeTab) => {
          Column({ space: Theme.space.s1 }) {
            Stack({ alignContent: Alignment.Center }) {
              Row()
                .width(40)
                .height(30)
                .borderRadius(Theme.radius.pill)
                .backgroundColor(this.current === tab.index ? Theme.colors().brandPrimaryContainer : Color.Transparent)
              AppIcon({
                name: tab.icon,
                iconSize: Theme.icon.lg,
                active: this.current === tab.index
              })
            }
            .width(44)
            .height(32)

            Text(tab.label)
              .fontSize(Theme.type.captionL)
              .maxLines(1)
              .fontWeight(this.current === tab.index ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.current === tab.index ? Theme.colors().brandPrimary : Theme.colors().textSecondary)
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(Theme.radius.md)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
          .accessibilityText(this.current === tab.index ? `${tab.label}，已选中` : tab.label)
          .onClick(() => { this.selectTab(tab.index) })
        }, (tab: CoffeeTab) => `${tab.index}`)
      }
      .height(Theme.nav.tabHeight)
      .padding({ left: Theme.space.s2, right: Theme.space.s2, top: Theme.space.s1, bottom: Theme.space.s1 })
      .backgroundColor(Theme.colors().surfaceCard)
      .border({ width: { top: 1 }, color: Theme.colors().strokeHairline })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.colors().surfacePage)
  }
}
