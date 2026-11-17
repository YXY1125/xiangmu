import { Theme } from '../components/design-system/Theme'
import { SectionTitle } from '../components/culture/SectionTitle'
import { CharacterDetail } from '../components/culture/CharacterDetail'
import { ArticleDetail } from '../components/culture/ArticleDetail'
import { CharacterProfile, CultureArticle, Exhibition } from '../models/CultureModels'
import { CultureSearch } from '../services/CultureSearch'
import { CultureCatalog } from '../data/CultureCatalog'
import { AssetResolver } from '../utils/AssetResolver'
import { ContentService } from '../services/ContentService'
import { BackService } from '../services/BackService'

@Component
export struct HomePage {
  @Prop company: string = ''
  @Prop appName: string = '朱仙镇年画'
  @Prop tagline: string = '让古老年画在指尖焕新'
  @State selectedCharacter: CharacterProfile | null = null
  @State selectedArticle: CultureArticle | null = null
  @State searchOpen: boolean = false
  @State query: string = ''
  private backId: number = 0
  onOpenMessages: () => void = () => {}
  onOpenCreate: () => void = () => {}
  onOpenPlayground: () => void = () => {}
  onOpenGallery: (segment: number) => void = () => {}
  onOpenExhibition: (id: string) => void = () => {}
  @State characters: CharacterProfile[] = CultureCatalog.characters()
  @State articles: CultureArticle[] = CultureCatalog.articles()
  @State exhibitions: Exhibition[] = CultureCatalog.exhibitions()

  aboutToAppear(): void {
    this.backId = BackService.register(() => {
      if (this.searchOpen) { this.searchOpen = false; this.query = ''; return true }
      return false
    })
    ContentService.characters().then((items: CharacterProfile[]) => { if (items.length > 0) this.characters = items })
    ContentService.articles().then((items: CultureArticle[]) => { if (items.length > 0) this.articles = items })
    ContentService.exhibitions().then((items: Exhibition[]) => { if (items.length > 0) this.exhibitions = items })
  }

  aboutToDisappear(): void { BackService.remove(this.backId) }

