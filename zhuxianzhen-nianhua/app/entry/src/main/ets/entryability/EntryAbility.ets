import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AccessConfig } from '../config/AccessConfig';
import { SessionStore } from '../services/SessionStore';
import { LocalDataStore } from '../services/LocalDataStore';
import { DeviceActivityService } from '../services/DeviceActivityService';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'onCreate');
    AppStorage.setOrCreate('apiBaseUrl', 'https://saas26.qianqi.online/api/v1');
    AppStorage.setOrCreate('tenantId', 'zxznh.xcl.huawei');
    AppStorage.setOrCreate('allowDevHttp', false);
    AppStorage.setOrCreate('companyName', '黑龙江省众富信息科技有限公司');
    AppStorage.setOrCreate('appDisplayName', '朱仙镇年画');
    AppStorage.setOrCreate('appTagline', '让古老年画在指尖焕新');
    AppStorage.setOrCreate('tabBarHidden', false);
    AppStorage.setOrCreate('sessionExpired', false);
    AccessConfig.applyDefaults('open_optional');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    Promise.all([SessionStore.init(this.context), LocalDataStore.init(this.context)]).then(() => {
      void DeviceActivityService.report('open');
      void LocalDataStore.synchronize();
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
    if (SessionStore.isReady()) {
      void DeviceActivityService.report('open');
      void LocalDataStore.synchronize();
    }
  }

}
