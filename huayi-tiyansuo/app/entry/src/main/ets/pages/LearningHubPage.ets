import { Theme } from '../components/design-system/Theme'
import { FlowerEvent, FlowerTutorial, FlowerWork, PagePayload, TutorialStep } from '../models/FlowerModels'
import { FlowerApiService } from '../services/FlowerApiService'

@Component
export struct LearningHubPage {
  @State private mode: string = 'course'
  @State private state: string = 'loading'
  @State private message: string = ''
  @State private courses: FlowerTutorial[] = []
  @State private events: FlowerEvent[] = []
  @State private selectedCourse: FlowerTutorial | null = null
  @State private selectedEvent: FlowerEvent | null = null
  @State private stepIndex: number = 0
  @State private publishedWorks: FlowerWork[] = []
  @State private submitNotice: string = ''
  onBack: () => void = () => {}
  onOpenWorkshop: (materialIds: string[]) => void = () => {}
  onRequireAuth: () => void = () => {}

  aboutToAppear(): void { this.load() }
  private load(): void {
    this.state = 'loading'; let completed = 0; let failed = false
    FlowerApiService.tutorials().then((response) => {
      if (response.code === 0 && response.data !== undefined) this.courses = (response.data as PagePayload<FlowerTutorial>).items
      else { failed = true; this.message = response.message }
      completed++; if (completed === 2) this.state = failed && this.courses.length === 0 && this.events.length === 0 ? 'error' : 'ready'
    })
    FlowerApiService.events().then((response) => {
      if (response.code === 0 && response.data !== undefined) this.events = (response.data as PagePayload<FlowerEvent>).items
      else { failed = true; this.message = response.message }
      completed++; if (completed === 2) this.state = failed && this.courses.length === 0 && this.events.length === 0 ? 'error' : 'ready'
    })
  }

  private requireLogin(): boolean {
    const token = AppStorage.get<string>('accessToken') ?? ''
    if (token.length > 0) return true
    this.onRequireAuth(); return false
  }

  private updateProgress(completed: boolean): void {
    if (this.selectedCourse === null || !this.requireLogin()) return
    FlowerApiService.tutorialProgress(this.selectedCourse.id, this.stepIndex + 1, completed).then((response) => {
      if (response.code !== 0) this.message = response.message
    })
  }

  private toggleCourseFavorite(course: FlowerTutorial): void {
    if (!this.requireLogin()) return
    FlowerApiService.favoriteTutorial(course.id).then((response) => {
      if (response.code !== 0) { this.message = response.message; return }
      const updated = this.copyTutorial(course)
      updated.favorite = !course.favorite
      this.courses = this.courses.map((item: FlowerTutorial) => item.id === updated.id ? updated : item)
      this.selectedCourse = updated
    })
  }

  private copyTutorial(source: FlowerTutorial): FlowerTutorial {
    const target = new FlowerTutorial()
    target.id = source.id
    target.title = source.title
    target.summary = source.summary
    target.category = source.category
    target.difficulty = source.difficulty
    target.minutes = source.minutes
    target.progress = source.progress
    target.favorite = source.favorite
    target.materialIds = source.materialIds.slice()
    target.tools = source.tools.slice()
    target.steps = source.steps.slice()
    return target
  }

  private joinEvent(): void {
    if (this.selectedEvent === null || !this.requireLogin()) return
    FlowerApiService.joinEvent(this.selectedEvent.id).then((response) => {
      if (response.code === 0 && response.data !== undefined) {
        this.submitNotice = '已参加活动，可以开始主题创作'
        this.selectedEvent = response.data
        this.loadPublishedWorks()
      } else {
        this.message = response.message
        this.submitNotice = response.message
      }
    })
  }

  private openEvent(event: FlowerEvent): void { this.selectedEvent = event; this.submitNotice = ''; if (event.joined) this.loadPublishedWorks() }
  private loadPublishedWorks(): void {
    FlowerApiService.myWorks().then((response) => {
      if (response.code === 0 && response.data !== undefined) this.publishedWorks = (response.data as PagePayload<FlowerWork>).items.filter((item: FlowerWork) => item.visibility === 'public')
      else this.submitNotice = response.message
    })
  }
  private submitWork(eventId: string, workId: string): void {
    FlowerApiService.submitEvent(eventId, workId).then((response) => { this.submitNotice = response.code === 0 ? '作品已提交，活动进度已更新' : response.message })
  }

