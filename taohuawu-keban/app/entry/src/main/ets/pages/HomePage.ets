import { Theme } from '../components/design-system/Theme'
import { ArtImage } from '../components/ArtImage'
import { LoadState } from '../components/LoadState'
import { HomeFeed, Banner, Character, Artwork, KnowledgeArticle, Category, Relation } from '../models/ArtModels'
import { CreationCanvas } from '../components/CreationCanvas'
import { ArtService, ArtError } from '../services/ArtService'
import { SessionStore } from '../services/SessionStore'

@Component
export struct HomePage {
  @State feed: HomeFeed = new HomeFeed()
  @State loading: boolean = true
  @State refreshing: boolean = false
  @State error: string = ''
  @StorageLink('sessionRevision') @Watch('reload') revision: number = 0
  onOpen: (kind: string, id: string) => void = () => {}
  private requestId: number = 0
  aboutToAppear(): void { this.reload() }
  private async reload(): Promise<void> {
    const request = ++this.requestId
    const session = SessionStore.revision()
    this.error = ''; this.feed = new HomeFeed(); this.loading = true
    try {
      const feed = await ArtService.home()
      if (request === this.requestId && session === SessionStore.revision()) this.feed = feed
    } catch (error) {
      if (request === this.requestId && session === SessionStore.revision()) this.error = (error as ArtError).message || '首页读取失败'
    } finally { if (request === this.requestId) { this.loading = false; this.refreshing = false } }
  }
  @Builder title(value: string, kind: string) {
    Row() {
      Text(value).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
      Blank()
      Text('查看全部').fontSize(13).fontColor(Theme.colors().brandPrimary).onClick(() => this.onOpen(kind, ''))
    }.width('100%').margin({ top: 24, bottom: 12 })
  }
  build() {
    Refresh({ refreshing: $$this.refreshing }) {
      Scroll() {
        Column() {
          Row({ space: 8 }) {
            Image($r('app.media.app_icon')).width(32).height(32).borderRadius(8)
            Text('桃花坞刻版').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary).layoutWeight(1)
            ArtImage({ imageKey: this.feed.viewer.avatarKey || 'ip_taoyao', fit: ImageFit.Contain }).width(36).height(36).backgroundColor('#FBE0E7').borderRadius(18).clip(true)
              .accessibilityText(this.feed.viewer.nickname || '我的艺术空间').onClick(() => this.onOpen('mine', ''))
            Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.message')).fontSize(20).fontColor([Theme.colors().textPrimary]) }
              .width(36).height(36).backgroundColor('#FBE0E7').onClick(() => this.onOpen('notifications', ''))
          }.width('100%')
          Text('让传统年画，变成可爱的动漫世界。').fontSize(11).lineHeight(16).fontColor(Theme.colors().textSecondary).width('100%').margin({ top: 8, bottom: 18 })
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(18).fontColor([Theme.colors().textSecondary])
            Text('搜索角色、作品与文化知识').fontSize(14).fontColor(Theme.colors().textSecondary)
          }.width('100%').height(46).padding({ left: 16 }).backgroundColor('#F9EDE2').borderRadius(14)
            .onClick(() => this.onOpen('search', ''))
          if (this.loading || this.error) {
            LoadState({ loading: this.loading, message: this.error, onRetry: () => this.reload() })
          } else {
            if (!this.feed.hasContent()) {
              LoadState({ emptyText: '还没有公开内容，稍后再来看看', emptyImage: 'empty_search' })
              Button('重新加载首页').id('home-empty-retry').backgroundColor(Theme.colors().brandPrimary).onClick(() => this.reload())
            }
            if (this.feed.banners.length > 0) {
              Swiper() {
                ForEach(this.feed.banners, (banner: Banner) => {
                  Stack({ alignContent: Alignment.BottomStart }) {
                    ArtImage({ imageKey: banner.imageKey })
                    Column({ space: 5 }) {
                      Text(banner.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                      Text(banner.subtitle).fontSize(13).fontColor('#FFF8F0')
                    }.width('100%').padding(20).linearGradient({ angle: 0, colors: [['#B3493B3A', 0], ['#00493B3A', 1]] })
                  }.width('100%').height(164).borderRadius(24).clip(true).onClick(() => this.onOpen(banner.targetKind, banner.targetId))
                }, (b: Banner) => b.id)
              }.height(164).margin({ top: 18 }).effectMode(EdgeEffect.Spring).autoPlay(false)
                .indicator(new DotIndicator().color('#C9B5AF').selectedColor('#A93635').bottom(8))
            }
            if (this.feed.categories.length > 0) {
              this.title('萌物收藏馆', 'catalog')
              Grid() {
                ForEach(this.feed.categories, (category: Category) => {
                  GridItem() {
                    Column({ space: 6 }) {
                      ArtImage({ imageKey: category.coverKey }).height(100).borderRadius(16).clip(true)
                      Text(category.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.colors().textPrimary)
                    }.onClick(() => this.onOpen('category', category.id))
                  }
                }, (c: Category) => c.id)
              }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(14).height(Math.ceil(this.feed.categories.length / 2) * 132)
            }
            if (this.feed.characters.length > 0) {
              this.title('今日遇见的小伙伴', 'catalog')
              Scroll() {
                Row({ space: 12 }) {
                  ForEach(this.feed.characters, (character: Character) => {
                    Column({ space: 8 }) {
                      ArtImage({ imageKey: character.imageKey, fit: ImageFit.Contain }).width(140).height(160).backgroundColor('#FBE0E7').borderRadius(20)
                      Text(character.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Theme.colors().textPrimary)
                    }.onClick(() => this.onOpen('character', character.id))
                  }, (c: Character) => c.id)
                }
              }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
            }
            if (this.feed.artworks.length > 0) {
              this.title('灵感新作', 'plaza')
              ForEach(this.feed.artworks, (art: Artwork) => {
                Row({ space: 12 }) {
                  CreationCanvas({ document: art.document }).width(88).height(110).borderRadius(16).clip(true)
                  Column({ space: 8 }) {
                    Text(art.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.colors().textPrimary)
                    Text(`${art.origin === 'official' ? '官方精选' : '用户原创'}  ${art.authorName}`).fontSize(12).fontColor(Theme.colors().textSecondary)
                    Text(`${art.likeCount} 人喜欢`).fontSize(12).fontColor(Theme.colors().brandPrimary)
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                }.width('100%').margin({ bottom: 16 }).onClick(() => this.onOpen('artwork', art.id))
              }, (a: Artwork) => a.id)
            }
            if (this.feed.knowledge.length > 0) {
              this.title('年画小课堂', 'knowledge')
              ForEach(this.feed.knowledge, (article: KnowledgeArticle) => {
                Column({ space: 8 }) {
                  Text(article.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(Theme.colors().textPrimary)
                  Text(article.summary).fontSize(14).fontColor(Theme.colors().textSecondary).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text('文化资料 · 查看来源').fontSize(12).fontColor('#53785D')
                }.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor('#EEF3E9').borderRadius(18).margin({ bottom: 12 })
                  .onClick(() => this.onOpen('article', article.id))
              }, (a: KnowledgeArticle) => a.id)
            }
            if (this.feed.ranking.length > 0) {
              this.title('人气作品榜', 'plaza')
              ForEach(this.feed.ranking, (art: Artwork, index: number) => {
                Row({ space: 12 }) {
                  Text(`${index + 1}`).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#A93635').width(28)
                  CreationCanvas({ document: art.document }).width(56).height(70).borderRadius(10).clip(true)
                  Column({ space: 6 }) {
                    Text(art.title).fontSize(15).fontColor('#493B3A').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`${art.likeCount} 次真实喜欢`).fontSize(12).fontColor('#76615E')
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }.width('100%').padding({ top: 8, bottom: 8 }).onClick(() => this.onOpen('artwork', art.id))
              }, (a: Artwork) => a.id)
            }
            if (this.feed.recent.length > 0) {
              this.title('上次看到这里', 'history')
              ForEach(this.feed.recent, (item: Relation) => {
                Text(item.title).fontSize(15).fontColor('#493B3A').width('100%').padding({ top: 10, bottom: 10 })
                  .onClick(() => this.onOpen(item.available ? item.targetType : 'history', item.available ? item.targetId : ''))
              }, (r: Relation) => r.id)
            }
          }
        }.width('100%').padding({ left: 20, right: 20, top: 20, bottom: 30 })
      }.width('100%').height('100%').align(Alignment.TopStart).edgeEffect(EdgeEffect.Spring)
    }.onRefreshing(() => this.reload()).backgroundColor(Theme.colors().surfacePage)
  }
}
