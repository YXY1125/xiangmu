# 权限声明候选与实际工程对照

module.json5 与 AppSpec 均声明：

- ohos.permission.INTERNET：访问账号、公共内容和当前用户业务API，inuse。
- ohos.permission.APP_TRACKING_CONSENT：登录/注册成功后申请；拒绝不影响核心功能，未授权不获取AAID。仅用于已说明的真实活跃统计，inuse。

不声明图库全量读取、定位、摄像头、麦克风或通讯录。当前头像使用应用内角色；导出采用系统文件保存选择器，分享采用系统分享面板。无第三方广告或大模型SDK。

发布包默认仅HTTPS；固定回环HTTP仅DEBUG且明确启动参数可启用。正式Profile/ACL和最终包解包权限尚未验证，不能勾选发布权限一致验收。IPv6：使用域名与系统网络栈，不锁定公网IPv4；尚无真实IPv6网络测试结果。
