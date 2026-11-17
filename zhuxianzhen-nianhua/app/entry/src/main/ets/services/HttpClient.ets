import { http } from '@kit.NetworkKit'
import { ApiResponse, EmptyPayload, LoginRequest, LoginResponse, RegisterRequest } from '../models/ApiModels'
import { SessionStore } from './SessionStore'

export class HttpClient {
  static getBaseUrl(): string {
    return AppStorage.get<string>('apiBaseUrl') ?? ''
  }

  static async request<T>(method: string, path: string, body?: object): Promise<ApiResponse<T>> {
    const base = HttpClient.getBaseUrl()
    if (!base.startsWith('https://') || base.indexOf('.invalid') >= 0) {
      return HttpClient.fail<T>('网络服务尚未配置，未执行登录或同步')
    }
    const client = http.createHttp()
    const requestToken = AppStorage.get<string>('accessToken') ?? ''
    const options = new RequestOptions()
    options.method = method === 'GET' ? http.RequestMethod.GET : method === 'DELETE' ?
      http.RequestMethod.DELETE : method === 'PUT' ? http.RequestMethod.PUT : http.RequestMethod.POST
    options.header = HttpClient.headers()
    if (body instanceof LoginRequest || body instanceof RegisterRequest) options.extraData = body.toJsonString()
    else if (body !== undefined) options.extraData = JSON.stringify(body)
    try {
      const response = await client.request(`${base}${path}`, options.toConfig())
      client.destroy()
      if (response.responseCode === 401) {
        if (requestToken.length > 0 && requestToken === (AppStorage.get<string>('accessToken') ?? '')) {
          await SessionStore.clearSession()
          AppStorage.setOrCreate('sessionExpired', true)
        }
        return HttpClient.fail<T>('登录状态已失效，请重新登录')
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return HttpClient.fail<T>(`服务请求失败（${response.responseCode}）`)
      }
      if (path === '/auth/login' || path === '/auth/register') return HttpClient.parseAuth<T>(response.result as string)
      const parsed = JSON.parse(response.result as string) as ApiResponse<T>
      if (parsed.code === 40101 && requestToken.length > 0 && requestToken === (AppStorage.get<string>('accessToken') ?? '')) {
        await SessionStore.clearSession(); AppStorage.setOrCreate('sessionExpired', true)
      }
      return parsed
    } catch {
      client.destroy()
      return HttpClient.fail<T>('网络不可用，操作未成功')
    }
  }

  private static headers(): Object {
    const token = AppStorage.get<string>('accessToken') ?? ''
    const tenant = AppStorage.get<string>('tenantId') ?? ''
    if (token.length > 0) {
      return JSON.parse(`{"Content-Type":"application/json","X-Tenant-Id":${JSON.stringify(tenant)},"Authorization":${JSON.stringify(`Bearer ${token}`)}}`) as Object
    }
    return JSON.parse(`{"Content-Type":"application/json","X-Tenant-Id":${JSON.stringify(tenant)}}`) as Object
  }

  private static parseAuth<T>(raw: string): ApiResponse<T> {
    try {
      const root = JSON.parse(raw) as AuthWireRoot
      const result = new ApiResponse<LoginResponse>()
      result.code = root.code
      result.message = root.message
      const data = new LoginResponse()
      if (root.data !== undefined && root.data !== null) {
        data.accessToken = typeof root.data.accessToken === 'string' ? root.data.accessToken : ''
        if (root.data.user !== undefined && root.data.user !== null) data.userId = typeof root.data.user.id === 'string' ? root.data.user.id : ''
      }
      result.data = data
      return result as ApiResponse<T>
    } catch {
      return HttpClient.fail<T>('服务响应格式错误')
    }
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
  static patch<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('PUT', path, body) }
  static delete<T>(path: string, body?: object): Promise<ApiResponse<T>> { return HttpClient.request<T>('DELETE', path, body) }
}

class EmptyHeaderObject {}
class AuthWireUser { id: string = '' }
class AuthWireData { accessToken: string = ''; user: AuthWireUser | undefined | null = undefined }
class AuthWireRoot {
  code: number = 50001
  message: string = ''
  data: AuthWireData | null | undefined = undefined
}
class HttpRequestConfig implements http.HttpRequestOptions {
  method: http.RequestMethod = http.RequestMethod.GET
  header: Object = new EmptyHeaderObject()
  extraData: string = ''
  expectDataType: http.HttpDataType = http.HttpDataType.STRING
  connectTimeout: number = 15000
  readTimeout: number = 15000
}
class RequestOptions {
  method: http.RequestMethod = http.RequestMethod.GET
  header: Object = new EmptyHeaderObject()
  extraData: string = ''
  toConfig(): http.HttpRequestOptions {
    const value = new HttpRequestConfig()
    value.method = this.method
    value.header = this.header
    value.extraData = this.extraData
    return value
  }
}
