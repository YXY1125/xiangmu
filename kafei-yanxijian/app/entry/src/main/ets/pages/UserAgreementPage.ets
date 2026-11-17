import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
@Entry
@Component
struct UserAgreementPage { build() { Scroll() { Column({ space: 14 }) { Row() { Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext())); Text('用户协议').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 }) }.width('100%'); Text('运营者：黑龙江省云富信息科技有限公司').fontSize(13).fontColor(Theme.colors().brandPrimary).width('100%'); Text('用户可浏览公共知识、公开配方和器具资料；创建配方、保存制作记录、测评、收藏与成长档案需要登录。用户不得上传违法内容或侵犯他人权利的图片。业务记录采用归档和版本机制，不在普通设置中提供物理删除。账号注销与个人信息处理按照隐私政策和适用法律执行。').fontSize(15).lineHeight(26).fontColor(Theme.colors().textPrimary).width('100%') }.padding(18).width('100%') }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage) } }
