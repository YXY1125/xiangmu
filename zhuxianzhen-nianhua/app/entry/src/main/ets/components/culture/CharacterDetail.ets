import { Theme } from '../design-system/Theme'
import { CharacterProfile } from '../../models/CultureModels'
import { AssetResolver } from '../../utils/AssetResolver'
import { LocalDataStore } from '../../services/LocalDataStore'
import { BackService } from '../../services/BackService'

@Component
export struct CharacterDetail {
  @Prop profile: CharacterProfile = new CharacterProfile()
  @State favorite: boolean = false
  onBack: () => void = () => {}
  private backId: number = 0
  private previousTabHidden: boolean = false
  @State status: string = ''

  aboutToAppear(): void {
    this.previousTabHidden = AppStorage.get<boolean>('tabBarHidden') ?? false
    AppStorage.setOrCreate('tabBarHidden', true)
    this.backId = BackService.register(() => { this.onBack(); return true })
    LocalDataStore.favorites().then((ids: string[]) => {
      this.favorite = ids.indexOf(`character:${this.profile.id}`) >= 0
    })
  }

  aboutToDisappear(): void {
    BackService.remove(this.backId)
    AppStorage.setOrCreate('tabBarHidden', this.previousTabHidden)
  }

  build() {
    Column() {
      Row() {
        Button('‹').fontSize(30).fontColor(Theme.colors().textPrimary).backgroundColor('rgba(255,253,248,0.88)')
          .width(44).height(44).borderRadius(22).onClick(() => this.onBack())
        Text(this.profile.series).fontSize(14).fontColor(Theme.colors().textSecondary).layoutWeight(1).textAlign(TextAlign.Center)
        Button(this.favorite ? '已收藏' : '收藏').fontSize(13)
          .fontColor(this.favorite ? Theme.colors().brandOnPrimary : Theme.colors().brandPrimary)
          .backgroundColor(this.favorite ? Theme.colors().brandPrimary : Theme.colors().surfaceCard)
          .height(40).borderRadius(20).onClick(() => {
            LocalDataStore.toggleFavorite(`character:${this.profile.id}`).then((value: boolean) => this.favorite = value)
              .catch(() => this.status = '收藏保存失败，请重试')
          })
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })
      if (this.status.length > 0) Text(this.status).fontSize(12).fontColor(Theme.colors().danger).padding(8)
      Scroll() {
        Column({ space: 16 }) {
          Stack({ alignContent: Alignment.Bottom }) {
            Column().width('100%').height(330).backgroundColor('#F1D9AC').borderRadius(28)
            Image(AssetResolver.media(this.profile.image)).objectFit(ImageFit.Contain).width('92%').height(320)
          }.width('100%')
          Column({ space: 7 }) {
            Text(this.profile.name).fontSize(30).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
            Text(this.profile.personality).fontSize(15).fontColor(Theme.colors().brandPrimary)
          }.width('100%').alignItems(HorizontalAlign.Start)
          this.InfoCard('文化原型', this.profile.origin)
          this.InfoCard('吉祥寓意', this.profile.meaning)
          this.InfoCard('角色故事 · 原创', this.profile.story)
          this.InfoCard('关联创作素材', '该角色立绘已进入创意工坊角色素材库，可添加到画布并调整位置、大小、旋转和层级。')
        }.padding({ left: 16, right: 16, bottom: 32 }).width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }

  @Builder
  InfoCard(title: string, content: string) {
    Column({ space: 8 }) {
      Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
      Text(content).fontSize(14).lineHeight(22).fontColor(Theme.colors().textSecondary)
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
  }
}
