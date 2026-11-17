import { LoginRequest, LoginResponse, RegisterRequest } from '../models/ApiModels'
import { HttpClient } from './HttpClient'
import { SessionStore } from './SessionStore'
import { DeviceActivityService } from './DeviceActivityService'

export class AuthService {
  static lastError: string = ''
  static async login(username: string, password: string): Promise<boolean> {
    const body = new LoginRequest()
    body.username = username
    body.password = password
    body.tenantId = HttpClient.tenantId()
    body.deviceModel = DeviceActivityService.deviceModel()
    return AuthService.authenticate('/auth/login', body)
  }
  static async register(body: RegisterRequest): Promise<boolean> {
    body.tenantId = HttpClient.tenantId()
    body.deviceModel = DeviceActivityService.deviceModel()
    return AuthService.authenticate('/auth/register', body)
  }
  private static async authenticate(path: string, body: LoginRequest): Promise<boolean> {
    AuthService.lastError = ''
    const result = await HttpClient.post<LoginResponse>(path, body)
    const data = result.data
    if (result.code !== 0 || data === undefined || typeof data.accessToken !== 'string' ||
      data.accessToken.length === 0 || data.user === undefined || typeof data.user.id !== 'string' ||
      data.user.id.length === 0 || data.user.tenantId !== HttpClient.tenantId()) {
      AuthService.lastError = result.message || '登录响应缺少有效身份，请重试'
      return false
    }
    try { await SessionStore.saveSession(data.accessToken, data.user.username, data.user.id) }
    catch { AuthService.lastError = '会话保存失败，请重试'; return false }
    return true
  }
  static async logout(): Promise<void> {
    const revision = SessionStore.revision()
    try { await HttpClient.post<Object>('/auth/logout') }
    finally { if (revision === SessionStore.revision()) await SessionStore.clearSession() }
  }
  static isLoggedIn(): boolean { return HttpClient.getToken().length > 0 && SessionStore.userId().length > 0 }
  static isGuest(): boolean { return !AuthService.isLoggedIn() }
  static requireAuth(action: string): boolean { return AuthService.isLoggedIn() }
  static currentUsername(): string { return AppStorage.get<string>('currentUsername') || '未登录' }
}
