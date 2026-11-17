import { ApiResponse, EmptyPayload } from '../models/ApiModels'
import {
  BrewRecordDraft,
  ActivityDay,
  ActivityStats,
  CoffeeRecord,
  CoffeeRecordList,
  EvaluationAverages,
  EvaluationStats,
  FlavorScores,
  MediaUploadResult,
  MethodCount,
  RecordPayload,
  TagCount,
  UserProfile,
  UserRecipeDraft,
  UserSummary
} from '../models/CoffeeModels'
import { HttpClient } from './HttpClient'
import { CoffeeSync } from './CoffeeSync'

export class CoffeeApi {
  private static prefix: string = '/biz/kafyj.zy.huawei'

  private static async write<T>(path: string, body: object, method: string = 'POST'): Promise<ApiResponse<T>> {
    const result = method === 'PUT' ? await HttpClient.put<T>(path, body) : await HttpClient.post<T>(path, body)
    if (result.code === 0) CoffeeSync.bump()
    return result
  }

  private static number(value: number, fallback: number = 0): number {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : fallback
  }

  private static record(source: CoffeeRecord): CoffeeRecord {
    const row = new CoffeeRecord()
    const payload = source.payload ?? new RecordPayload()
    const scores = payload.scores ?? new FlavorScores()
    row.id = `${source.id ?? ''}`
    row.kind = `${source.kind ?? ''}`
    row.status = `${source.status ?? 'active'}`
    row.version = CoffeeApi.number(source.version, 1)
    row.parentVersionId = `${source.parentVersionId ?? ''}`
    row.createdAt = `${source.createdAt ?? ''}`
    row.updatedAt = `${source.updatedAt ?? ''}`
    row.payload.coffeeName = `${payload.coffeeName ?? ''}`
    row.payload.bean = `${payload.bean ?? ''}`
    row.payload.method = `${payload.method ?? ''}`
    row.payload.equipment = `${payload.equipment ?? ''}`
    row.payload.grind = `${payload.grind ?? ''}`
    row.payload.note = `${payload.note ?? ''}`
    row.payload.name = `${payload.name ?? ''}`
    row.payload.steps = `${payload.steps ?? ''}`
    row.payload.flavor = `${payload.flavor ?? ''}`
    row.payload.knowledgeId = `${payload.knowledgeId ?? ''}`
    row.payload.targetType = `${payload.targetType ?? ''}`
    row.payload.targetId = `${payload.targetId ?? ''}`
    row.payload.imageKey = `${payload.imageKey ?? ''}`
    row.payload.coverKey = `${payload.coverKey ?? ''}`
    row.payload.dose = CoffeeApi.number(payload.dose)
    row.payload.water = CoffeeApi.number(payload.water)
    row.payload.temperature = CoffeeApi.number(payload.temperature)
    row.payload.durationSeconds = CoffeeApi.number(payload.durationSeconds)
    row.payload.ratio = CoffeeApi.number(payload.ratio)
    row.payload.tags = Array.isArray(payload.tags) ? payload.tags.map((value: string) => `${value}`) : []
    row.payload.scores.acidity = CoffeeApi.number(scores.acidity)
    row.payload.scores.sweetness = CoffeeApi.number(scores.sweetness)
    row.payload.scores.bitterness = CoffeeApi.number(scores.bitterness)
    row.payload.scores.body = CoffeeApi.number(scores.body)
    row.payload.scores.aroma = CoffeeApi.number(scores.aroma)
    row.payload.scores.aftertaste = CoffeeApi.number(scores.aftertaste)
    row.payload.scores.overall = CoffeeApi.number(scores.overall)
    return row
  }

  private static async records(path: string): Promise<ApiResponse<CoffeeRecordList>> {
    const result = await HttpClient.get<CoffeeRecordList>(path)
    if (result.code === 0 && result.data !== undefined) {
      const list = new CoffeeRecordList()
      list.items = Array.isArray(result.data.items) ? result.data.items.map((row: CoffeeRecord) => CoffeeApi.record(row)) : []
      result.data = list
    }
    return result
  }

  static saveBrew(record: BrewRecordDraft): Promise<ApiResponse<CoffeeRecord>> {
    return CoffeeApi.write<CoffeeRecord>(`${CoffeeApi.prefix}/me/brewing-records`, record)
  }

