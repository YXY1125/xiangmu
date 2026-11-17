import { Theme } from '../components/design-system/Theme'
import { CharacterDetail } from '../components/culture/CharacterDetail'
import { ArticleDetail } from '../components/culture/ArticleDetail'
import { CultureCatalog } from '../data/CultureCatalog'
import { CharacterProfile, CultureArticle, Exhibition } from '../models/CultureModels'
import { AssetResolver } from '../utils/AssetResolver'
import { LocalDataStore } from '../services/LocalDataStore'
import { ContentService } from '../services/ContentService'
import { BackService } from '../services/BackService'

@Component
export struct CoreBizPage {
  @Prop pageTitle: string = '年画馆'
  @Prop initialSegment: number = 0
  @State segment: number = 0
  @State selectedCharacter: CharacterProfile | null = null
  @State selectedArticle: CultureArticle | null = null
  @State selectedExhibition: Exhibition | null = null
  @State exhibitionProgress: number = 0
  @State exhibitionFavorite: boolean = false
  @State exhibitionMessage: string = ''
  private backId: number = 0
  onRequireAuth: () => void = () => {}
  @State articles: CultureArticle[] = CultureCatalog.articles()
  @State characters: CharacterProfile[] = CultureCatalog.characters()
  @State exhibitions: Exhibition[] = CultureCatalog.exhibitions()

  aboutToAppear(): void {
    this.segment = this.initialSegment
    this.backId = BackService.register(() => {
      if (this.selectedExhibition !== null) { this.closeExhibition(); return true }
      return false
    })
    ContentService.articles().then((items: CultureArticle[]) => { if (items.length > 0) this.articles = items })
    ContentService.characters().then((items: CharacterProfile[]) => { if (items.length > 0) this.characters = items })
    ContentService.exhibitions().then((items: Exhibition[]) => { if (items.length > 0) this.exhibitions = items })
    const requested = AppStorage.get<string>('requestedExhibition') ?? ''
    if (requested.length > 0) {
      AppStorage.setOrCreate('requestedExhibition', '')
      const item = this.exhibitions.find((entry: Exhibition) => entry.id === requested)
      if (item !== undefined) this.openExhibition(item)
    }
  }

  aboutToDisappear(): void { BackService.remove(this.backId) }

  private closeExhibition(): void {
    this.selectedExhibition = null
    AppStorage.setOrCreate('tabBarHidden', false)
  }

  private openExhibition(item: Exhibition): void {
    this.selectedExhibition = item
    this.exhibitionProgress = 0
    this.exhibitionFavorite = false
    this.exhibitionMessage = ''
    AppStorage.setOrCreate('tabBarHidden', true)
    LocalDataStore.browsingProgress(item.id).then((value: number) => {
      if (this.selectedExhibition?.id === item.id) this.exhibitionProgress = value
    }).catch(() => this.exhibitionMessage = '浏览记录读取失败')
    LocalDataStore.favorites().then((ids: string[]) => {
      if (this.selectedExhibition?.id === item.id) this.exhibitionFavorite = ids.indexOf('exhibition:' + item.id) >= 0
    }).catch(() => this.exhibitionMessage = '收藏状态读取失败')
  }

  private completeExhibition(id: string): void {
    LocalDataStore.saveBrowsingProgress(id, 1).then(() => {
      if (this.selectedExhibition?.id === id) { this.exhibitionProgress = 1; this.exhibitionMessage = '浏览进度已保存' }
    }).catch(() => this.exhibitionMessage = '浏览进度保存失败，请重试')
  }

