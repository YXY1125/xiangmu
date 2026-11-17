import { ApiResponse } from '../models/ApiModels'
import { HomeFeed, Character, Category, Artwork, Banner, KnowledgeArticle, SourceReference, Material, Template,
  Creation, CanvasDocument, CanvasLayer, PageResult, TargetAction, Relation, UserProfile, Notification, Publication,
  ArtworkVersionRequest, PublicationRequest, ReportRequest, ReportReceipt, FeedbackRequest, Feedback, PublicAuthor } from '../models/ArtModels'
import { HttpClient } from './HttpClient'
import { SessionStore } from './SessionStore'
import { ArtDataChanges } from './ArtDataChanges'
import { CreationShelf } from '../models/CreationShelf'

const ROOT: string = '/biz/thwkb.zh.huawei'

export class ArtError extends Error {
  code: number = 50001
  constructor(code: number, message: string) { super(message); this.code = code }
}

export class ArtService {
  static relationTypeForApi(kind: string): string { return kind === 'article' ? 'knowledge' : kind }
  static relationTypeForPage(kind: string): string { return kind === 'knowledge' ? 'article' : kind }
  static text(value: string | undefined): string { return typeof value === 'string' ? value : '' }
  static number(value: number | undefined): number { return typeof value === 'number' && Number.isFinite(value) ? value : 0 }
  private static data<T>(res: ApiResponse<T>): T {
    if (res.code !== 0 || res.data === undefined || res.data === null) throw new ArtError(res.code, res.message || '未能读取内容')
    return res.data
  }
  private static sources(values: SourceReference[] | undefined): SourceReference[] {
    if (!Array.isArray(values)) return []
    return values.filter(v => v !== null && v !== undefined).map(v => {
      const source = new SourceReference()
      source.title = ArtService.text(v.title); source.url = ArtService.text(v.url)
      source.publisher = ArtService.text(v.publisher); source.accessedAt = ArtService.text(v.accessedAt)
      return source
    })
  }
  static character(v: Character): Character {
    const c = new Character()
    if (v === null || v === undefined) return c
    c.id = ArtService.text(v.id); c.name = ArtService.text(v.name); c.categoryId = ArtService.text(v.categoryId)
    c.categoryName = ArtService.text(v.categoryName); c.imageKey = ArtService.text(v.imageKey)
    c.story = ArtService.text(v.story); c.culturalMeaning = ArtService.text(v.culturalMeaning)
    c.inspiration = ArtService.text(v.inspiration); c.colorDescription = ArtService.text(v.colorDescription)
    c.designDescription = ArtService.text(v.designDescription); c.originalNotice = ArtService.text(v.originalNotice) || '现代原创角色设定'
    c.sources = ArtService.sources(v.sources); c.favorite = v.favorite === true
    c.relatedArtworkIds = Array.isArray(v.relatedArtworkIds) ? v.relatedArtworkIds.filter(id => typeof id === 'string') : []
    return c
  }
  static article(v: KnowledgeArticle): KnowledgeArticle {
    const a = new KnowledgeArticle()
    if (v === null || v === undefined) return a
    a.id = ArtService.text(v.id); a.title = ArtService.text(v.title); a.summary = ArtService.text(v.summary)
    a.categoryId = ArtService.text(v.categoryId); a.coverKey = ArtService.text(v.coverKey)
    a.body = ArtService.text(v.body); a.verifiedAt = ArtService.text(v.verifiedAt)
    a.sources = ArtService.sources(v.sources); a.favorite = v.favorite === true
    return a
  }
  static document(v: CanvasDocument | undefined): CanvasDocument {
    const d = new CanvasDocument()
    if (v === undefined || v === null) return d
    if (v.schemaVersion !== 1) throw new ArtError(422, '作品版本暂不支持，请更新应用')
    if ((v.width !== undefined && v.width !== 800) || (v.height !== undefined && v.height !== 1000)) throw new ArtError(422, '作品画布尺寸暂不支持')
    d.backgroundKey = ArtService.text(v.backgroundKey) || 'bg_handmade_paper'
    d.colorTheme = ArtService.text(v.colorTheme) || 'peach'
    if (Array.isArray(v.layers)) d.layers = v.layers.filter(l => l !== null && l !== undefined).slice(0, 60).map(l => {
      const layer = new CanvasLayer()
      layer.id = ArtService.text(l.id); layer.kind = l.kind === 'text' ? 'text' : 'image'
      layer.materialId = ArtService.text(l.materialId); layer.imageKey = ArtService.text(l.imageKey)
      layer.text = ArtService.text(l.text).slice(0, 80); layer.color = /^#[0-9A-Fa-f]{6}$/.test(l.color) ? l.color : '#493B3A'
      layer.x = Math.max(0, Math.min(1, ArtService.number(l.x))); layer.y = Math.max(0, Math.min(1, ArtService.number(l.y)))
      layer.scale = Math.max(.08, Math.min(1.5, ArtService.number(l.scale))); layer.rotation = Math.max(-360, Math.min(360, ArtService.number(l.rotation)))
      return layer
    })
    return d
  }
  static creation(v: Creation): Creation {
    const c = new Creation()
    if (v === null || v === undefined) return c
    c.id = ArtService.text(v.id); c.templateId = ArtService.text(v.templateId); c.title = ArtService.text(v.title); c.status = ArtService.text(v.status)
    c.revision = ArtService.number(v.revision); c.document = ArtService.document(v.document)
    c.updatedAt = ArtService.text(v.updatedAt)
    return c
  }
  static artwork(v: Artwork): Artwork {
    const a = new Artwork()
    if (v === null || v === undefined) return a
    a.id = ArtService.text(v.id); a.title = ArtService.text(v.title); a.description = ArtService.text(v.description)
    a.authorId = ArtService.text(v.authorId); a.authorName = ArtService.text(v.authorName)
    a.origin = ArtService.text(v.origin); a.coverKey = ArtService.text(v.coverKey); a.previewUrl = ArtService.text(v.previewUrl)
    a.document = ArtService.document(v.document); a.reviewStatus = ArtService.text(v.reviewStatus)
    a.copyrightSource = ArtService.text(v.copyrightSource); a.createdAt = ArtService.text(v.createdAt)
    a.likeCount = ArtService.number(v.likeCount); a.favoriteCount = ArtService.number(v.favoriteCount)
    a.liked = v.liked === true; a.favorite = v.favorite === true
    return a
  }
  static async home(): Promise<HomeFeed> {
    const v = ArtService.data(await HttpClient.get<HomeFeed>(`${ROOT}/home`))
    const feed = new HomeFeed()
    if (Array.isArray(v.banners)) feed.banners = v.banners.filter(b => b !== null && b !== undefined).map(b => {
      const a = new Banner(); a.id = ArtService.text(b.id); a.title = ArtService.text(b.title)
      a.subtitle = ArtService.text(b.subtitle); a.imageKey = ArtService.text(b.imageKey)
      a.targetKind = ArtService.text(b.targetKind); a.targetId = ArtService.text(b.targetId); return a
    }).filter(b => b.id.length > 0)
    if (Array.isArray(v.categories)) feed.categories = v.categories.filter(c => c !== null && c !== undefined).map(c => {
      const a = new Category(); a.id = ArtService.text(c.id); a.name = ArtService.text(c.name); a.coverKey = ArtService.text(c.coverKey); a.targetKind = c.targetKind === 'artwork' ? 'artwork' : 'character'; return a
    }).filter(c => c.id.length > 0)
    if (Array.isArray(v.characters)) feed.characters = v.characters.map(c => ArtService.character(c)).filter(c => c.id.length > 0)
    if (Array.isArray(v.artworks)) feed.artworks = v.artworks.map(a => ArtService.artwork(a)).filter(a => a.id.length > 0)
    if (Array.isArray(v.ranking)) feed.ranking = v.ranking.map(a => ArtService.artwork(a)).filter(a => a.id.length > 0)
    if (Array.isArray(v.knowledge)) feed.knowledge = v.knowledge.map(a => ArtService.article(a)).filter(a => a.id.length > 0)
    if (Array.isArray(v.recent)) feed.recent = v.recent.filter(v => v !== null && v !== undefined).map(v => {
      const a = new Relation(); a.id = ArtService.text(v.id); a.targetType = ArtService.relationTypeForPage(ArtService.text(v.targetType)); a.targetId = ArtService.text(v.targetId)
      a.title = ArtService.text(v.title); a.imageKey = ArtService.text(v.imageKey); a.updatedAt = ArtService.text(v.updatedAt); return a
    })
    if (v.viewer !== null && v.viewer !== undefined) {
      feed.viewer.nickname = ArtService.text(v.viewer.nickname); feed.viewer.avatarKey = ArtService.text(v.viewer.avatarKey)
    }
    return feed
  }
  static async characters(category: string, search: string): Promise<Character[]> {
    const v = ArtService.data(await HttpClient.get<PageResult<Character>>(`${ROOT}/characters?category=${encodeURIComponent(category)}&q=${encodeURIComponent(search)}`))
    return Array.isArray(v.items) ? v.items.map(c => ArtService.character(c)).filter(c => c.id.length > 0) : []
  }
  static async getCharacter(id: string): Promise<Character> { return ArtService.character(ArtService.data(await HttpClient.get<Character>(`${ROOT}/characters/${encodeURIComponent(id)}`))) }
  static async knowledge(search: string): Promise<KnowledgeArticle[]> {
    const v = ArtService.data(await HttpClient.get<PageResult<KnowledgeArticle>>(`${ROOT}/knowledge?q=${encodeURIComponent(search)}`))
    return Array.isArray(v.items) ? v.items.map(a => ArtService.article(a)).filter(a => a.id.length > 0) : []
  }
  static async getArticle(id: string): Promise<KnowledgeArticle> { return ArtService.article(ArtService.data(await HttpClient.get<KnowledgeArticle>(`${ROOT}/knowledge/${encodeURIComponent(id)}`))) }
  static async materials(): Promise<Material[]> {
    const v = ArtService.data(await HttpClient.get<PageResult<Material>>(`${ROOT}/materials`))
    return Array.isArray(v.items) ? v.items.filter(m => m !== null && m !== undefined).map(m => {
      const a = new Material(); a.id = ArtService.text(m.id); a.name = ArtService.text(m.name); a.kind = ArtService.text(m.kind)
      a.imageKey = ArtService.text(m.imageKey); a.source = ArtService.text(m.source); a.license = ArtService.text(m.license)
      a.copyrightOwner = ArtService.text(m.copyrightOwner); return a
    }).filter(m => m.id.length > 0) : []
  }
  static async templates(): Promise<Template[]> {
    const v = ArtService.data(await HttpClient.get<PageResult<Template>>(`${ROOT}/templates`))
    return Array.isArray(v.items) ? v.items.filter(t => t !== null && t !== undefined).map(t => {
      const a = new Template(); a.id = ArtService.text(t.id); a.name = ArtService.text(t.name); a.coverKey = ArtService.text(t.coverKey)
      a.document = ArtService.document(t.document); a.materialIds = Array.isArray(t.materialIds) ? t.materialIds.filter(id => typeof id === 'string') : []; return a
    }).filter(t => t.id.length > 0) : []
  }
  static async creations(): Promise<Creation[]> {
    const v = ArtService.data(await HttpClient.get<PageResult<Creation>>(`${ROOT}/creations`))
    return Array.isArray(v.items) ? v.items.map(c => ArtService.creation(c)).filter(c => c.id.length > 0) : []
  }
  static async getCreation(id: string): Promise<Creation> { return ArtService.creation(ArtService.data(await HttpClient.get<Creation>(`${ROOT}/creations/${encodeURIComponent(id)}`))) }
  static async savedCreations(): Promise<Creation[]> { return CreationShelf.completed(await ArtService.creations()) }
  static async draftCreations(): Promise<Creation[]> { return CreationShelf.drafts(await ArtService.creations()) }
  static async saveCreation(c: Creation): Promise<Creation> {
    const session = SessionStore.revision()
    const result = c.id ? await HttpClient.put<Creation>(`${ROOT}/creations/${encodeURIComponent(c.id)}`, c) : await HttpClient.post<Creation>(`${ROOT}/creations`, c)
    const saved = ArtService.creation(ArtService.data(result))
    ArtDataChanges.confirmed(session); return saved
  }
  static async plaza(search: string, order: string, cursor: string, category: string = ''): Promise<PageResult<Artwork>> {
    const v = ArtService.data(await HttpClient.get<PageResult<Artwork>>(`${ROOT}/plaza?q=${encodeURIComponent(search)}&order=${encodeURIComponent(order)}&cursor=${encodeURIComponent(cursor)}&category=${encodeURIComponent(category)}`))
    const page = new PageResult<Artwork>()
    page.items = Array.isArray(v.items) ? v.items.map(a => ArtService.artwork(a)).filter(a => a.id.length > 0) : []
    page.total = ArtService.number(v.total); page.nextCursor = ArtService.text(v.nextCursor); return page
  }
  static async getArtwork(id: string): Promise<Artwork> { return ArtService.artwork(ArtService.data(await HttpClient.get<Artwork>(`${ROOT}/artworks/${encodeURIComponent(id)}`))) }
  static async favorite(kind: string, id: string, active: boolean): Promise<void> {
    const session = SessionStore.revision()
    const targetType = ArtService.relationTypeForApi(kind)
    const body = new TargetAction(); body.targetType = targetType; body.targetId = id
    const res = active ? await HttpClient.post<Object>(`${ROOT}/favorites`, body) : await HttpClient.delete<Object>(`${ROOT}/favorites/${encodeURIComponent(targetType)}/${encodeURIComponent(id)}`)
    if (res.code !== 0) throw new ArtError(res.code, res.message)
    ArtDataChanges.confirmed(session)
  }
  static async like(id: string, active: boolean): Promise<void> {
    const res = active ? await HttpClient.post<Object>(`${ROOT}/artworks/${encodeURIComponent(id)}/like`) : await HttpClient.delete<Object>(`${ROOT}/artworks/${encodeURIComponent(id)}/like`)
    if (res.code !== 0) throw new ArtError(res.code, res.message)
  }
  static async history(kind: string, id: string): Promise<void> {
    const body = new TargetAction(); body.targetType = ArtService.relationTypeForApi(kind); body.targetId = id
    const res = await HttpClient.post<Object>(`${ROOT}/history`, body)
    if (res.code !== 0) throw new ArtError(res.code, res.message)
  }

