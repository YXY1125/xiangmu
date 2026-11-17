import { http } from '@kit.NetworkKit'
import { ApiResponse, EmptyPayload, LoginRequest, LoginResponse, RegisterRequest, ActivityOpenRequest } from '../models/ApiModels'
import { SessionStore } from './SessionStore'
import { CoffeeSync } from './CoffeeSync'

/** COFFEE LAB HTTPS 客户端；网络失败绝不生成离线 Token 或模拟业务结果。 */
export class HttpClient {
  static getBaseUrl(): string {
    const configured = AppStorage.get<string>('apiBaseUrl')
    return configured && configured.length > 0 ? configured : 'https://saas26.qianqi.online/api/v1'
  }

  static getToken(): string { return AppStorage.get<string>('accessToken') ?? '' }
  static tenantId(): string { return AppStorage.get<string>('tenantId') ?? 'kafyj.zy.huawei' }

  static async request<T>(method: string, path: string, body?: object): Promise<ApiResponse<T>> {
    const base = HttpClient.getBaseUrl()
    if (!base.startsWith('https://')) {
      return HttpClient.fail<T>('仅支持 HTTPS 服务地址')
    }
    const client = http.createHttp()
    try {
      const options = new RequestOptions()
      options.header = HttpClient.headers(HttpClient.tenantId(), HttpClient.getToken())
      if (method === 'GET') {
        options.method = http.RequestMethod.GET
      } else if (method === 'PUT') {
        options.method = http.RequestMethod.PUT
      } else if (method === 'DELETE') {
        options.method = http.RequestMethod.DELETE
      } else {
        options.method = http.RequestMethod.POST
      }
      const payload = HttpClient.encodeBody(body)
      if (payload.length > 0) {
        options.extraData = payload
      }
      const response = await client.request(`${base}${path}`, options.toRequestConfig())
      if (response.responseCode < 200 || response.responseCode >= 300) {
        if (response.responseCode === 401) {
          await SessionStore.clearSession()
          CoffeeSync.resetForAccountChange()
        }
        return HttpClient.fail<T>(HttpClient.errorMessage(response.responseCode, response.result as string))
      }
      if (path === '/auth/login' || path === '/auth/register') {
        return HttpClient.parseAuth<T>(response.result as string)
      }
      return HttpClient.parseResponse<T>(response.result as string)
    } catch (error) {
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
    if (body instanceof RegisterRequest || body instanceof LoginRequest || body instanceof ActivityOpenRequest) {
      return body.toJsonString()
    }
    return JSON.stringify(body)
  }

  private static parseAuth<T>(raw: string): ApiResponse<T> {
    const result = new ApiResponse<LoginResponse>()
    try {
      const root = JSON.parse(raw) as AuthRoot
      result.code = root.code
      result.message = root.message ?? ''
      const data = new LoginResponse()
      data.accessToken = root.data?.accessToken ?? ''
      result.data = data
    } catch (error) {
      result.code = 50001
      result.message = '认证响应解析失败'
      result.data = new LoginResponse()
    }
    return result as ApiResponse<T>
  }

  private static parseResponse<T>(raw: string): ApiResponse<T> {
    const result = new ApiResponse<T>()
    try {
      const root = JSON.parse(raw) as GenericRoot<T>
      result.code = typeof root.code === 'number' ? root.code : 50001
      result.message = typeof root.message === 'string' ? root.message : ''
      result.data = root.data
    } catch (error) {
      result.code = 50001
      result.message = '服务响应格式无效'
    }
    return result
  }

  private static errorMessage(status: number, raw: string): string {
    try {
      const parsed = JSON.parse(raw) as ErrorRoot
      if (parsed.message && parsed.message.length > 0) return parsed.message
    } catch (error) {
    }
    return status === 401 ? '登录已失效，请重新登录' : `服务请求失败（${status}）`
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

class HeaderObject {}
class AuthData { accessToken: string = '' }
class AuthRoot { code: number = 50001; message: string = ''; data?: AuthData }
class ErrorRoot { message: string = '' }
class GenericRoot<T> { code: number = 50001; message: string = ''; data?: T }

class RequestOptions {
  method: http.RequestMethod = http.RequestMethod.GET
  header: Object = new HeaderObject()
  extraData: string = ''
  expectDataType: http.HttpDataType = http.HttpDataType.STRING
  connectTimeout: number = 15000
  readTimeout: number = 15000
  toRequestConfig(): http.HttpRequestOptions {
    const config = new RequestConfig()
    config.method = this.method
    config.header = this.header
    config.extraData = this.extraData.length > 0 ? this.extraData : undefined
    config.expectDataType = this.expectDataType
    config.connectTimeout = this.connectTimeout
    config.readTimeout = this.readTimeout
    return config
  }
}

class RequestConfig implements http.HttpRequestOptions {
  method: http.RequestMethod = http.RequestMethod.GET
  header: Object = new HeaderObject()
  extraData?: string
  expectDataType: http.HttpDataType = http.HttpDataType.STRING
  connectTimeout: number = 15000
  readTimeout: number = 15000
}
