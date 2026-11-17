import { http } from '@kit.NetworkKit'
import { ApiResponse, EmptyPayload, LoginRequest, LoginResponse, RegisterRequest, ActivityOpenRequest } from '../models/ApiModels'
import { SessionStore } from './SessionStore'

class EmptyHeaderObject {}
class NestHttpError { message: string = '' }
class AuthWireData { accessToken: string = '' }
class AuthWireRoot {
  code: number = 50001
  message: string = ''
  data: AuthWireData | null | undefined = undefined
}
class HttpRequestConfig implements http.HttpRequestOptions {
  method: http.RequestMethod = http.RequestMethod.GET
  header: Object = new EmptyHeaderObject()
  extraData?: string
  expectDataType: http.HttpDataType = http.HttpDataType.STRING
  connectTimeout: number = 15000
  readTimeout: number = 15000
}

/** saas26 HTTPS 客户端。网络异常如实返回，不生成离线用户或虚构业务数据。 */
export class HttpClient {
  static getBaseUrl(): string {
    const value = AppStorage.get<string>('apiBaseUrl')
    return value && value.length > 0 ? value : 'https://saas26.qianqi.online/api/v1'
  }

  static tenantId(): string {
    const value = AppStorage.get<string>('tenantId')
    return value && value.length > 0 ? value : 'hytys.xcl.huawei'
  }

  static getToken(): string { return AppStorage.get<string>('accessToken') ?? '' }

  static async request<T>(method: string, path: string, body?: object): Promise<ApiResponse<T>> {
    const base = HttpClient.getBaseUrl()
    if (!base.startsWith('https://')) return HttpClient.fail<T>('仅支持 HTTPS')
    const token = AppStorage.get<string>('accessToken') ?? ''
    const config = new HttpRequestConfig()
    config.header = HttpClient.headers(HttpClient.tenantId(), token)
    if (method === 'POST') config.method = http.RequestMethod.POST
    if (method === 'PUT' || method === 'PATCH') config.method = http.RequestMethod.PUT
    if (method === 'DELETE') config.method = http.RequestMethod.DELETE
    const payload = HttpClient.encodeBody(body)
    if (payload.length > 0) config.extraData = payload
    const client = http.createHttp()
    try {
      const response = await client.request(`${base}${path}`, config)
      if (response.responseCode < 200 || response.responseCode >= 300) {
        if (response.responseCode === 401) await SessionStore.clearSession()
        return HttpClient.httpFailure<T>(response.responseCode, response.result as string)
      }
      if (path === '/auth/login' || path === '/auth/register') return HttpClient.parseAuth<T>(response.result as string)
      return JSON.parse(response.result as string) as ApiResponse<T>
    } catch {
      return HttpClient.fail<T>('网络不可用，请检查连接后重试')
    } finally {
      client.destroy()
    }
  }

  private static headers(tenantId: string, token: string): Object {
    if (token.length > 0) {
      return JSON.parse(`{"Content-Type":"application/json","X-Tenant-Id":${JSON.stringify(tenantId)},"Authorization":${JSON.stringify(`Bearer ${token}`)}}`) as Object
    }
    return JSON.parse(`{"Content-Type":"application/json","X-Tenant-Id":${JSON.stringify(tenantId)}}`) as Object
  }

  private static encodeBody(body?: object): string {
    if (body === undefined) return ''
    if (body instanceof RegisterRequest || body instanceof LoginRequest || body instanceof ActivityOpenRequest) return body.toJsonString()
    return JSON.stringify(body)
  }

  private static parseAuth<T>(raw: string): ApiResponse<T> {
    const result = new ApiResponse<T>()
    try {
      const root = JSON.parse(raw) as AuthWireRoot
      result.code = root.code
      result.message = root.message ?? ''
      const auth = new LoginResponse()
      auth.accessToken = root.data?.accessToken ?? ''
      result.data = auth as T
    } catch {
      result.code = 50001
      result.message = '响应解析失败'
    }
    return result
  }

  private static httpFailure<T>(status: number, raw: string): ApiResponse<T> {
    let message = `HTTP ${status}`
    try {
      const error = JSON.parse(raw) as NestHttpError
      if (error.message.length > 0) message = error.message
    } catch {}
    const result = HttpClient.fail<T>(message)
    result.code = status === 401 ? 40101 : status * 100 + 1
    return result
  }

  private static fail<T>(message: string): ApiResponse<T> {
    const result = new ApiResponse<T>()
    result.code = 50001
    result.message = message
    result.data = new EmptyPayload() as T
    return result
  }

  static get<T>(path: string): Promise<ApiResponse<T>> { return HttpClient.request<T>('GET', path) }
  static post<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('POST', path, body) }
  static put<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('PUT', path, body) }
  static patch<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('PATCH', path, body) }
  static delete<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('DELETE', path, body) }
}
