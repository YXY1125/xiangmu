import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'

const TRACKING: Permissions = 'ohos.permission.APP_TRACKING_CONSENT'

export async function requestAppTrackingConsent(context: common.UIAbilityContext): Promise<void> {
  try {
    const manager = abilityAccessCtrl.createAtManager()
    await manager.requestPermissionsFromUser(context, [TRACKING])
  } catch {
    // 用户拒绝或系统不支持时，不阻断登录与任何核心功能。
  }
}