  static async profile(): Promise<UserProfile> {
    const value = ArtService.data(await HttpClient.get<UserProfile>(`${ROOT}/profile`))
    const p = new UserProfile()
    p.userId = ArtService.text(value.userId); p.nickname = ArtService.text(value.nickname)
    p.avatarKey = ArtService.text(value.avatarKey); p.bio = ArtService.text(value.bio)
    p.workCount = ArtService.number(value.workCount); p.draftCount = ArtService.number(value.draftCount)
    p.favoriteCount = ArtService.number(value.favoriteCount); return p
  }
  static async updateProfile(value: UserProfile): Promise<void> {
    const session = SessionStore.revision()
    const response = await HttpClient.put<UserProfile>(`${ROOT}/profile`, value)
    if (response.code !== 0) throw new ArtError(response.code, response.message)
    ArtDataChanges.confirmed(session)
  }
  static async personalProfile(): Promise<UserProfile> {
    const session = SessionStore.revision()
    const profile = await ArtService.profile()
    if (session !== SessionStore.revision()) throw new ArtError(40101, '账号已变化，请重新加载')
    const creations = await ArtService.creations()
    if (session !== SessionStore.revision()) throw new ArtError(40101, '账号已变化，请重新加载')
    return CreationShelf.profile(profile, creations)
  }
  static async relations(kind: string): Promise<Relation[]> {
    if (kind !== 'favorites' && kind !== 'history') throw new ArtError(40001, '无效的记录类型')
    const value = ArtService.data(await HttpClient.get<PageResult<Relation>>(`${ROOT}/${kind}`))
    return Array.isArray(value.items) ? value.items.filter(v => v !== null && v !== undefined).map(v => {
      const a = new Relation(); a.id = ArtService.text(v.id); a.targetId = ArtService.text(v.targetId)
      a.targetType = ArtService.relationTypeForPage(ArtService.text(v.targetType)); a.title = ArtService.text(v.title)
      a.imageKey = ArtService.text(v.imageKey); a.updatedAt = ArtService.text(v.updatedAt); a.available = v.available !== false; return a
    }) : []
  }
  static async notifications(): Promise<Notification[]> {
    const value = ArtService.data(await HttpClient.get<PageResult<Notification>>(`${ROOT}/notifications`))
    return Array.isArray(value.items) ? value.items.filter(v => v !== null && v !== undefined).map(v => {
      const a = new Notification(); a.id = ArtService.text(v.id); a.kind = ArtService.text(v.kind)
      a.title = ArtService.text(v.title); a.body = ArtService.text(v.body); a.readAt = ArtService.text(v.readAt)
      a.targetRoute = ArtService.text(v.targetRoute); return a
    }) : []
  }
  static async readNotification(id: string): Promise<void> {
    const response = await HttpClient.put<Object>(`${ROOT}/notifications/${encodeURIComponent(id)}/read`)
    if (response.code !== 0) throw new ArtError(response.code, response.message)
  }
  static async myArtworks(): Promise<Artwork[]> {
    const value = ArtService.data(await HttpClient.get<PageResult<Artwork>>(`${ROOT}/artworks/mine`))
    return Array.isArray(value.items) ? value.items.map(v => ArtService.artwork(v)) : []
  }
  static async createArtwork(id: string, body: ArtworkVersionRequest): Promise<Artwork> {
    const session = SessionStore.revision()
    const artwork = ArtService.artwork(ArtService.data(await HttpClient.post<Artwork>(`${ROOT}/creations/${encodeURIComponent(id)}/artwork`, body)))
    ArtDataChanges.confirmed(session); return artwork
  }
  static async submitArtwork(id: string): Promise<Publication> {
    const session = SessionStore.revision()
    const body = new PublicationRequest(); body.rightsConfirmed = true
    const publication = ArtService.data(await HttpClient.post<Publication>(`${ROOT}/artworks/${encodeURIComponent(id)}/publications`, body))
    ArtDataChanges.confirmed(session); return publication
  }
  static async publications(): Promise<Publication[]> {
    const page = ArtService.data(await HttpClient.get<PageResult<Publication>>(`${ROOT}/publications/mine`))
    return Array.isArray(page.items) ? page.items.filter(v => v !== null && v !== undefined).map(v => {
      const item = new Publication(); item.id = ArtService.text(v.id); item.artworkId = ArtService.text(v.artworkId)
      item.status = ArtService.text(v.status); item.reason = ArtService.text(v.reason); item.updatedAt = ArtService.text(v.updatedAt); return item
    }).filter(v => v.id.length > 0) : []
  }
  static async reportArtwork(id: string, body: ReportRequest): Promise<ReportReceipt> {
    return ArtService.data(await HttpClient.post<ReportReceipt>(`${ROOT}/artworks/${encodeURIComponent(id)}/reports`, body))
  }
  static async myLikes(cursor: string = ''): Promise<PageResult<Artwork>> {
    const result = ArtService.data(await HttpClient.get<PageResult<Artwork>>(`${ROOT}/plaza?liked=mine&cursor=${encodeURIComponent(cursor)}`))
    const page = new PageResult<Artwork>(); page.items = Array.isArray(result.items) ? result.items.map(v => ArtService.artwork(v)).filter(v => v.id.length > 0) : []
    page.total = ArtService.number(result.total); page.nextCursor = ArtService.text(result.nextCursor); return page
  }
  static async archiveCreation(id: string): Promise<void> {
    const session = SessionStore.revision()
    const response = await HttpClient.delete<Object>(`${ROOT}/creations/${encodeURIComponent(id)}`)
    if (response.code !== 0) throw new ArtError(response.code, response.message)
    ArtDataChanges.confirmed(session)
  }
  static async author(id: string): Promise<PublicAuthor> {
    const value = ArtService.data(await HttpClient.get<PublicAuthor>(`${ROOT}/authors/${encodeURIComponent(id)}`))
    const author = new PublicAuthor(); author.id = ArtService.text(value.id); author.nickname = ArtService.text(value.nickname)
    author.avatarKey = ArtService.text(value.avatarKey); author.bio = ArtService.text(value.bio)
    author.artworks = Array.isArray(value.artworks) ? value.artworks.map(v => ArtService.artwork(v)).filter(v => v.id.length > 0) : []; return author
  }
  static async feedbacks(): Promise<Feedback[]> {
    const page = ArtService.data(await HttpClient.get<PageResult<Feedback>>(`${ROOT}/feedback`))
    return Array.isArray(page.items) ? page.items.filter(v => v !== null && v !== undefined).map(v => {
      const item = new Feedback(); item.id = ArtService.text(v.id); item.category = ArtService.text(v.category)
      item.body = ArtService.text(v.body); item.status = ArtService.text(v.status); item.reply = ArtService.text(v.reply); item.createdAt = ArtService.text(v.createdAt); return item
    }) : []
  }
  static async sendFeedback(body: FeedbackRequest): Promise<void> {
    ArtService.data(await HttpClient.post<Feedback>(`${ROOT}/feedback`, body))
  }
}