  static listBrews(): Promise<ApiResponse<CoffeeRecordList>> {
    return CoffeeApi.records(`${CoffeeApi.prefix}/me/brewing-records`)
  }

  static saveRecipe(recipe: UserRecipeDraft): Promise<ApiResponse<CoffeeRecord>> {
    return CoffeeApi.write<CoffeeRecord>(`${CoffeeApi.prefix}/me/recipes`, recipe)
  }

  static updateRecipe(id: string, recipe: UserRecipeDraft): Promise<ApiResponse<CoffeeRecord>> {
    return CoffeeApi.write<CoffeeRecord>(`${CoffeeApi.prefix}/me/recipes/${id}`, recipe, 'PUT')
  }

  static listUserRecipes(): Promise<ApiResponse<CoffeeRecordList>> {
    return CoffeeApi.records(`${CoffeeApi.prefix}/me/recipes`)
  }

  static archiveRecipe(id: string): Promise<ApiResponse<CoffeeRecord>> {
    return CoffeeApi.write<CoffeeRecord>(`${CoffeeApi.prefix}/me/recipes/${id}/archive`, new EmptyPayload(), 'PUT')
  }

  static async saveEvaluation(bean: string, method: string, tags: string[], scores: FlavorScores, note: string): Promise<ApiResponse<CoffeeRecord>> {
    const body = new EvaluationPayload()
    body.bean = bean
    body.method = method
    body.tags = tags
    body.scores = scores
    body.note = note
    return CoffeeApi.write<CoffeeRecord>(`${CoffeeApi.prefix}/me/evaluations`, body)
  }

  static listEvaluations(): Promise<ApiResponse<CoffeeRecordList>> {
    return CoffeeApi.records(`${CoffeeApi.prefix}/me/evaluations`)
  }

  static async evaluationStats(): Promise<ApiResponse<EvaluationStats>> {
    const result = await HttpClient.get<EvaluationStats>(`${CoffeeApi.prefix}/me/evaluations/stats`)
    if (result.code === 0 && result.data !== undefined) {
      const source = result.data
      const values = source.averages ?? new EvaluationAverages()
      const stats = new EvaluationStats()
      stats.count = CoffeeApi.number(source.count)
      stats.averages.acidity = CoffeeApi.number(values.acidity)
      stats.averages.sweetness = CoffeeApi.number(values.sweetness)
      stats.averages.bitterness = CoffeeApi.number(values.bitterness)
      stats.averages.body = CoffeeApi.number(values.body)
      stats.averages.aroma = CoffeeApi.number(values.aroma)
      stats.averages.aftertaste = CoffeeApi.number(values.aftertaste)
      stats.averages.overall = CoffeeApi.number(values.overall)
      stats.tags = (Array.isArray(source.tags) ? source.tags : []).map((value: TagCount) => {
        const tag = new TagCount()
        tag.name = `${value.name ?? ''}`
        tag.count = CoffeeApi.number(value.count)
        return tag
      })
      result.data = stats
    }
    return result
  }

  static saveLearning(knowledgeId: string): Promise<ApiResponse<CoffeeRecord>> {
    const payload = new LearningPayload()
    payload.knowledgeId = knowledgeId
    return CoffeeApi.write<CoffeeRecord>(`${CoffeeApi.prefix}/me/learning`, payload)
  }

  static listLearning(): Promise<ApiResponse<CoffeeRecordList>> {
    return CoffeeApi.records(`${CoffeeApi.prefix}/me/learning`)
  }

  static saveFavorite(targetType: string, targetId: string): Promise<ApiResponse<CoffeeRecord>> {
    const payload = new FavoritePayload()
    payload.targetType = targetType
    payload.targetId = targetId
    return CoffeeApi.write<CoffeeRecord>(`${CoffeeApi.prefix}/me/favorites`, payload)
  }

  static listFavorites(): Promise<ApiResponse<CoffeeRecordList>> {
    return CoffeeApi.records(`${CoffeeApi.prefix}/me/favorites`)
  }

