import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'

const TRACKING: Permissions = 'ohos.permission.APP_TRACKING_CONSENT'

export async function requestAppTrackingConsent(context: common.UIAbilityContext): Promise<void> {
  try {
    const atManager = abilityAccessCtrl.createAtManager()
    const result = await atManager.requestPermissionsFromUser(context, [TRACKING])
    AppStorage.setOrCreate('trackingGranted', result.authResults.length > 0 && result.authResults[0] === 0)
  } catch {
    AppStorage.setOrCreate('trackingGranted', false)
    // 申请失败或用户拒绝均不阻断登录与核心功能
  }
}
