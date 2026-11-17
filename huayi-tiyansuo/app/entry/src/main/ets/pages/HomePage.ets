import { Theme } from '../components/design-system/Theme'
import { FlowerEvent, FlowerMaterial, FlowerTutorial, FlowerWork, HomePayload } from '../models/FlowerModels'
import { FlowerApiService } from '../services/FlowerApiService'

@Component
export struct HomePage {
  @Prop appName: string = '花艺体验所'
  @Prop tagline: string = '让每个人都能成为生活里的花艺师。'
  @State private state: string = 'loading'
  @State private message: string = ''
  @State private data: HomePayload = new HomePayload()
  onOpenWorkshop: (materialId: string) => void = () => {}
  onOpenAtlas: () => void = () => {}
  onOpenLearning: () => void = () => {}
  onOpenGarden: () => void = () => {}

  aboutToAppear(): void { this.load() }
  private load(): void {
    this.state = 'loading'
    FlowerApiService.home().then((response) => {
      if (response.code !== 0 || response.data === undefined) { this.state = 'error'; this.message = response.message; return }
      this.data = response.data; this.state = 'ready'
    })
  }

  build() {
    Scroll() {
      Column({ space: 22 }) {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image($r('app.media.hero_home')).width('100%').height(300).objectFit(ImageFit.Cover)
          Column({ space: 6 }) {
            Text(this.appName).fontSize(31).fontWeight(FontWeight.Bold).fontColor('#FFFDF7')
            Text(this.tagline).fontSize(14).fontColor('#FFFDF7').maxLines(2)
            Button('进入花艺工坊').margin({ top: 8 }).height(38).backgroundColor('#FFF8EE').fontColor('#2E4938').onClick(() => this.onOpenWorkshop(''))
          }.alignItems(HorizontalAlign.Start).width('100%').padding(22).linearGradient({ angle: 0, colors: [['rgba(25,47,34,0.82)', 0], ['rgba(25,47,34,0)', 1]] })
        }.width('100%').height(300).borderRadius({ bottomLeft: 30, bottomRight: 30 }).clip(true)

        if (this.state === 'loading') {
          Column({ space: 10 }) { LoadingProgress().color('#496B55'); Text('正在整理今日花艺灵感…').fontSize(13).fontColor(Theme.colors().textSecondary) }.height(160).justifyContent(FlexAlign.Center)
        } else if (this.state === 'error') {
          Column({ space: 10 }) { Text('内容暂时未能送达').fontSize(18).fontWeight(FontWeight.Bold); Text(this.message).fontSize(13).fontColor(Theme.colors().textSecondary); Button('重新加载').onClick(() => this.load()) }.padding(22).backgroundColor('#FFFEFA').borderRadius(20)
        } else {
          Column({ space: 8 }) {
            Text('每日花语').fontSize(12).fontColor('#D98B91').fontWeight(FontWeight.Bold)
            Text(this.data.dailyLanguage).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#2E4938').width('100%')
            Text(this.data.dailyInspiration).fontSize(14).lineHeight(22).fontColor(Theme.colors().textSecondary).width('100%')
          }.width('100%').alignItems(HorizontalAlign.Start).padding(20).backgroundColor('#F4DED7').borderRadius(24)

          Row({ space: 12 }) {
            this.FeatureCard('工坊', '自由插花与主题挑战', $r('app.media.banner_workshop'), () => this.onOpenWorkshop(''))
            this.FeatureCard('花材图鉴', '认识 60 种真实花材', $r('app.media.cover_atlas'), () => this.onOpenAtlas())
          }.width('100%')
          Row({ space: 12 }) {
            this.FeatureCard('花艺课堂', '从入门到节日花礼', $r('app.media.cover_tutorial'), () => this.onOpenLearning())
            this.FeatureCard('作品花园', '发现花友创作灵感', $r('app.media.hero_home'), () => this.onOpenGarden())
          }.width('100%')

          this.SectionHeader('花艺课堂推荐', '查看全部', () => this.onOpenLearning())
          Scroll() { Row({ space: 12 }) { ForEach(this.data.tutorials, (item: FlowerTutorial) => { this.CourseCard(item) }, (item: FlowerTutorial) => item.id) } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')

          this.SectionHeader('节日花事', '活动大厅', () => this.onOpenLearning())
          ForEach(this.data.events, (item: FlowerEvent) => {
            Stack({ alignContent: Alignment.BottomStart }) {
              Image($r('app.media.cover_mothers_day')).width('100%').height(180).objectFit(ImageFit.Cover)
              Column({ space: 4 }) { Text(item.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF'); Text(item.summary).fontSize(12).fontColor('#FFFDF7').maxLines(2) }.alignItems(HorizontalAlign.Start).width('100%').padding(18).backgroundColor('rgba(34,54,41,0.62)')
            }.height(180).borderRadius(22).clip(true).onClick(() => this.onOpenLearning())
          }, (item: FlowerEvent) => item.id)

          this.SectionHeader('人气作品', '去花园', () => this.onOpenGarden())
          Scroll() { Row({ space: 12 }) { ForEach(this.data.works, (item: FlowerWork) => { this.WorkCard(item) }, (item: FlowerWork) => item.id) } }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')

          this.SectionHeader('热门花材', '随机认识一种', () => this.onOpenAtlas())
          Row({ space: 10 }) { ForEach(this.data.materials, (item: FlowerMaterial) => { Column({ space: 5 }) { Text(item.name).fontSize(15).fontWeight(FontWeight.Bold); Text(item.flowerLanguage).fontSize(11).fontColor(Theme.colors().textSecondary).maxLines(2) }.alignItems(HorizontalAlign.Start).layoutWeight(1).height(90).padding(12).backgroundColor('#E2EBDD').borderRadius(16).onClick(() => this.onOpenWorkshop(item.id)) }, (item: FlowerMaterial) => item.id) }.width('100%')
        }
      }.width('100%').padding({ left: 16, right: 16, bottom: 32 })
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage).scrollBar(BarState.Off)
  }

  @Builder FeatureCard(title: string, subtitle: string, image: Resource, action: () => void) {
    Stack({ alignContent: Alignment.BottomStart }) { Image(image).width('100%').height(150).objectFit(ImageFit.Cover); Column({ space: 2 }) { Text(title).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF'); Text(subtitle).fontSize(10).fontColor('#FFFDF7').maxLines(2) }.width('100%').alignItems(HorizontalAlign.Start).padding(12).backgroundColor('rgba(33,53,40,0.64)') }.layoutWeight(1).height(150).borderRadius(20).clip(true).onClick(action)
  }
  @Builder SectionHeader(title: string, actionLabel: string, action: () => void) { Row() { Text(title).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#24362B').layoutWeight(1); Text(actionLabel).fontSize(13).fontColor('#496B55').onClick(action) }.width('100%') }
  @Builder CourseCard(item: FlowerTutorial) { Column({ space: 7 }) { Image($r('app.media.cover_tutorial')).width(210).height(118).objectFit(ImageFit.Cover).borderRadius(16); Text(item.title).fontSize(15).fontWeight(FontWeight.Bold).maxLines(1).width(210); Text(`${item.difficulty} · ${item.minutes} 分钟`).fontSize(11).fontColor(Theme.colors().textSecondary).width(210) }.alignItems(HorizontalAlign.Start).width(210) }
  @Builder WorkCard(item: FlowerWork) { Column({ space: 6 }) { Image($r('app.media.hero_home')).width(180).height(150).objectFit(ImageFit.Cover).borderRadius(18); Text(item.title).fontSize(14).fontWeight(FontWeight.Bold).maxLines(1).width(180); Text(`${item.authorName} · ${item.likeCount} 喜欢`).fontSize(11).fontColor(Theme.colors().textSecondary).width(180) }.alignItems(HorizontalAlign.Start).width(180).onClick(() => this.onOpenGarden()) }
}