  build() {
    Stack() {
      Column() {
        Column({ space: 12 }) {
          Text('年画馆').fontSize(30).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
          Text('看见传统，也创造新的表达').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
          Row({ space: 6 }) {
            this.SegmentButton('文化', 0)
            this.SegmentButton('角色', 1)
            this.SegmentButton('专题', 2)
          }.padding(4).backgroundColor('#ECDDCA').borderRadius(24).width('100%')
        }.padding({ left: 16, right: 16, top: 16, bottom: 10 }).width('100%').alignItems(HorizontalAlign.Start)
        Scroll() {
          Column({ space: 14 }) {
            if (this.segment === 0) {
              Stack({ alignContent: Alignment.BottomStart }) {
                Image(AssetResolver.media('exhibition_classic')).height(220).width('100%').objectFit(ImageFit.Cover).borderRadius(24)
                Column({ space: 4 }) {
                  Text('朱仙镇木版年画').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  Text('起源 · 工艺 · 题材 · 民俗').fontSize(12).fontColor('#FFF5DE')
                }.alignItems(HorizontalAlign.Start).padding(16).width('100%').backgroundColor('rgba(56,45,42,0.45)')
              }.width('100%')
              ForEach(this.articles, (item: CultureArticle) => {
                Row({ space: 12 }) {
                  Image(AssetResolver.media(item.image)).width(104).height(88).objectFit(ImageFit.Cover).borderRadius(15)
                  Column({ space: 6 }) {
                    Text(item.category).fontSize(11).fontColor(Theme.colors().brandPrimary)
                    Text(item.title).fontSize(17).fontWeight(FontWeight.Bold).maxLines(1)
                    Text(item.summary).fontSize(12).fontColor(Theme.colors().textSecondary).maxLines(2)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }.padding(10).width('100%').backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
                  .onClick(() => this.selectedArticle = item)
              }, (item: CultureArticle) => item.id)
            } else if (this.segment === 1) {
              ForEach(['门神守护团', '财神纳福团', '瑞兽奇遇团', '福娃迎春团'], (series: string) => {
                Column({ space: 10 }) {
                  Text(series).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).width('100%')
                  Grid() {
                    ForEach(this.characters.filter((item: CharacterProfile) => item.series === series), (item: CharacterProfile) => {
                      GridItem() {
                        Column({ space: 7 }) {
                          Image(AssetResolver.media(item.image)).width('100%').height(152).objectFit(ImageFit.Contain)
                            .backgroundColor('#F2DDB6').borderRadius(18)
                          Text(item.name).fontSize(15).fontWeight(FontWeight.Bold)
                          Text(item.personality).fontSize(11).fontColor(Theme.colors().textSecondary).maxLines(1)
                        }.width('100%').alignItems(HorizontalAlign.Start).onClick(() => this.selectedCharacter = item)
                      }
                    }, (item: CharacterProfile) => item.id)
                  }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(14).width('100%')
                }.width('100%')
              }, (series: string) => series)
            } else {
              ForEach(this.exhibitions, (item: Exhibition, index: number) => {
                Stack({ alignContent: Alignment.BottomStart }) {
                  Image(AssetResolver.media(item.image)).width('100%').height(190).objectFit(ImageFit.Cover).borderRadius(22)
                  Column({ space: 5 }) {
                    Text(`专题 0${index + 1}`).fontSize(11).fontColor('#FFF2C8')
                    Text(item.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                    Text(item.intro).fontSize(12).fontColor('#FFF8E8').maxLines(2)
                  }.alignItems(HorizontalAlign.Start).padding(16).width('100%').backgroundColor('rgba(56,45,42,0.5)')
                }.width('100%').onClick(() => {
                  this.openExhibition(item)
                })
              }, (item: Exhibition) => item.id)
            }
          }.padding({ left: 16, right: 16, bottom: 26 }).width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
      if (this.selectedExhibition !== null) {
        this.ExhibitionDetail(this.selectedExhibition)
      }
      if (this.selectedCharacter !== null) {
        CharacterDetail({ profile: this.selectedCharacter, onBack: () => this.selectedCharacter = null })
      }
      if (this.selectedArticle !== null) {
        ArticleDetail({ article: this.selectedArticle, onBack: () => this.selectedArticle = null })
      }
    }.width('100%').height('100%')
  }

  @Builder
  SegmentButton(label: string, index: number) {
    Button(label).layoutWeight(1).height(40).fontSize(14).borderRadius(20)
      .fontColor(this.segment === index ? '#FFFFFF' : Theme.colors().textPrimary)
      .backgroundColor(this.segment === index ? Theme.colors().brandPrimary : 'transparent')
      .onClick(() => this.segment = index)
  }

  @Builder
  ExhibitionDetail(item: Exhibition) {
    Column() {
      Row() {
        Button('‹').fontSize(30).backgroundColor('transparent').fontColor(Theme.colors().textPrimary)
          .width(44).height(44).onClick(() => this.closeExhibition())
        Text('数字专题展').fontSize(15).layoutWeight(1).textAlign(TextAlign.Center)
        Button(this.exhibitionFavorite ? '已收藏' : '收藏').height(40).fontSize(12)
          .backgroundColor(Theme.colors().surfaceCard).fontColor(Theme.colors().brandPrimary)
          .onClick(() => {
            LocalDataStore.toggleFavorite('exhibition:' + item.id).then((value: boolean) => this.exhibitionFavorite = value)
              .catch(() => this.exhibitionMessage = '收藏保存失败，请重试')
          })
      }.padding({ left: 12, right: 12, top: 12 }).width('100%')
      Scroll() {
        Column({ space: 18 }) {
          Image(AssetResolver.media(item.image)).width('100%').height(250).objectFit(ImageFit.Cover).borderRadius(24)
          Text(item.title).fontSize(28).fontWeight(FontWeight.Bold).width('100%')
          Text(item.intro).fontSize(15).lineHeight(24).fontColor(Theme.colors().textSecondary).width('100%')
          Text('展览内容').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
          ForEach(this.articles.filter((a: CultureArticle) => item.itemIds.indexOf(a.id) >= 0), (a: CultureArticle) => {
            Row({ space: 12 }) {
              Image(AssetResolver.media(a.image)).width(88).height(72).objectFit(ImageFit.Cover).borderRadius(12)
              Text(a.title).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
              Text('›').fontSize(24).fontColor(Theme.colors().brandPrimary)
            }.padding(10).backgroundColor(Theme.colors().surfaceCard).borderRadius(16).width('100%')
              .onClick(() => this.selectedArticle = a)
          }, (a: CultureArticle) => a.id)
          Text(`展览浏览进度 ${Math.round(this.exhibitionProgress * 100)}%`).fontSize(12).fontColor(Theme.colors().success)
          if (this.exhibitionMessage.length > 0) Text(this.exhibitionMessage).fontSize(12).fontColor(Theme.colors().textSecondary)
        }.padding({ left: 16, right: 16, bottom: 30 }).width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).onReachEnd(() => this.completeExhibition(item.id))
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
