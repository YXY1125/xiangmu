import { HttpClient } from './HttpClient'
import { CharacterProfile, CreativeTemplate, CultureArticle, Exhibition } from '../models/CultureModels'

class ListPayload<T> {
  items: T[] = []
  total: number = 0
}

class CharacterWire extends CharacterProfile { assetKey: string = '' }
class ArticleWire extends CultureArticle { coverKey: string = '' }
class ExhibitionWire extends Exhibition { coverKey: string = '' }

export class ContentService {
  static async characters(): Promise<CharacterProfile[]> {
    const response = await HttpClient.get<ListPayload<CharacterWire>>('/biz/zxznh.xcl.huawei/characters')
    if (response.code !== 0 || response.data === undefined || !Array.isArray(response.data.items)) return []
    return response.data.items.map((wire: CharacterWire) => {
      const item = new CharacterProfile()
      item.id = wire.id || ''
      item.name = wire.name || ''
      item.series = wire.series || ''
      item.image = wire.assetKey || wire.image || ''
      item.personality = wire.personality || ''
      item.origin = wire.origin || ''
      item.meaning = wire.meaning || ''
      item.story = wire.story || '原创角色故事正在编辑完善。'
      return item
    }).filter((item: CharacterProfile) => item.id.length > 0 && item.image.length > 0)
  }

  static async articles(): Promise<CultureArticle[]> {
    const response = await HttpClient.get<ListPayload<ArticleWire>>('/biz/zxznh.xcl.huawei/articles')
    if (response.code !== 0 || response.data === undefined || !Array.isArray(response.data.items)) return []
    return response.data.items.map((wire: ArticleWire) => {
      const item = new CultureArticle()
      item.id = wire.id || ''
      item.title = wire.title || ''
      item.category = wire.category || ''
      item.summary = wire.summary || ''
      item.body = wire.body || ''
      item.image = wire.coverKey || wire.image || ''
      item.sourceNote = wire.sourceNote || '来源记录待运营端补充'
      item.original = wire.original === true
      return item
    }).filter((item: CultureArticle) => item.id.length > 0)
  }

  static async exhibitions(): Promise<Exhibition[]> {
    const response = await HttpClient.get<ListPayload<ExhibitionWire>>('/biz/zxznh.xcl.huawei/exhibitions')
    if (response.code !== 0 || response.data === undefined || !Array.isArray(response.data.items)) return []
    return response.data.items.map((wire: ExhibitionWire) => {
      const item = new Exhibition()
      item.id = wire.id || ''
      item.title = wire.title || ''
      item.intro = wire.intro || ''
      item.image = wire.coverKey || wire.image || ''
      item.itemIds = Array.isArray(wire.itemIds) ? wire.itemIds : []
      return item
    }).filter((item: Exhibition) => item.id.length > 0)
  }

  static async templates(): Promise<CreativeTemplate[]> {
    const response = await HttpClient.get<ListPayload<CreativeTemplate>>('/biz/zxznh.xcl.huawei/creative/templates')
    if (response.code !== 0 || response.data === undefined || !Array.isArray(response.data.items)) return []
    return response.data.items.filter((item: CreativeTemplate) => item.id !== undefined && item.id.length > 0)
  }
}