  build() {
    Stack() {
      Column() {
        Row({ space: 10 }) {
          Image($r('app.media.app_icon')).width(42).height(42).borderRadius(12)
          Column({ space: 1 }) {
            Text(this.appName).fontSize(19).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
            Text('年画新世界').fontSize(11).fontColor(Theme.colors().textSecondary)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button(this.searchOpen ? '收起' : '搜索').fontSize(13).fontColor(Theme.colors().textPrimary)
            .backgroundColor(Theme.colors().surfaceCard).height(40).borderRadius(20)
            .onClick(() => { this.searchOpen = !this.searchOpen; if (!this.searchOpen) this.query = '' })
        }.padding({ left: 16, right: 16, top: 12, bottom: 8 }).width('100%')
        if (this.searchOpen) {
          TextInput({ placeholder: '搜索角色、文化知识、专题', text: this.query })
            .onChange((value: string) => this.query = value).height(46).margin({ left: 16, right: 16, bottom: 8 })
            .backgroundColor(Theme.colors().surfaceCard).borderRadius(23).id('home-search-input')
            .enterKeyType(EnterKeyType.Search).onSubmit(() => this.query = this.query.trim())
        }
        if (this.searchOpen) {
          Scroll() {
            Column({ space: 12 }) {
              if (this.query.trim().length === 0) {
                Text('输入关键词，即时查找角色、知识和专题').fontSize(14).padding(24)
              } else {
                Text(`找到 ${CultureSearch.characters(this.query, this.characters).length + CultureSearch.articles(this.query, this.articles).length + CultureSearch.exhibitions(this.query, this.exhibitions).length} 项内容`)
                  .fontSize(14).fontColor(Theme.colors().textSecondary).width('100%').id('home-search-count')
                ForEach(CultureSearch.characters(this.query, this.characters), (item: CharacterProfile) => {
                  Row({ space: 12 }) {
                    Image(AssetResolver.media(item.image)).width(66).height(76).objectFit(ImageFit.Contain)
                    Column({ space: 6 }) {
                      Text(item.name).fontSize(17).fontWeight(FontWeight.Bold)
                      Text('原创角色 · ' + item.series).fontSize(12)
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Text('›').fontSize(24)
                  }.padding(12).width('100%').backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
                    .onClick(() => this.selectedCharacter = item)
                }, (item: CharacterProfile) => item.id)
                ForEach(CultureSearch.articles(this.query, this.articles), (item: CultureArticle) => {
                  Column({ space: 6 }) {
                    Text(item.title).fontSize(17).fontWeight(FontWeight.Bold)
                    Text('文化知识 · ' + item.summary).fontSize(12).maxLines(2)
                  }.alignItems(HorizontalAlign.Start).padding(16).width('100%')
                    .backgroundColor(Theme.colors().surfaceCard).borderRadius(18).onClick(() => this.selectedArticle = item)
                }, (item: CultureArticle) => item.id)
                ForEach(CultureSearch.exhibitions(this.query, this.exhibitions), (item: Exhibition) => {
                  Column({ space: 6 }) {
                    Text(item.title).fontSize(17).fontWeight(FontWeight.Bold)
                    Text('数字专题 · ' + item.intro).fontSize(12).maxLines(2)
                  }.alignItems(HorizontalAlign.Start).padding(16).width('100%')
                    .backgroundColor(Theme.colors().surfaceCard).borderRadius(18).onClick(() => this.onOpenExhibition(item.id))
                }, (item: Exhibition) => item.id)
                if (CultureSearch.characters(this.query, this.characters).length + CultureSearch.articles(this.query, this.articles).length + CultureSearch.exhibitions(this.query, this.exhibitions).length === 0) {
                  Text('暂未找到相关内容，试试“门神”“木版”或“秦小将”').fontSize(14).padding(24)
                }
              }
            }.padding(16).width('100%')
          }.layoutWeight(1).scrollBar(BarState.Off).id('home-search-results')
        } else {
        Scroll() {
          Column({ space: 24 }) {
            Stack({ alignContent: Alignment.BottomStart }) {
              Image(AssetResolver.media('hero_home')).width('100%').height(265).objectFit(ImageFit.Cover).borderRadius(28)
              Column({ space: 10 }) {
                Text('年画新世界').fontSize(31).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  .shadow({ radius: 4, color: 'rgba(0,0,0,0.42)' })
                Text(this.tagline).fontSize(14).fontColor('#FFF8E8')
                Button('进入创意工坊  ›').height(48).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                  .backgroundColor(Theme.colors().brandPrimary).borderRadius(24).onClick(() => this.onOpenCreate())
              }.alignItems(HorizontalAlign.Start).padding(20)
            }.width('100%')
            Column({ space: 12 }) {
              SectionTitle({ title: '原创角色', subtitle: '四大系列 · 12 位原创伙伴', onMore: () => this.onOpenGallery(1) })
              Scroll() {
                Row({ space: 12 }) {
                  ForEach(this.characters.slice(0, 6), (item: CharacterProfile) => {
                    Column({ space: 8 }) {
                      Image(AssetResolver.media(item.image)).width(118).height(140).objectFit(ImageFit.Contain)
                        .backgroundColor('#F2DDB6').borderRadius(18)
                      Text(item.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.colors().textPrimary)
                      Text(item.series).fontSize(10).fontColor(Theme.colors().textSecondary)
                    }.width(118).alignItems(HorizontalAlign.Start).onClick(() => this.selectedCharacter = item)
                  }, (item: CharacterProfile) => item.id)
                }
              }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            }.width('100%')
            Stack({ alignContent: Alignment.BottomStart }) {
              Image(AssetResolver.media('banner_craft')).width('100%').height(210).objectFit(ImageFit.Cover).borderRadius(24)
              Column({ space: 6 }) {
                Text('今日文化').fontSize(13).fontColor('#FFFFFF').backgroundColor(Theme.colors().brandPrimary)
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 }).borderRadius(10)
                Text('一刀一线：木版雕刻').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              }.alignItems(HorizontalAlign.Start).padding(16)
            }.width('100%').onClick(() => { if (this.articles.length > 0) this.selectedArticle = this.articles.find((item: CultureArticle) => item.id === 'carving') ?? this.articles[0] })
            Row({ space: 12 }) {
              this.FeatureCard('创意工坊', '20 套模板，自由编辑', 'banner_craft', () => this.onOpenCreate())
              this.FeatureCard('互动乐园', '五种游戏，边玩边学', 'cover_playground', () => this.onOpenPlayground())
            }.width('100%')
            Column({ space: 12 }) {
              SectionTitle({ title: '精选专题', subtitle: '从作品、工艺到民俗', onMore: () => this.onOpenGallery(2) })
              Stack({ alignContent: Alignment.BottomStart }) {
                Image(AssetResolver.media('exhibition_classic')).width('100%').height(190).objectFit(ImageFit.Cover).borderRadius(22)
                Text('朱仙镇年画经典作品展').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  .padding(16).width('100%').backgroundColor('rgba(56,45,42,0.45)')
              }.width('100%').onClick(() => this.onOpenExhibition('classic'))
            }.width('100%')
            Column({ space: 12 }) {
              SectionTitle({ title: '热门年画知识', subtitle: '内容均标注来源与编辑记录', onMore: () => this.onOpenGallery(0) })
              ForEach(this.articles.slice(0, 4), (item: CultureArticle) => {
                Row({ space: 12 }) {
                  Image(AssetResolver.media(item.image)).width(92).height(76).objectFit(ImageFit.Cover).borderRadius(14)
                  Column({ space: 6 }) {
                    Text(item.title).fontSize(16).fontWeight(FontWeight.Bold).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(item.summary).fontSize(12).fontColor(Theme.colors().textSecondary).maxLines(2)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }.width('100%').padding(10).backgroundColor(Theme.colors().surfaceCard).borderRadius(18)
                  .onClick(() => this.selectedArticle = item)
              }, (item: CultureArticle) => item.id)
            }.width('100%')
            Stack({ alignContent: Alignment.BottomStart }) {
              Image(AssetResolver.media('banner_festival')).width('100%').height(180).objectFit(ImageFit.Cover).borderRadius(22)
              Text('新春年俗主题活动 · 收集五福纹样').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .padding(16).width('100%').backgroundColor('rgba(110,30,36,0.48)')
            }.width('100%').onClick(() => this.onOpenPlayground())
          }.padding({ left: 16, right: 16, bottom: 28 }).width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off)
        }
      }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
      if (this.selectedCharacter !== null) {
        CharacterDetail({ profile: this.selectedCharacter, onBack: () => this.selectedCharacter = null })
      }
      if (this.selectedArticle !== null) {
        ArticleDetail({ article: this.selectedArticle, onBack: () => this.selectedArticle = null })
      }
    }.width('100%').height('100%')
  }

  @Builder
  FeatureCard(title: string, desc: string, image: string, action: () => void) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(AssetResolver.media(image)).width('100%').height(168).objectFit(ImageFit.Cover).borderRadius(20)
      Column({ space: 3 }) {
        Text(title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Text(desc).fontSize(11).fontColor('#FFF4DA')
      }.alignItems(HorizontalAlign.Start).padding(12).width('100%').backgroundColor('rgba(56,45,42,0.46)')
    }.layoutWeight(1).onClick(action)
  }
}
