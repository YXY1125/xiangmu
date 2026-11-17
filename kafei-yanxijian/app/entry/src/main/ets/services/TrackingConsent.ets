import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'

const TRACKING: Permissions = 'ohos.permission.APP_TRACKING_CONSENT'

export async function requestAppTrackingConsent(context: common.UIAbilityContext): Promise<void> {
  try {
    const atManager = abilityAccessCtrl.createAtManager()
    await atManager.requestPermissionsFromUser(context, [TRACKING])
  } catch {
    // 申请失败或用户拒绝均不阻断登录与核心功能
  }
}
