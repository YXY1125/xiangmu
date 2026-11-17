import { deviceInfo } from '@kit.BasicServicesKit'
import { AAID } from '@kit.PushKit'
import { ActivityOpenRequest } from '../models/ApiModels'
import { HttpClient } from './HttpClient'

/** 采集手机型号 + AAID，登录/注册写入用户资料，每次打开记活跃。 */
export class DeviceActivityService {
  static lastError: string = ''
  static lastOpenAt: number = 0
  private static lastOwner: string = ''

  static deviceModel(): string {
    const market = `${deviceInfo.marketName ?? ''}`
    const product = `${deviceInfo.productModel ?? ''}`
    if (market.length > 0 && product.length > 0 && market !== product) {
      return `${market} (${product})`
    }
    if (market.length > 0) {
      return market
    }
    if (product.length > 0) {
      return product
    }
    return `${deviceInfo.deviceType ?? ''}`
  }

  static async aaid(): Promise<string> {
    if (AppStorage.get<boolean>('trackingGranted') !== true) return ''
    try {
      const value = await AAID.getAAID()
      return typeof value === 'string' ? value : ''
    } catch {
      return ''
    }
  }

  static async snapshot(): Promise<ActivityOpenRequest> {
    const body = new ActivityOpenRequest()
    body.deviceModel = DeviceActivityService.deviceModel()
    body.aaid = await DeviceActivityService.aaid()
    body.tenantId = HttpClient.tenantId()
    return body
  }

  static async report(reason: string): Promise<void> {
    if (AppStorage.get<boolean>('privacyAccepted') !== true) return
    const revision = AppStorage.get<number>('sessionRevision') ?? 0
    const owner = `${HttpClient.tenantId()}:${AppStorage.get<string>('currentUserId') ?? ''}`
    if (owner !== DeviceActivityService.lastOwner) { DeviceActivityService.lastOwner = owner; DeviceActivityService.lastOpenAt = 0; DeviceActivityService.lastError = '' }
    const token = HttpClient.getToken()
    if (token.length === 0) {
      return
    }
    const now = Date.now()
    if (reason === 'open' && now - DeviceActivityService.lastOpenAt < 30000) {
      return
    }
    DeviceActivityService.lastOpenAt = now
    DeviceActivityService.lastError = ''
    const body = await DeviceActivityService.snapshot()
    if (revision !== (AppStorage.get<number>('sessionRevision') ?? 0)) return
    const res = await HttpClient.post<ActivityOpenRequest>('/auth/activity', body)
    if (res.code !== 0) {
      DeviceActivityService.lastError = res.message.length > 0 ? res.message : '活跃记录失败'
    }
  }
}
