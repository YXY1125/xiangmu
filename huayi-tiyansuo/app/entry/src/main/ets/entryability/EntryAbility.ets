import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AccessConfig } from '../config/AccessConfig';
import { SessionStore } from '../services/SessionStore';
import { DeviceActivityService } from '../services/DeviceActivityService';
import { AuthService } from '../services/AuthService';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'onCreate');
    AppStorage.setOrCreate('apiBaseUrl', 'https://saas26.qianqi.online/api/v1');
    AppStorage.setOrCreate('tenantId', 'hytys.xcl.huawei');
    AppStorage.setOrCreate('allowDevHttp', false);
    AppStorage.setOrCreate('companyName', '黑龙江省众富信息科技有限公司');
    AppStorage.setOrCreate('appDisplayName', '花艺体验所');
    AppStorage.setOrCreate('appTagline', '让每个人都能成为生活里的花艺师。');
    AppStorage.setOrCreate('tabBarHidden', false);
    AccessConfig.applyDefaults('open_optional');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    SessionStore.init(this.context).then(() => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(0x0000, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        }
      });
    }).catch(() => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(0x0000, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        }
      });
    });
  }

  onForeground(): void {
    if (AuthService.isLoggedIn()) {
      DeviceActivityService.report('open')
    }
  }
}
