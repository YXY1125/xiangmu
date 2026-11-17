import { Theme } from '../design-system/Theme'
import { CultureArticle } from '../../models/CultureModels'
import { AssetResolver } from '../../utils/AssetResolver'
import { LocalDataStore } from '../../services/LocalDataStore'
import { BackService } from '../../services/BackService'

@Component
export struct ArticleDetail {
  @Prop article: CultureArticle = new CultureArticle()
  @State favorite: boolean = false
  onBack: () => void = () => {}
  private backId: number = 0
  private previousTabHidden: boolean = false
  @State status: string = ''

  aboutToAppear(): void {
    this.previousTabHidden = AppStorage.get<boolean>('tabBarHidden') ?? false
    AppStorage.setOrCreate('tabBarHidden', true)
    this.backId = BackService.register(() => { this.onBack(); return true })
    LocalDataStore.markLearned(this.article.id).catch(() => this.status = '阅读记录未能保存，请重试')
    LocalDataStore.favorites().then((ids: string[]) => this.favorite = ids.indexOf(`article:${this.article.id}`) >= 0)
  }

  aboutToDisappear(): void {
    BackService.remove(this.backId)
    AppStorage.setOrCreate('tabBarHidden', this.previousTabHidden)
  }

  build() {
    Column() {
      Row() {
        Button('‹').fontSize(30).fontColor(Theme.colors().textPrimary).backgroundColor('transparent')
          .width(44).height(44).onClick(() => this.onBack())
        Text(this.article.category).fontSize(15).fontColor(Theme.colors().textSecondary).layoutWeight(1).textAlign(TextAlign.Center)
        Button(this.favorite ? '已收藏' : '收藏').fontSize(13).height(40).borderRadius(20)
          .fontColor(this.favorite ? '#FFFFFF' : Theme.colors().brandPrimary)
          .backgroundColor(this.favorite ? Theme.colors().brandPrimary : Theme.colors().surfaceCard)
          .onClick(() => LocalDataStore.toggleFavorite(`article:${this.article.id}`)
            .then((value: boolean) => this.favorite = value).catch(() => this.status = '收藏保存失败，请重试'))
      }.padding({ left: 12, right: 16, top: 12, bottom: 8 }).width('100%')
      Scroll() {
        Column({ space: 18 }) {
          Image(AssetResolver.media(this.article.image)).width('100%').height(220).objectFit(ImageFit.Cover).borderRadius(24)
          Text(this.article.title).fontSize(28).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
          if (this.article.original) {
            Text('原创创作').fontSize(12).fontColor('#FFFFFF').backgroundColor(Theme.colors().brandPrimary)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(12).alignSelf(ItemAlign.Start)
          }
          Text(this.article.body).fontSize(16).lineHeight(28).fontColor(Theme.colors().textPrimary).width('100%')
          if (this.status.length > 0) Text(this.status).fontSize(12).fontColor(Theme.colors().danger)
          Column({ space: 8 }) {
            Text('来源与编辑记录').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
            Text(this.article.sourceNote).fontSize(12).lineHeight(20).fontColor(Theme.colors().textSecondary)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor('#F0E4CC').borderRadius(16)
        }.padding({ left: 16, right: 16, bottom: 32 }).width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
