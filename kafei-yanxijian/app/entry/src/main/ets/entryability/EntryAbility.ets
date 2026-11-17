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
    AppStorage.setOrCreate('tenantId', 'kafyj.zy.huawei');
    AppStorage.setOrCreate('allowDevHttp', false);
    AppStorage.setOrCreate('companyName', '黑龙江省众富信息科技有限公司');
    AppStorage.setOrCreate('appDisplayName', '咖啡研习间');
    AppStorage.setOrCreate('appTagline', '旗舰型咖啡知识、冲煮实验、配方、风味测评、器具百科与个人成长平台');
    AppStorage.setOrCreate('tabBarHidden', false);
    AppStorage.setOrCreate('coffeeDataRevision', 0);
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
