import { http } from '@kit.NetworkKit'
import { ApiResponse, LoginRequest, RegisterRequest, ActivityOpenRequest } from '../models/ApiModels'
import { SessionStore } from './SessionStore'
import BuildProfile from 'BuildProfile'

class RequestConfig implements http.HttpRequestOptions {
  method: http.RequestMethod = http.RequestMethod.GET
  header: Object = new Object()
  extraData?: string
  expectDataType: http.HttpDataType = http.HttpDataType.STRING
  connectTimeout: number = 15000
  readTimeout: number = 20000
  // API responses contain private, mutable counters and records. Always consult
  // the authenticated server after a write instead of NetworkKit's default cache.
  usingCache: boolean = false
}

/** Real HTTPS only. No offline authentication or synthetic business success. */
export class HttpClient {
  static getBaseUrl(): string {
    return AppStorage.get<string>('apiBaseUrl') ?? 'https://saas26.qianqi.online/api/v1'
  }
  static getToken(): string { return AppStorage.get<string>('accessToken') ?? '' }
  static tenantId(): string { return AppStorage.get<string>('tenantId') ?? '' }

  static async request<T>(method: string, path: string, body?: object): Promise<ApiResponse<T>> {
    const base = HttpClient.getBaseUrl()
    const localDebug = BuildProfile.DEBUG && AppStorage.get<boolean>('allowDevHttp') === true && base === 'http://127.0.0.1:43126/api/v1'
    if ((!base.startsWith('https://') && !localDebug) || !path.startsWith('/') || path.startsWith('//')) {
      return HttpClient.failure<T>(40001, '服务地址无效')
    }
    const token = HttpClient.getToken()
    const revision = SessionStore.revision()
    const config = new RequestConfig()
    config.header = JSON.parse(`{"Content-Type":"application/json","X-Tenant-Id":${JSON.stringify(HttpClient.tenantId())},"Authorization":${JSON.stringify(token.length > 0 ? `Bearer ${token}` : '')}}`) as Object
    if (method === 'POST') config.method = http.RequestMethod.POST
    else if (method === 'PUT') config.method = http.RequestMethod.PUT
    else if (method === 'DELETE') config.method = http.RequestMethod.DELETE
    else if (method !== 'GET') return HttpClient.failure<T>(40001, '不支持的请求方式')
    if (body !== undefined) {
      if (body instanceof RegisterRequest || body instanceof LoginRequest || body instanceof ActivityOpenRequest) {
        config.extraData = body.toJsonString()
      } else config.extraData = JSON.stringify(body)
    }
    const client = http.createHttp()
    try {
      const response = await client.request(`${base}${path}`, config)
      if (revision !== SessionStore.revision() || token !== HttpClient.getToken()) {
        return HttpClient.failure<T>(40901, '账号状态已变化，请重新操作')
      }
      if (response.responseCode === 401 && token.length > 0) {
        await SessionStore.clearSession()
        return HttpClient.failure<T>(401, '登录已失效，请重新登录')
      }
      let parsed: ApiResponse<T>
      try { parsed = JSON.parse(response.result as string) as ApiResponse<T> }
      catch { return HttpClient.failure<T>(50002, '服务响应无法解析，请重试') }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        if (response.responseCode === 404) return HttpClient.failure<T>(40401, '内容暂不可用，请稍后重新加载')
        if (response.responseCode === 503) return HttpClient.failure<T>(50301, '服务暂不可用，请稍后再试')
        return HttpClient.failure<T>(response.responseCode, parsed.message || `请求失败（${response.responseCode}）`)
      }
      if (typeof parsed.code !== 'number') return HttpClient.failure<T>(50002, '服务响应缺少状态码')
      if ((parsed.code === 401 || parsed.code === 40101) && token.length > 0) await SessionStore.clearSession()
      if (typeof parsed.message !== 'string') parsed.message = ''
      return parsed
    } catch {
      return HttpClient.failure<T>(50301, '连接服务失败，请检查网络后重试')
    } finally { client.destroy() }
  }

  private static failure<T>(code: number, message: string): ApiResponse<T> {
    const result = new ApiResponse<T>()
    result.code = code
    result.message = message
    return result
  }
  static get<T>(path: string): Promise<ApiResponse<T>> { return HttpClient.request<T>('GET', path) }
  static post<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('POST', path, body) }
  static put<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('PUT', path, body) }
  static patch<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.put<T>(path, body) }
  static delete<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('DELETE', path, body) }
}
