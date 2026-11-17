import { Theme } from '../components/design-system/Theme'
import { AppIcon, AppIconName } from '../components/design-system/AppIcon'
import { HomePage } from './HomePage'
import { WorkshopPage } from './WorkshopPage'
import { FlowerAtlasPage } from './FlowerAtlasPage'
import { WorkGardenPage } from './WorkGardenPage'
import { LearningHubPage } from './LearningHubPage'
import { MinePage } from './MinePage'
import { AuthService } from '../services/AuthService'
import { FlowerWork } from '../models/FlowerModels'

class TabItem {
  index: number = 0
  name: AppIconName = 'home'
  label: string = ''
  static all(): TabItem[] {
    const items: TabItem[] = []
    const names: AppIconName[] = ['home', 'workshop', 'atlas', 'garden', 'user']
    const labels = ['首页', '工坊', '图鉴', '花园', '我的']
    names.forEach((name: AppIconName, index: number) => { const item = new TabItem(); item.index = index; item.name = name; item.label = labels[index]; items.push(item) })
    return items
  }
}

@Component
export struct MainTabPage {
  @State private current: number = 0
  @State private showLearning: boolean = false
  @State private workshopSeeds: string[] = []
  @State private editingWorkId: string = ''
  @State private editingWorkTitle: string = ''
  @State private editingSnapshot: string = ''
  @State private mineRefreshRevision: number = 0
  @StorageLink('tabBarHidden') tabBarHidden: boolean = false
  @Prop appName: string = '花艺体验所'
  @Prop tagline: string = '让每个人都能成为生活里的花艺师。'
  onOpenLogin: () => void = () => {}
  onLogout: () => void = () => {}
  onRequireAuth: () => void = () => {}
  private tabs: TabItem[] = TabItem.all()

  private openWorkshop(ids: string[]): void { this.editingWorkId = ''; this.editingWorkTitle = ''; this.editingSnapshot = ''; this.workshopSeeds = ids.slice(); this.current = 1; this.showLearning = false }
  private editWork(work: FlowerWork): void { this.workshopSeeds = []; this.editingWorkId = work.id; this.editingWorkTitle = work.title; this.editingSnapshot = JSON.stringify(work.canvas); this.current = 1 }

  build() {
    Stack() {
      Column() {
        if (this.current === 0) {
          HomePage({
            appName: this.appName,
            tagline: this.tagline,
            onOpenWorkshop: (materialId: string) => this.openWorkshop(materialId.length > 0 ? [materialId] : []),
            onOpenAtlas: () => this.current = 2,
            onOpenLearning: () => this.showLearning = true,
            onOpenGarden: () => this.current = 3
          }).layoutWeight(1)
        } else if (this.current === 1) {
          WorkshopPage({ seedMaterialIds: this.workshopSeeds, initialWorkId: this.editingWorkId, initialWorkTitle: this.editingWorkTitle, initialSnapshotJson: this.editingSnapshot, onRequireAuth: () => this.onRequireAuth(), onDataChanged: () => this.mineRefreshRevision++ }).layoutWeight(1)
        } else if (this.current === 2) {
          FlowerAtlasPage({ onUseMaterial: (id: string) => this.openWorkshop([id]), onRequireAuth: () => this.onRequireAuth() }).layoutWeight(1)
        } else if (this.current === 3) {
          WorkGardenPage({ onRequireAuth: () => this.onRequireAuth() }).layoutWeight(1)
        } else {
          MinePage({
            appName: this.appName,
            refreshRevision: this.mineRefreshRevision,
            onOpenLogin: () => this.onOpenLogin(),
            onLogout: () => { void AuthService.logout(); this.onLogout() },
            onEditWork: (work: FlowerWork) => this.editWork(work)
          }).layoutWeight(1)
        }

        if (!this.tabBarHidden && !this.showLearning) {
          Row() { ForEach(this.tabs, (item: TabItem) => { this.TabBarItem(item) }, (item: TabItem) => `${item.index}`) }
            .width('100%').height(64).padding({ bottom: 4 }).backgroundColor('#FFFEFA').border({ width: { top: 1 }, color: 'rgba(46,73,56,0.08)' }).shadow({ radius: 18, color: 'rgba(46,73,56,0.08)', offsetY: -3, offsetX: 0 })
        }
      }.width('100%').height('100%')

      if (this.showLearning) {
        LearningHubPage({ onBack: () => this.showLearning = false, onOpenWorkshop: (ids: string[]) => this.openWorkshop(ids), onRequireAuth: () => this.onRequireAuth() }).width('100%').height('100%').zIndex(20)
      }
    }.width('100%').height('100%')
  }

  @Builder TabBarItem(item: TabItem) {
    Column({ space: 3 }) {
      AppIcon({ name: item.name, iconSize: 21, color: this.current === item.index ? '#496B55' : '#929A94' })
      Text(item.label).fontSize(10).fontWeight(this.current === item.index ? FontWeight.Bold : FontWeight.Normal).fontColor(this.current === item.index ? '#496B55' : '#929A94')
    }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center).onClick(() => {
      this.workshopSeeds = []
      this.editingWorkId = ''
      this.editingWorkTitle = ''
      this.editingSnapshot = ''
      if (item.index === 4) this.mineRefreshRevision++
      this.current = item.index
    })
  }
}