  static async hasFavorite(targetType: string, targetId: string): Promise<ApiResponse<boolean>> {
    const source = await CoffeeApi.listFavorites()
    const result = new ApiResponse<boolean>()
    result.code = source.code
    result.message = source.message
    result.data = source.code === 0 && source.data !== undefined && source.data.items.some((row: CoffeeRecord) =>
      row.status === 'active' && row.payload.targetType === targetType && row.payload.targetId === targetId)
    return result
  }

  static checkIn(): Promise<ApiResponse<CoffeeRecord>> {
    return CoffeeApi.write<CoffeeRecord>(`${CoffeeApi.prefix}/me/checkins`, new EmptyPayload())
  }

  static async growth(): Promise<ApiResponse<UserSummary>> {
    const result = await HttpClient.get<UserSummary>(`${CoffeeApi.prefix}/me/growth`)
    if (result.code === 0 && result.data !== undefined) {
      const source = result.data
      const summary = new UserSummary()
      summary.learningCount = CoffeeApi.number(source.learningCount)
      summary.brewCount = CoffeeApi.number(source.brewCount)
      summary.recipeCount = CoffeeApi.number(source.recipeCount)
      summary.evaluationCount = CoffeeApi.number(source.evaluationCount)
      summary.favoriteCount = CoffeeApi.number(source.favoriteCount)
      summary.recipeFavoriteCount = CoffeeApi.number(source.recipeFavoriteCount)
      summary.checkInCount = CoffeeApi.number(source.checkInCount)
      summary.experience = CoffeeApi.number(source.experience)
      result.data = summary
    }
    return result
  }

  static async activityStats(): Promise<ApiResponse<ActivityStats>> {
    const result = await HttpClient.get<ActivityStats>(`${CoffeeApi.prefix}/me/activity-stats`)
    if (result.code === 0 && result.data !== undefined) {
      const source = result.data
      const stats = new ActivityStats()
      stats.days = (Array.isArray(source.days) ? source.days : []).map((value: ActivityDay) => {
        const day = new ActivityDay()
        day.date = `${value.date ?? ''}`
        day.label = `${value.label ?? ''}`
        day.brewCount = CoffeeApi.number(value.brewCount)
        day.learningCount = CoffeeApi.number(value.learningCount)
        day.evaluationCount = CoffeeApi.number(value.evaluationCount)
        return day
      })
      stats.methods = (Array.isArray(source.methods) ? source.methods : []).map((value: MethodCount) => {
        const method = new MethodCount()
        method.name = `${value.name ?? ''}`
        method.count = CoffeeApi.number(value.count)
        return method
      })
      result.data = stats
    }
    return result
  }

  static async uploadImage(mimeType: string, dataBase64: string): Promise<ApiResponse<MediaUploadResult>> {
    const body = new MediaUploadPayload()
    body.mimeType = mimeType
    body.dataBase64 = dataBase64
    return HttpClient.post<MediaUploadResult>(`${CoffeeApi.prefix}/media/images`, body)
  }

  static async profile(): Promise<ApiResponse<UserProfile>> {
    const result = await HttpClient.get<UserProfile>(`${CoffeeApi.prefix}/me/profile`)
    if (result.code === 0 && result.data !== undefined) {
      const source = result.data
      const profile = new UserProfile()
      profile.nickname = `${source.nickname ?? ''}`
      profile.bio = `${source.bio ?? ''}`
      profile.interestDirections = Array.isArray(source.interestDirections) ? source.interestDirections.map((value: string) => `${value}`) : []
      profile.updatedAt = `${source.updatedAt ?? ''}`
      result.data = profile
    }
    return result
  }

  static saveProfile(profile: UserProfile): Promise<ApiResponse<UserProfile>> {
    return CoffeeApi.write<UserProfile>(`${CoffeeApi.prefix}/me/profile`, profile, 'PUT')
  }

  static closeAccount(): Promise<ApiResponse<EmptyPayload>> {
    return CoffeeApi.write<EmptyPayload>('/privacy/account-close', new EmptyPayload())
  }
}

class EvaluationPayload {
  bean: string = ''
  method: string = ''
  tags: string[] = []
  scores: FlavorScores = new FlavorScores()
  note: string = ''
}

class LearningPayload { knowledgeId: string = '' }
class FavoritePayload { targetType: string = ''; targetId: string = '' }
class MediaUploadPayload { mimeType: string = ''; dataBase64: string = '' }
