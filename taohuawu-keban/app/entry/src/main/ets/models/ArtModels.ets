export class SourceReference {
  title: string = ''
  url: string = ''
  publisher: string = ''
  accessedAt: string = ''
}
export class Category {
  id: string = ''
  name: string = ''
  coverKey: string = ''
  targetKind: string = 'character'
}
export class Character {
  id: string = ''
  name: string = ''
  categoryId: string = ''
  categoryName: string = ''
  imageKey: string = ''
  story: string = ''
  culturalMeaning: string = ''
  inspiration: string = ''
  colorDescription: string = ''
  designDescription: string = ''
  originalNotice: string = '现代原创角色设定'
  sources: SourceReference[] = []
  relatedArtworkIds: string[] = []
  favorite: boolean = false
}
export class KnowledgeArticle {
  id: string = ''
  title: string = ''
  summary: string = ''
  categoryId: string = ''
  coverKey: string = ''
  body: string = ''
  sources: SourceReference[] = []
  verifiedAt: string = ''
  favorite: boolean = false
}
export class Material {
  id: string = ''
  name: string = ''
  kind: string = ''
  imageKey: string = ''
  source: string = ''
  license: string = ''
  copyrightOwner: string = ''
}
export class CanvasLayer {
  id: string = ''
  kind: string = 'image'
  materialId: string = ''
  imageKey: string = ''
  text: string = ''
  x: number = 0.5
  y: number = 0.5
  scale: number = 0.6
  rotation: number = 0
  color: string = '#493B3A'
}
export class CanvasDocument {
  schemaVersion: number = 1
  width: number = 800
  height: number = 1000
  backgroundKey: string = 'bg_handmade_paper'
  colorTheme: string = 'peach'
  layers: CanvasLayer[] = []
}
export class Creation {
  id: string = ''
  templateId: string = ''
  title: string = ''
  status: string = 'draft'
  revision: number = 0
  document: CanvasDocument = new CanvasDocument()
  updatedAt: string = ''
}
export class Template {
  id: string = ''
  name: string = ''
  coverKey: string = ''
  document: CanvasDocument = new CanvasDocument()
  materialIds: string[] = []
}
export class Artwork {
  id: string = ''
  title: string = ''
  description: string = ''
  authorId: string = ''
  authorName: string = ''
  origin: string = ''
  coverKey: string = ''
  previewUrl: string = ''
  document: CanvasDocument = new CanvasDocument()
  reviewStatus: string = ''
  copyrightSource: string = ''
  likeCount: number = 0
  favoriteCount: number = 0
  liked: boolean = false
  favorite: boolean = false
  createdAt: string = ''
}
export class Banner {
  id: string = ''
  title: string = ''
  subtitle: string = ''
  imageKey: string = ''
  targetKind: string = ''
  targetId: string = ''
}
export class HomeFeed {
  banners: Banner[] = []
  categories: Category[] = []
  characters: Character[] = []
  artworks: Artwork[] = []
  ranking: Artwork[] = []
  knowledge: KnowledgeArticle[] = []
  recent: Relation[] = []
  viewer: UserProfile = new UserProfile()
  hasContent(): boolean {
    return this.banners.length > 0 || this.categories.length > 0 || this.characters.length > 0 ||
      this.artworks.length > 0 || this.ranking.length > 0 || this.knowledge.length > 0 || this.recent.length > 0
  }
}
export class PageResult<T> {
  items: T[] = []
  total: number = 0
  nextCursor: string = ''
}
export class TargetAction {
  targetType: string = ''
  targetId: string = ''
}
export class Relation {
  id: string = ''
  targetType: string = ''
  targetId: string = ''
  title: string = ''
  imageKey: string = ''
  updatedAt: string = ''
  available: boolean = true
}
export class UserProfile {
  userId: string = ''
  nickname: string = ''
  avatarKey: string = ''
  bio: string = ''
  workCount: number = 0
  draftCount: number = 0
  favoriteCount: number = 0
}
export class Notification {
  id: string = ''
  kind: string = ''
  title: string = ''
  body: string = ''
  readAt: string = ''
  targetRoute: string = ''
}
export class Publication {
  id: string = ''
  artworkId: string = ''
  status: string = ''
  reason: string = ''
  updatedAt: string = ''
}
export class ArtworkVersionRequest {
  copyrightDeclaration: string = ''
  description: string = ''
}
export class PublicationRequest { rightsConfirmed: boolean = false }
export class ReportRequest {
  reasonCode: string = 'copyright'
  description: string = ''
}
export class ReportReceipt {
  id: string = ''
  status: string = ''
}
export class FeedbackRequest { category: string = 'suggestion'; body: string = '' }
export class Feedback {
  id: string = ''; category: string = ''; body: string = ''; status: string = ''; reply: string = ''; createdAt: string = ''
}
export class PublicAuthor {
  id: string = ''; nickname: string = ''; avatarKey: string = ''; bio: string = ''; artworks: Artwork[] = []
}