  build() {
    Stack() {
      Column() {
        Row() { Button('返回').height(36).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.onBack()); Column({ space: 2 }) { Text('花艺课堂与节日花事').fontSize(22).fontWeight(FontWeight.Bold); Text('学习、复刻、参加主题创作').fontSize(11).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1) }.width('100%').padding(16)
        Row() { Text('花艺课堂').fontColor(this.mode === 'course' ? '#FFFFFF' : '#496B55').backgroundColor(this.mode === 'course' ? '#496B55' : '#E2EBDD').padding({ left: 24, right: 24, top: 10, bottom: 10 }).borderRadius(99).onClick(() => this.mode = 'course'); Text('节日花事').fontColor(this.mode === 'event' ? '#FFFFFF' : '#496B55').backgroundColor(this.mode === 'event' ? '#496B55' : '#E2EBDD').padding({ left: 24, right: 24, top: 10, bottom: 10 }).borderRadius(99).onClick(() => this.mode = 'event') }.width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 12 })
        if (this.state === 'loading') {
          Column({ space: 10 }) { LoadingProgress().color('#496B55'); Text('正在准备课程与活动…').fontSize(13).fontColor(Theme.colors().textSecondary) }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.state === 'error') {
          Column({ space: 10 }) { Text('内容加载失败').fontSize(18).fontWeight(FontWeight.Bold); Text(this.message).fontSize(13).fontColor(Theme.colors().textSecondary); Button('重试').onClick(() => this.load()) }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.mode === 'course') {
          List({ space: 12 }) { ForEach(this.courses, (item: FlowerTutorial) => { ListItem() { Row({ space: 12 }) { Image($r('app.media.cover_tutorial')).width(116).height(96).objectFit(ImageFit.Cover).borderRadius(16); Column({ space: 5 }) { Text(item.category).fontSize(10).fontColor('#D98B91'); Text(item.title).fontSize(17).fontWeight(FontWeight.Bold).maxLines(2); Text(`${item.difficulty} · ${item.minutes} 分钟 · 已学 ${item.progress}%`).fontSize(11).fontColor(Theme.colors().textSecondary) }.alignItems(HorizontalAlign.Start).layoutWeight(1) }.padding(10).backgroundColor('#FFFEFA').borderRadius(20).onClick(() => { this.selectedCourse = item; this.stepIndex = Math.max(0, Math.floor(item.progress * item.steps.length / 100) - 1) }) } }, (item: FlowerTutorial) => item.id) }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).scrollBar(BarState.Off)
        } else {
          List({ space: 14 }) { ForEach(this.events, (item: FlowerEvent) => { ListItem() { Column({ space: 9 }) { Image($r('app.media.cover_mothers_day')).width('100%').height(170).objectFit(ImageFit.Cover).borderRadius(20); Row() { Column({ space: 4 }) { Text(item.title).fontSize(19).fontWeight(FontWeight.Bold); Text(item.summary).fontSize(12).fontColor(Theme.colors().textSecondary).maxLines(2) }.alignItems(HorizontalAlign.Start).layoutWeight(1); Text(EventStatusLabel(item.status)).fontSize(11).fontColor(item.status === 'active' ? '#2E4938' : '#929A94').padding(7).backgroundColor(item.status === 'active' ? '#E2EBDD' : '#F3ECE2').borderRadius(99) }.width('100%') }.padding(10).backgroundColor('#FFFEFA').borderRadius(22).onClick(() => this.openEvent(item)) } }, (item: FlowerEvent) => item.id) }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).scrollBar(BarState.Off)
        }
      }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)

      if (this.selectedCourse !== null) this.CourseDetail(this.selectedCourse)
      if (this.selectedEvent !== null) this.EventDetail(this.selectedEvent)
    }.width('100%').height('100%')
  }

  @Builder CourseDetail(course: FlowerTutorial) {
    Column() {
      Row() { Button('返回课程').height(36).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.selectedCourse = null); Text(course.title).fontSize(18).fontWeight(FontWeight.Bold).maxLines(1).margin({ left: 10 }).layoutWeight(1); Button(course.favorite ? '已收藏' : '收藏').height(34).fontSize(11).backgroundColor(course.favorite ? '#F4DED7' : '#E2EBDD').fontColor('#2E4938').onClick(() => this.toggleCourseFavorite(course)) }.width('100%').padding(16)
      if (course.steps.length === 0) {
        Column({ space: 10 }) { Text('课程步骤正在整理').fontSize(18).fontWeight(FontWeight.Bold); Text('服务器尚未返回可学习步骤').fontSize(12).fontColor(Theme.colors().textSecondary) }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() { Column({ space: 16 }) { Image($r('app.media.cover_tutorial')).width('100%').height(230).objectFit(ImageFit.Cover).borderRadius(24); Text(`第 ${this.stepIndex + 1} / ${course.steps.length} 步`).fontSize(12).fontColor('#D98B91').width('100%'); Text(course.steps[this.stepIndex].title).fontSize(24).fontWeight(FontWeight.Bold).width('100%'); Text(course.steps[this.stepIndex].instruction).fontSize(15).lineHeight(24).fontColor(Theme.colors().textSecondary).width('100%'); Column({ space: 6 }) { Text('所需工具').fontSize(15).fontWeight(FontWeight.Bold).width('100%'); Text(course.tools.join(' · ')).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%') }.padding(16).backgroundColor('#FFFEFA').borderRadius(18).width('100%') }.alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 20 }) }.layoutWeight(1).scrollBar(BarState.Off)
        Row({ space: 10 }) { Button('上一步').enabled(this.stepIndex > 0).layoutWeight(1).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => { if (this.stepIndex > 0) { this.stepIndex--; this.updateProgress(false) } }); Button(this.stepIndex === course.steps.length - 1 ? '完成并去工坊' : '下一步').layoutWeight(1).backgroundColor('#496B55').onClick(() => { if (this.stepIndex === course.steps.length - 1) { this.updateProgress(true); this.onOpenWorkshop(course.materialIds) } else { this.stepIndex++; this.updateProgress(false) } }) }.padding({ left: 16, right: 16, bottom: 18 }).width('100%')
      }
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage).zIndex(30)
  }

  @Builder EventDetail(event: FlowerEvent) {
    Column() {
      Row() {
        Button('返回活动').height(36).backgroundColor('#E2EBDD').fontColor('#2E4938').onClick(() => this.selectedEvent = null)
        Text(event.title).fontSize(19).fontWeight(FontWeight.Bold).margin({ left: 10 }).layoutWeight(1)
      }.width('100%').padding(16)
      Scroll() {
        Column({ space: 14 }) {
          Image($r('app.media.cover_mothers_day')).width('100%').height(250).objectFit(ImageFit.Cover).borderRadius(24)
          Text(event.theme).fontSize(24).fontWeight(FontWeight.Bold).width('100%')
          Text(event.summary).fontSize(14).lineHeight(22).fontColor(Theme.colors().textSecondary).width('100%')
          Text(`${event.startsAt} 至 ${event.endsAt}`).fontSize(12).fontColor('#D98B91').width('100%')
          Column({ space: 8 }) {
            Text('活动规则').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
            ForEach(event.rules, (rule: string, index: number) => {
              Text(`${index + 1}. ${rule}`).fontSize(13).lineHeight(20).fontColor(Theme.colors().textSecondary).width('100%')
            })
          }.padding(16).backgroundColor('#FFFEFA').borderRadius(18).width('100%')
          Button(event.joined ? '已参加 · 开始主题创作' : '参加活动')
            .width('100%').backgroundColor('#496B55').enabled(event.status === 'active')
            .onClick(() => { if (event.joined) this.onOpenWorkshop(event.recommendedMaterialIds); else this.joinEvent() })
          if (this.submitNotice.length > 0) {
            Text(this.submitNotice).fontSize(12).fontColor('#8A4D53').width('100%')
          }
          if (event.joined) {
            Text('提交我的公开作品').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
            if (this.publishedWorks.length === 0) {
              Text('还没有可提交的公开作品，请先完成主题创作并发布。').fontSize(12).fontColor(Theme.colors().textSecondary).width('100%')
            }
            ForEach(this.publishedWorks, (work: FlowerWork) => {
              Row() {
                Column({ space: 3 }) {
                  Text(work.title).fontSize(14).fontWeight(FontWeight.Bold)
                  Text(work.themeName).fontSize(10).fontColor(Theme.colors().textSecondary)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Button('提交').height(34).fontSize(11).backgroundColor('#E2EBDD').fontColor('#2E4938').enabled(event.status === 'active').onClick(() => this.submitWork(event.id, work.id))
              }.padding(12).backgroundColor('#FFFEFA').borderRadius(16).width('100%')
            }, (work: FlowerWork) => work.id)
          }
        }.alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, bottom: 30 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage).zIndex(30)
  }
}

function EventStatusLabel(status: string): string {
  if (status === 'active') return '进行中'
  if (status === 'upcoming') return '即将开始'
  return '已结束'
}
