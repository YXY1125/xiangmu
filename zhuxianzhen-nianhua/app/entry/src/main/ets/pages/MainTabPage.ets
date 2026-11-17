import { Theme } from '../components/design-system/Theme'
import { AppIcon, AppIconName } from '../components/design-system/AppIcon'
import { HomePage } from './HomePage'
import { CoreBizPage } from './CoreBizPage'
import { DashboardPage } from './DashboardPage'
import { MessagesPage } from './MessagesPage'
import { MinePage } from './MinePage'
import { AuthService } from '../services/AuthService'

class TabItem {
  index: number = 0
  name: AppIconName = 'home'
  label: string = ''
}

function tab(index: number, name: AppIconName, label: string): TabItem {
  const item = new TabItem()
  item.index = index
  item.name = name
  item.label = label
  return item
}

@Component
export struct MainTabPage {
  @State current: number = 0
  @State gallerySegment: number = 0
  @StorageLink('tabBarHidden') tabBarHidden: boolean = false
  @Prop company: string = '黑龙江省众富信息科技有限公司'
  @Prop appName: string = '朱仙镇年画'
  @Prop tagline: string = '让古老年画在指尖焕新'
  @Prop quickCommands: string[] = []
  onOpenLogin: () => void = () => {}
  onLogout: () => void = () => {}
  onRequireAuth: () => void = () => {}
  private tabs: TabItem[] = [
    tab(0, 'home', '首页'), tab(1, 'biz', '年画馆'), tab(2, 'create', '创作'),
    tab(3, 'play', '乐园'), tab(4, 'user', '我的')
  ]

  build() {
    Column() {
      if (this.current === 0) {
        HomePage({
          company: this.company, appName: this.appName, tagline: this.tagline,
          onOpenCreate: () => this.current = 2,
          onOpenPlayground: () => this.current = 3,
          onOpenGallery: (segment: number) => { this.gallerySegment = segment; this.current = 1 },
          onOpenExhibition: (id: string) => {
            this.gallerySegment = 2
            AppStorage.setOrCreate('requestedExhibition', id)
            this.current = 1
          }
        }).layoutWeight(1)
      } else if (this.current === 1) {
        CoreBizPage({ pageTitle: '年画馆', initialSegment: this.gallerySegment, onRequireAuth: () => this.onRequireAuth() }).layoutWeight(1)
      } else if (this.current === 2) {
        DashboardPage({ onRequireAuth: () => this.onRequireAuth() }).layoutWeight(1)
      } else if (this.current === 3) {
        MessagesPage().layoutWeight(1)
      } else {
        MinePage({
          appName: this.appName,
          onOpenLogin: () => this.onOpenLogin(),
          onLogout: () => this.onLogout(),
          onOpenCreate: () => this.current = 2,
          onOpenGallery: () => { this.gallerySegment = 2; this.current = 1 },
          onRequireAuth: () => this.onRequireAuth()
        }).layoutWeight(1)
      }
      if (!this.tabBarHidden) {
        Row() {
          ForEach(this.tabs, (item: TabItem) => this.TabBarItem(item), (item: TabItem) => `${item.index}`)
        }.width('100%').height(64).backgroundColor(Theme.colors().surfaceCard)
          .border({ width: { top: 1 }, color: Theme.colors().strokeHairline })
      }
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder
  TabBarItem(item: TabItem) {
    Column({ space: 3 }) {
      AppIcon({ name: item.name, iconSize: 23, color: this.current === item.index ? Theme.colors().brandPrimary : Theme.colors().textSecondary })
      Text(item.label).fontSize(11).fontWeight(this.current === item.index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.current === item.index ? Theme.colors().brandPrimary : Theme.colors().textSecondary)
    }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center).onClick(() => {
      AppStorage.setOrCreate('tabBarHidden', false)
      if (item.index === 1) this.gallerySegment = 0
      this.current = item.index
    })
  }
}
