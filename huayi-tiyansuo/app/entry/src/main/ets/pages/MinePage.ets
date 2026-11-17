import { Theme } from '../components/design-system/Theme'
import { LegalDocKind, LegalDocOverlay } from '../components/legal/LegalDocOverlay'
import { EventRecord, FlowerMaterial, FlowerTutorial, FlowerWork, LearningRecord, MeDashboardPayload, PagePayload, UserAchievement } from '../models/FlowerModels'
import { AuthService } from '../services/AuthService'
import { FlowerApiService } from '../services/FlowerApiService'
import { StudioPreview } from '../components/StudioPreview'
import { PrivacyService } from '../services/PrivacyService'

@Component
export struct MinePage {
  @Prop appName: string = '花艺体验所'
  @Prop @Watch('onRefreshRevisionChanged') refreshRevision: number = 0
  @StorageLink('accessToken') @Watch('onSessionChanged') accessToken: string = ''
  @StorageLink('currentUsername') currentUsername: string = ''
  @State private achievements: UserAchievement[] = []
  @State private works: FlowerWork[] = []
  @State private state: string = 'guest'
  @State private showSettings: boolean = false
  @State private showLegal: boolean = false
  @State private legalKind: LegalDocKind = 'privacy'
  @State private message: string = ''
  @State private dashboard: MeDashboardPayload = new MeDashboardPayload()
  @State private accountBusy: boolean = false
  onOpenLogin: () => void = () => {}
  onLogout: () => void = () => {}
  onEditWork: (work: FlowerWork) => void = () => {}

  aboutToAppear(): void { this.refreshData() }
  private onRefreshRevisionChanged(): void { this.refreshData() }
  private onSessionChanged(): void { this.refreshData() }
  private loggedIn(): boolean { return this.accessToken.length > 0 }
  private refreshData(): void {
    if (!this.loggedIn()) {
      this.state = 'guest'; this.achievements = []; this.works = []; this.dashboard = new MeDashboardPayload(); this.message = ''
      return
    }
    this.state = 'loading'
    this.message = ''
    let completed = 0
    const finish = (): void => { completed++; if (completed === 3) this.state = 'ready' }
    FlowerApiService.achievements().then((response) => {
      if (response.code === 0 && response.data !== undefined) this.achievements = (response.data as PagePayload<UserAchievement>).items
      else this.message = response.message
      finish()
    })
    FlowerApiService.myWorks().then((response) => {
      if (response.code === 0 && response.data !== undefined) this.works = (response.data as PagePayload<FlowerWork>).items
      else this.message = response.message
      finish()
    })
    FlowerApiService.meDashboard().then((response) => {
      if (response.code === 0 && response.data !== undefined) this.dashboard = response.data
      else this.message = response.message
      finish()
    })
  }

  private unlockedCount(): number { return this.achievements.filter((item: UserAchievement) => item.unlocked).length }

  private confirmDeleteAccount(): void {
    AlertDialog.show({
      title: '注销账号',
      message: '注销后，你的作品、草稿、收藏、学习进度、活动记录和账号将被删除且不可恢复。',
      autoCancel: true,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认注销', action: () => { void this.deleteAccount() } }
    })
  }

