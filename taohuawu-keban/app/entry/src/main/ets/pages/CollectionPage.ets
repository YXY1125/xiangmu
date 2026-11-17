import { Theme } from '../components/design-system/Theme'
import { ArtImage } from '../components/ArtImage'
import { LoadState } from '../components/LoadState'
import { Character, KnowledgeArticle, Artwork, Category } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { SessionStore } from '../services/SessionStore'
import { CreationCanvas } from '../components/CreationCanvas'

@Component
export struct CollectionPage {
  @Prop mode: string = 'catalog'
  @Prop initialCategory: string = ''
  @State category: string = ''
  @State query: string = ''
  @State order: string = 'latest'
  @State categories: Category[] = []
  @State characters: Character[] = []
  @State articles: KnowledgeArticle[] = []
  @State artworks: Artwork[] = []
  @State loading: boolean = true
  @State error: string = ''
  @State partialError: string = ''
  @State cursor: string = ''
  @StorageLink('sessionRevision') @Watch('sessionChanged') revision: number = 0
  private requestId: number = 0
  onOpen: (kind: string, id: string) => void = () => {}
  aboutToAppear(): void { this.category = this.initialCategory; this.reload() }
  private sessionChanged(): void { this.reload(false) }
  private async reload(append: boolean = false): Promise<void> {
    const request = ++this.requestId; const session = SessionStore.revision()
    this.loading = true; this.error = ''; this.partialError = ''
    if (!append) { this.cursor = ''; this.characters = []; this.articles = []; this.artworks = [] }
    try {
      if (this.mode === 'search') {
        try { const values = await ArtService.characters('', this.query); if (request === this.requestId && session === SessionStore.revision()) this.characters = values }
        catch { if (request === this.requestId && session === SessionStore.revision()) this.partialError = '部分搜索结果读取失败，可重试；已成功结果仍保留。' }
        if (request !== this.requestId || session !== SessionStore.revision()) return
        try { const values = await ArtService.knowledge(this.query); if (request === this.requestId && session === SessionStore.revision()) this.articles = values }
        catch { if (request === this.requestId && session === SessionStore.revision()) this.partialError = '部分搜索结果读取失败，可重试；已成功结果仍保留。' }
        if (request !== this.requestId || session !== SessionStore.revision()) return
        try {
          const works = await ArtService.plaza(this.query, 'latest', append ? this.cursor : '')
          if (request === this.requestId && session === SessionStore.revision()) {
            this.artworks = append ? this.artworks.concat(works.items.filter(a => !this.artworks.some(old => old.id === a.id))) : works.items
            this.cursor = works.nextCursor
          }
        }
        catch { if (request === this.requestId && session === SessionStore.revision()) this.partialError = '部分搜索结果读取失败，可重试；已成功结果仍保留。' }
        if (this.empty() && this.partialError) this.error = this.partialError
      } else if (this.mode === 'knowledge') {
        const values = await ArtService.knowledge(this.query)
        if (request === this.requestId && session === SessionStore.revision()) this.articles = values
      } else if (this.mode === 'plaza') {
        const page = await ArtService.plaza(this.query, this.order, append ? this.cursor : '')
        if (request === this.requestId && session === SessionStore.revision()) {
          this.artworks = append ? this.artworks.concat(page.items.filter(a => !this.artworks.some(old => old.id === a.id))) : page.items
          this.cursor = page.nextCursor
        }
      } else {
        if (this.categories.length === 0) {
          const feed = await ArtService.home()
          if (request === this.requestId && session === SessionStore.revision()) this.categories = feed.categories
        }
        if (request !== this.requestId || session !== SessionStore.revision()) return
        if (this.artworkCatalog()) {
          const page = await ArtService.plaza(this.query, 'latest', append ? this.cursor : '', this.category)
          if (request === this.requestId && session === SessionStore.revision()) {
            this.artworks = append ? this.artworks.concat(page.items.filter(a => !this.artworks.some(old => old.id === a.id))) : page.items
            this.cursor = page.nextCursor
          }
        } else {
          const values = await ArtService.characters(this.category, this.query)
          if (request === this.requestId && session === SessionStore.revision()) this.characters = values
        }
      }
    } catch (error) {
      if (request === this.requestId && session === SessionStore.revision()) {
        if (append && !this.empty()) this.partialError = '更多结果加载失败，已有内容仍保留，可重试。'
        else this.error = (error as ArtError).message || '内容读取失败'
      }
    }
    finally { if (request === this.requestId) this.loading = false }
  }
  private empty(): boolean { return this.characters.length + this.articles.length + this.artworks.length === 0 }
  private artworkCatalog(): boolean { return this.mode === 'catalog' && this.categories.some(c => c.id === this.category && c.targetKind === 'artwork') }
  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.mode === 'search' ? '寻找桃花灵感' : this.mode === 'knowledge' ? '年画小课堂' : this.mode === 'plaza' ? '灵感集市' : '萌物收藏馆')
          .fontSize(26).fontWeight(FontWeight.Bold).fontColor(Theme.colors().textPrimary)
        Blank()
        if (this.mode === 'catalog') Text('文化小课堂').fontSize(13).fontColor(Theme.colors().brandPrimary).onClick(() => this.onOpen('knowledge', ''))
      }.width('100%')
      Row({ space: 8 }) {
        TextInput({ text: this.query, placeholder: '输入关键词' }).layoutWeight(1).height(44).backgroundColor('#F9EDE2')
          .onChange((value: string) => { this.query = value }).onSubmit(() => this.reload())
        Button('搜索').height(44).backgroundColor(Theme.colors().brandPrimary).onClick(() => this.reload())
      }.width('100%')
      if (this.mode === 'catalog') {
        Scroll() {
          Row({ space: 8 }) {
            Button('全部').backgroundColor(this.category === '' ? '#A93635' : '#F9EDE2').fontColor(this.category === '' ? '#FFFFFF' : '#493B3A')
              .onClick(() => { this.category = ''; this.reload() })
            ForEach(this.categories, (c: Category) => {
              Button(c.name).backgroundColor(this.category === c.id ? '#A93635' : '#F9EDE2').fontColor(this.category === c.id ? '#FFFFFF' : '#493B3A')
                .onClick(() => { this.category = c.id; this.reload() })
            }, (c: Category) => c.id)
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      }
      if (this.mode === 'plaza') {
        Row({ space: 12 }) {
          ForEach(['latest', 'popular', 'official'], (sort: string) => {
            Button(sort === 'latest' ? '最新' : sort === 'popular' ? '热门' : '官方精选')
              .backgroundColor(this.order === sort ? '#A93635' : '#F9EDE2').fontColor(this.order === sort ? '#FFFFFF' : '#493B3A')
              .onClick(() => { this.order = sort; this.reload() })
          })
        }.width('100%')
      }
      if (this.partialError && !this.error) Text(this.partialError).fontSize(12).fontColor('#A93635').onClick(() => this.reload())
      if ((this.loading && this.empty()) || this.error || this.empty()) {
        LoadState({ loading: this.loading, message: this.error, emptyText: '暂未找到相关内容，试试其他关键词', onRetry: () => this.reload() }).layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            if (this.mode === 'catalog' && !this.artworkCatalog() || this.mode === 'search') {
              if (this.mode === 'search' && this.characters.length > 0) Text('原创角色').fontSize(18).fontColor('#493B3A').width('100%')
              Grid() {
                ForEach(this.characters, (character: Character) => {
                  GridItem() {
                    Column({ space: 8 }) {
                      ArtImage({ imageKey: character.imageKey, fit: ImageFit.Contain }).height(172).backgroundColor('#FBE0E7').borderRadius(20)
                      Text(character.name).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#493B3A')
                      Text(character.categoryName).fontSize(12).fontColor('#76615E')
                    }.width('100%').onClick(() => this.onOpen('character', character.id))
                  }
                }, (c: Character) => c.id)
              }.columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(20).height(Math.ceil(this.characters.length / 2) * 232)
            }
            if (this.mode === 'knowledge' || this.mode === 'search') {
              if (this.mode === 'search' && this.articles.length > 0) Text('文化知识').fontSize(18).fontColor('#493B3A').width('100%')
              ForEach(this.articles, (article: KnowledgeArticle) => {
                Column({ space: 10 }) {
                  ArtImage({ imageKey: article.coverKey }).height(170).borderRadius(20).clip(true)
                  Text(article.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#493B3A')
                  Text(article.summary).fontSize(14).fontColor('#76615E').maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${article.sources.length} 条资料来源`).fontSize(12).fontColor('#53785D')
                }.width('100%').alignItems(HorizontalAlign.Start).onClick(() => this.onOpen('article', article.id))
              }, (a: KnowledgeArticle) => a.id)
            }
            if (this.mode === 'plaza' || this.mode === 'search' || this.artworkCatalog()) {
              if (this.mode === 'search' && this.artworks.length > 0) Text('作品灵感').fontSize(18).fontColor('#493B3A').width('100%')
              ForEach(this.artworks, (art: Artwork) => {
                Column({ space: 8 }) {
                  CreationCanvas({ document: art.document }).borderRadius(20).clip(true)
                  Row() {
                    Text(art.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A').layoutWeight(1)
                    Text(`${art.likeCount} 喜欢`).fontSize(12).fontColor('#A93635')
                  }.width('100%')
                  Text(`${art.origin === 'official' ? '官方作品' : '用户原创'}  ${art.authorName}`).fontSize(13).fontColor('#76615E')
                }.width('100%').alignItems(HorizontalAlign.Start).onClick(() => this.onOpen('artwork', art.id))
              }, (a: Artwork) => a.id)
              if (this.cursor) Button(this.loading ? '加载中…' : '加载更多').enabled(!this.loading).onClick(() => this.reload(true))
            }
          }.width('100%').padding({ bottom: 24 })
        }.layoutWeight(1).edgeEffect(EdgeEffect.Spring)
      }
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 20 }).backgroundColor(Theme.colors().surfacePage)
  }
}
