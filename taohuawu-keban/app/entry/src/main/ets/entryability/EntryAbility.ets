import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AccessConfig } from '../config/AccessConfig';
import { SessionStore } from '../services/SessionStore';
import { DeviceActivityService } from '../services/DeviceActivityService';
import { AuthService } from '../services/AuthService';
import { DraftStore } from '../services/DraftStore';
import BuildProfile from 'BuildProfile';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'onCreate');
    AppStorage.setOrCreate('apiBaseUrl', 'https://saas26.qianqi.online/api/v1');
    AppStorage.setOrCreate('tenantId', 'thwkb.zh.huawei');
    AppStorage.setOrCreate('sessionRevision', 0);
    AppStorage.setOrCreate('trackingGranted', false);
    AppStorage.setOrCreate('allowDevHttp', false);
    if (BuildProfile.DEBUG && want.parameters?.['thwkbLocalApi'] === true) {
      AppStorage.setOrCreate('allowDevHttp', true);
      AppStorage.setOrCreate('apiBaseUrl', 'http://127.0.0.1:43126/api/v1');
    }
    AppStorage.setOrCreate('companyName', '黑龙江省众富信息科技有限公司');
    AppStorage.setOrCreate('appDisplayName', '桃花坞刻版');
    AppStorage.setOrCreate('appTagline', '让传统年画，变成可爱的动漫世界。');
    AppStorage.setOrCreate('tabBarHidden', false);
    AppStorage.setOrCreate('navigationBackRequest', 0);
    AppStorage.setOrCreate('canHandleAppBack', false);
    AccessConfig.applyDefaults('register_optional');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    SessionStore.init(this.context).then(async () => {
      await DraftStore.init(this.context);
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
