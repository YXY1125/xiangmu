import { abilityAccessCtrl, bundleManager } from '@kit.AbilityKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { identifier } from '@kit.AdsKit'
import { HttpClient } from './HttpClient'

class ActivityRequest {
  tenantId: string = 'zxznh.xcl.huawei'
  deviceModel: string = ''
  aaid: string = ''
}

export class DeviceActivityService {
  private static lastOwner: string = ''
  private static lastOpenAt: number = 0

  static deviceModel(): string {
    const market = deviceInfo.marketName
    const product = deviceInfo.productModel
    return market.length > 0 && product.length > 0 && market !== product ? `${market} (${product})` : market || product
  }

  private static async authorizedIdentifier(): Promise<string> {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      const status = abilityAccessCtrl.createAtManager().checkAccessTokenSync(info.appInfo.accessTokenId, 'ohos.permission.APP_TRACKING_CONSENT')
      if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) return ''
      return await identifier.getOAID()
    } catch {
      return ''
    }
  }

  static async report(reason: string): Promise<void> {
    const token = AppStorage.get<string>('accessToken') ?? ''
    const owner = AppStorage.get<string>('currentUsername') ?? ''
    if (token.length === 0 || owner.length === 0 || AppStorage.get<boolean>('privacyAccepted') !== true) return
    const now = Date.now()
    if (reason === 'open' && owner === DeviceActivityService.lastOwner && now - DeviceActivityService.lastOpenAt < 30000) return
    DeviceActivityService.lastOwner = owner
    DeviceActivityService.lastOpenAt = now
    const body = new ActivityRequest()
    body.deviceModel = DeviceActivityService.deviceModel()
    body.aaid = await DeviceActivityService.authorizedIdentifier()
    if (token !== (AppStorage.get<string>('accessToken') ?? '')) return
    const result = await HttpClient.post<ActivityRequest>('/auth/activity', body)
    AppStorage.setOrCreate('lastActivityError', result.code === 0 ? '' : result.message)
  }
}