  private async deleteAccount(): Promise<void> {
    if (this.accountBusy) return
    this.accountBusy = true
    const ok = await PrivacyService.deleteAccount()
    this.accountBusy = false
    if (!ok) { this.message = '注销失败，请稍后重试'; return }
    await AuthService.logout()
    this.showSettings = false
    this.onLogout()
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 18 }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Image($r('app.media.banner_workshop')).width('100%').height(210).objectFit(ImageFit.Cover)
            Row({ space: 12 }) {
              Image($r('app.media.app_icon')).width(54).height(54).objectFit(ImageFit.Contain).backgroundColor('#FFF8EE').borderRadius(27)
              Column({ space: 4 }) { Text(this.loggedIn() ? this.currentUsername : '访客花友').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(this.loggedIn() ? '欢迎回到你的花房' : '登录后同步作品、收藏和学习记录').fontSize(10).fontColor('#FFFDF7').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (this.loggedIn()) {
                Button(this.state === 'loading' ? '同步' : '刷新').width(58).height(34).fontSize(10).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => { this.refreshData() })
              }
              Button(this.loggedIn() ? '设置' : '登录').width(58).height(34).fontSize(10).backgroundColor('#FFF8EE').fontColor('#2E4938').onClick(() => { if (this.loggedIn()) this.showSettings = true; else this.onOpenLogin() })
            }.width('100%').padding(18).backgroundColor('rgba(34,54,41,0.66)')
          }.width('100%').height(210).borderRadius({ bottomLeft: 28, bottomRight: 28 }).clip(true)

          if (!this.loggedIn()) {
            Column({ space: 12 }) { Image($r('app.media.empty_vase')).width(180).height(170).objectFit(ImageFit.Contain); Text('把创作留在自己的花房').fontSize(20).fontWeight(FontWeight.Bold); Text('注册协议默认不勾选，登录后所有个人数据按用户隔离。').fontSize(12).lineHeight(19).fontColor(Theme.colors().textSecondary).textAlign(TextAlign.Center); Button('登录 / 注册').backgroundColor('#496B55').onClick(() => this.onOpenLogin()) }.padding(20).backgroundColor('#FFFEFA').borderRadius(24).width('100%')
          } else {
            Row({ space: 10 }) { this.Stat((): string => `${this.works.length}`, '作品'); this.Stat((): string => `${this.works.filter((item: FlowerWork) => item.visibility === 'private').length}`, '草稿'); this.Stat((): string => `${this.unlockedCount()}/${this.achievements.length}`, '成就') }.width('100%')
            if (this.state === 'loading') {
              Row({ space: 8 }) { LoadingProgress().width(22).height(22).color('#496B55'); Text('正在同步花房数据…').fontSize(12).fontColor(Theme.colors().textSecondary) }.width('100%').justifyContent(FlexAlign.Center)
            }
            Text('我的花房').fontSize(21).fontWeight(FontWeight.Bold).width('100%')
            if (this.works.length > 0) {
              Scroll() { Row({ space: 10 }) { ForEach(this.works, (work: FlowerWork) => { Column({ space: 5 }) { StudioPreview({ snapshot: work.canvas, previewWidth: 142 }); Text(work.title).fontSize(13).fontWeight(FontWeight.Bold).maxLines(1).width(142); Text(work.visibility === 'private' ? '私有草稿 · 继续编辑' : '已发布 · 继续编辑').fontSize(10).fontColor(Theme.colors().textSecondary).width(142) }.alignItems(HorizontalAlign.Start).onClick(() => this.onEditWork(work)) }, (work: FlowerWork) => work.id) } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            }
            Row({ space: 8 }) { this.SmallCount((): string => `${this.dashboard.collectedWorks.length}`, '作品收藏'); this.SmallCount((): string => `${this.dashboard.favoriteMaterials.length}`, '花材收藏'); this.SmallCount((): string => `${this.dashboard.learning.length}`, '学习记录'); this.SmallCount((): string => `${this.dashboard.eventRecords.length}`, '活动记录') }.width('100%')
            if (this.dashboard.favoriteMaterials.length > 0) {
              Text('收藏的花材').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
              Scroll() { Row({ space: 8 }) { ForEach(this.dashboard.favoriteMaterials, (item: FlowerMaterial) => { Column({ space: 3 }) { Text(item.name).fontSize(13).fontWeight(FontWeight.Bold); Text(item.category).fontSize(9).fontColor(Theme.colors().textSecondary) }.width(100).padding(10).backgroundColor('#E2EBDD').borderRadius(14) }, (item: FlowerMaterial) => item.id) } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            }
            if (this.dashboard.learning.length > 0) {
              Text('课程进度').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
              ForEach(this.dashboard.learning.slice(0, 3), (item: LearningRecord) => { Row() { Column({ space: 3 }) { Text(item.title).fontSize(13).fontWeight(FontWeight.Bold); Text(item.completed ? '已完成' : `学习进度 ${item.progress}%`).fontSize(10).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Progress({ value: item.progress, total: 100, type: ProgressType.Ring }).width(34).height(34).color('#496B55') }.padding(11).backgroundColor('#FFFEFA').borderRadius(15).width('100%') }, (item: LearningRecord) => item.id)
            }
            if (this.dashboard.favoriteTutorials.length > 0) {
              Text('收藏的课程').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
              ForEach(this.dashboard.favoriteTutorials.slice(0, 3), (item: FlowerTutorial) => { Row() { Column({ space: 3 }) { Text(item.title).fontSize(13).fontWeight(FontWeight.Bold); Text(`${item.category} · ${item.minutes} 分钟`).fontSize(10).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text('已收藏').fontSize(10).fontColor('#D98B91') }.padding(11).backgroundColor('#FFFEFA').borderRadius(15).width('100%') }, (item: FlowerTutorial) => item.id)
            }
            if (this.dashboard.eventRecords.length > 0) {
              Text('活动参与记录').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
              ForEach(this.dashboard.eventRecords, (item: EventRecord) => { Row() { Column({ space: 3 }) { Text(item.title).fontSize(13).fontWeight(FontWeight.Bold); Text(`已提交 ${item.submissions.length} 件作品`).fontSize(10).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(item.status === 'active' ? '进行中' : item.status === 'upcoming' ? '未开始' : '已结束').fontSize(10).fontColor('#D98B91') }.padding(11).backgroundColor('#FFFEFA').borderRadius(15).width('100%') }, (item: EventRecord) => item.eventId)
            }
            Row() { Text('成长与成就').fontSize(21).fontWeight(FontWeight.Bold).layoutWeight(1); Text(`${this.unlockedCount()} 已解锁`).fontSize(12).fontColor('#D98B91') }.width('100%')
            if (this.state === 'loading') LoadingProgress().color('#496B55')
            ForEach(this.achievements, (item: UserAchievement) => {
              Row({ space: 12 }) { Column() { Text(item.unlocked ? '已解锁' : `${item.current}/${item.target}`).fontSize(10).fontColor(item.unlocked ? '#8A4D53' : '#5D6B62') }.width(52).height(52).justifyContent(FlexAlign.Center).backgroundColor(item.unlocked ? '#F4DED7' : '#F3ECE2').borderRadius(26); Column({ space: 4 }) { Text(item.title).fontSize(16).fontWeight(FontWeight.Bold); Text(item.description).fontSize(11).fontColor(Theme.colors().textSecondary).maxLines(2); Progress({ value: Math.min(item.current, item.target), total: item.target, type: ProgressType.Linear }).color('#496B55').backgroundColor('#E2EBDD').height(5).width('100%') }.alignItems(HorizontalAlign.Start).layoutWeight(1) }.padding(14).backgroundColor('#FFFEFA').borderRadius(18).width('100%')
            }, (item: UserAchievement) => item.id)
          }
          if (this.message.length > 0) Text(this.message).fontSize(11).fontColor('#8A4D53').width('100%')
        }.width('100%').padding({ left: 16, right: 16, bottom: 32 })
      }.width('100%').height('100%').scrollBar(BarState.Off).backgroundColor(Theme.colors().surfacePage)

      if (this.showSettings) {
        Column({ space: 14 }) { Row() { Button('返回').height(36).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.showSettings = false); Text('设置中心').fontSize(22).fontWeight(FontWeight.Bold).margin({ left: 12 }).layoutWeight(1) }.width('100%'); Button('用户协议').width('100%').backgroundColor('#FFFEFA').fontColor('#2E4938').onClick(() => { this.legalKind = 'agreement'; this.showLegal = true }); Button('隐私政策').width('100%').backgroundColor('#FFFEFA').fontColor('#2E4938').onClick(() => { this.legalKind = 'privacy'; this.showLegal = true }); Button('退出登录').width('100%').backgroundColor('#F4DED7').fontColor('#8A3340').onClick(() => { void AuthService.logout(); this.showSettings = false; this.onLogout() }); Button(this.accountBusy ? '正在注销…' : '注销账号').enabled(!this.accountBusy).width('100%').backgroundColor('#8A3340').fontColor('#FFFFFF').onClick(() => this.confirmDeleteAccount()) }.padding(16).width('100%').height('100%').backgroundColor(Theme.colors().surfacePage).zIndex(20)
      }
      if (this.showLegal) LegalDocOverlay({ kind: this.legalKind, onClose: () => this.showLegal = false }).width('100%').height('100%').zIndex(30)
    }.width('100%').height('100%')
  }

  @Builder Stat(value: () => string, label: string) { Column({ space: 3 }) { Text(value()).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2E4938'); Text(label).fontSize(11).fontColor(Theme.colors().textSecondary) }.layoutWeight(1).padding(14).backgroundColor('#E2EBDD').borderRadius(17) }
  @Builder SmallCount(value: () => string, label: string) { Column({ space: 2 }) { Text(value()).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2E4938'); Text(label).fontSize(8).fontColor(Theme.colors().textSecondary).maxLines(1) }.layoutWeight(1).padding({ top: 10, bottom: 10 }).backgroundColor('#F3ECE2').borderRadius(13) }
}
