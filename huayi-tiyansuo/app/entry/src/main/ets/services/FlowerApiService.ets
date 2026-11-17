import { ApiResponse } from '../models/ApiModels'
import { EmptyFlowerPayload, FlowerChallenge, FlowerEvent, FlowerMaterial, FlowerTheme, FlowerTutorial, FlowerWork, HomePayload, MeDashboardPayload, PagePayload, StudioSnapshot, UserAchievement } from '../models/FlowerModels'
import { HttpClient } from './HttpClient'

class WorkWritePayload {
  title: string = ''
  status: string = 'draft'
  visibility: string = 'private'
  canvas: StudioSnapshot = new StudioSnapshot()
  themeName: string = '自由创作'
  challengeId: string = ''
}
class InteractionPayload { action: string = '' }
class ProgressPayload { step: number = 0; completed: boolean = false }
class EventSubmitPayload { workId: string = '' }

export class FlowerApiService {
  static home(): Promise<ApiResponse<HomePayload>> { return HttpClient.get<HomePayload>('/floral/home') }
  static materials(query: string = '', category: string = ''): Promise<ApiResponse<PagePayload<FlowerMaterial>>> {
    return HttpClient.get<PagePayload<FlowerMaterial>>(`/floral/materials?q=${encodeURIComponent(query)}&category=${encodeURIComponent(category)}`)
  }
  static material(id: string): Promise<ApiResponse<FlowerMaterial>> { return HttpClient.get<FlowerMaterial>(`/floral/materials/${id}`) }
  static favoriteMaterial(id: string): Promise<ApiResponse<EmptyFlowerPayload>> { return HttpClient.post<EmptyFlowerPayload>(`/floral/materials/${id}/favorite`) }
  static tutorials(): Promise<ApiResponse<PagePayload<FlowerTutorial>>> { return HttpClient.get<PagePayload<FlowerTutorial>>('/floral/tutorials') }
  static favoriteTutorial(id: string): Promise<ApiResponse<EmptyFlowerPayload>> { return HttpClient.post<EmptyFlowerPayload>(`/floral/tutorials/${id}/favorite`) }
  static themes(): Promise<ApiResponse<PagePayload<FlowerTheme>>> { return HttpClient.get<PagePayload<FlowerTheme>>('/floral/themes') }
  static challenges(): Promise<ApiResponse<PagePayload<FlowerChallenge>>> { return HttpClient.get<PagePayload<FlowerChallenge>>('/floral/challenges') }
  static tutorialProgress(id: string, step: number, completed: boolean): Promise<ApiResponse<EmptyFlowerPayload>> {
    const body = new ProgressPayload(); body.step = step; body.completed = completed
    return HttpClient.put<EmptyFlowerPayload>(`/floral/tutorials/${id}/progress`, body)
  }
  static works(sort: string = 'recommended'): Promise<ApiResponse<PagePayload<FlowerWork>>> { return HttpClient.get<PagePayload<FlowerWork>>(`/floral/works?sort=${sort}`) }
  static myWorks(): Promise<ApiResponse<PagePayload<FlowerWork>>> { return HttpClient.get<PagePayload<FlowerWork>>('/floral/me/works') }
  static saveWork(title: string, status: string, snapshot: StudioSnapshot, themeName: string = '自由创作', challengeId: string = ''): Promise<ApiResponse<FlowerWork>> {
    const body = new WorkWritePayload(); body.title = title; body.status = status; body.visibility = status === 'published' ? 'public' : 'private'; body.canvas = snapshot; body.themeName = themeName; body.challengeId = challengeId
    return HttpClient.post<FlowerWork>('/floral/works', body)
  }
  static updateWork(id: string, title: string, status: string, snapshot: StudioSnapshot, themeName: string = '自由创作', challengeId: string = ''): Promise<ApiResponse<FlowerWork>> {
    const body = new WorkWritePayload(); body.title = title; body.status = status; body.visibility = status === 'published' ? 'public' : 'private'; body.canvas = snapshot; body.themeName = themeName; body.challengeId = challengeId
    return HttpClient.put<FlowerWork>(`/floral/works/${id}`, body)
  }
  static interactWork(id: string, action: string): Promise<ApiResponse<FlowerWork>> {
    const body = new InteractionPayload(); body.action = action
    return HttpClient.put<FlowerWork>(`/floral/works/${id}/interaction`, body)
  }
  static events(): Promise<ApiResponse<PagePayload<FlowerEvent>>> { return HttpClient.get<PagePayload<FlowerEvent>>('/floral/events') }
  static joinEvent(id: string): Promise<ApiResponse<FlowerEvent>> { return HttpClient.post<FlowerEvent>(`/floral/events/${id}/join`) }
  static submitEvent(id: string, workId: string): Promise<ApiResponse<EmptyFlowerPayload>> {
    const body = new EventSubmitPayload(); body.workId = workId
    return HttpClient.post<EmptyFlowerPayload>(`/floral/events/${id}/submissions`, body)
  }
  static achievements(): Promise<ApiResponse<PagePayload<UserAchievement>>> { return HttpClient.get<PagePayload<UserAchievement>>('/floral/me/achievements') }
  static meDashboard(): Promise<ApiResponse<MeDashboardPayload>> { return HttpClient.get<MeDashboardPayload>('/floral/me/dashboard') }
}
