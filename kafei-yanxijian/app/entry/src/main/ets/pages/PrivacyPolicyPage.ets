import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
@Entry
@Component
struct PrivacyPolicyPage { build() { Scroll() { Column({ space: 14 }) { Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Text('隐私政策').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }) }.width('100%'); Text('运营者：黑龙江省云富信息科技有限公司').fontSize(13).fontColor(Theme.colors().brandPrimary).width('100%'); this.Section('收集范围', '账号标识、昵称与用户主动填写的资料；学习、制作、配方、测评、收藏和成长记录；为安全和故障诊断所需的最小设备与日志信息。'); this.Section('使用目的', '提供登录与数据隔离、保存个人咖啡档案、展示真实统计、处理账号安全和用户主动发起的媒体上传。'); this.Section('权限原则', '网络权限用于 API 请求；跟踪同意在用户主动操作后请求。注册协议默认不勾选，未同意时不发送注册请求。'); this.Section('用户权利', '用户可访问、更正、导出并申请注销账号。业务记录归档不等于账号注销；依法需要保留的审计信息将按期限处理。') }.padding(18).width('100%') }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage) }
  @Builder Section(title: string, body: string) { Column({ space: 7 }) { Text(title).fontSize(19).fontWeight(FontWeight.Bold).width('100%'); Text(body).fontSize(14).lineHeight(23).fontColor(Theme.colors().textSecondary).width('100%') }.padding(17).backgroundColor(Theme.colors().surfaceCard).borderRadius(18).alignItems(HorizontalAlign.Start) }
}
