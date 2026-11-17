import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { UserProfile } from '../models/CoffeeModels'
import { CoffeeApi } from '../services/CoffeeApi'

@Component
struct ProfileTextField {
  @Prop label: string = ''
  @Prop placeholder: string = ''
  @Link value: string

  build() {
    Column({ space: 6 }) {
      Text(this.label).fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
      TextInput({ text: this.value, placeholder: this.placeholder })
        .height(48)
        .backgroundColor(Theme.colors().surfaceCard)
        .borderRadius(16)
        .onChange((value: string) => { this.value = value })
    }.width('100%')
  }
}

@Entry
@Component
struct ProfilePage {
  @State nickname: string = ''
  @State bio: string = ''
  @State interest: string = ''
  @State loading: boolean = false
  @State message: string = ''
  @State saved: boolean = false

  aboutToAppear(): void { this.load() }

  private async load(): Promise<void> {
    this.loading = true
    this.message = ''
    const result = await CoffeeApi.profile()
    this.loading = false
    if (result.code === 0 && result.data !== undefined) {
      this.applyProfile(result.data)
    } else {
      this.saved = false
      this.message = result.message
    }
  }

  private applyProfile(profile: UserProfile): void {
    this.nickname = profile.nickname || ''
    this.bio = profile.bio || ''
    this.interest = Array.isArray(profile.interestDirections) ? profile.interestDirections.join('、') : ''
  }

  private async save(): Promise<void> {
    if (this.loading) return
    const nickname = this.nickname.trim()
    if (nickname.length === 0) {
      this.saved = false
      this.message = '请填写昵称'
      return
    }
    if (nickname.length > 60 || this.bio.trim().length > 240) {
      this.saved = false
      this.message = '昵称或个人简介超过长度限制'
      return
    }

    const profile = new UserProfile()
    profile.nickname = nickname
    profile.bio = this.bio.trim()
    profile.interestDirections = this.interest.split(/[、,，]/)
      .map((item: string) => item.trim())
      .filter((item: string) => item.length > 0)
      .slice(0, 12)

    this.loading = true
    this.message = ''
    const result = await CoffeeApi.saveProfile(profile)
    if (result.code !== 0) {
      this.loading = false
      this.saved = false
      this.message = result.message
      return
    }

    const confirmed = await CoffeeApi.profile()
    this.loading = false
    if (confirmed.code === 0 && confirmed.data !== undefined) {
      this.applyProfile(confirmed.data)
      this.saved = true
      this.message = '个人资料已保存并同步'
    } else {
      this.saved = false
      this.message = '资料已提交，但回读确认失败，请稍后重试'
    }
  }

  build() {
    Scroll() {
      Column({ space: 15 }) {
        Row() {
          Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
          Text('个人资料').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 })
        }.width('100%')
        Image($r('app.media.app_icon')).width(88).height(88).borderRadius(26)
        ProfileTextField({ label: '昵称', value: $nickname, placeholder: '设置昵称' })
        ProfileTextField({ label: '个人简介', value: $bio, placeholder: '写下你的咖啡兴趣' })
        ProfileTextField({ label: '兴趣方向', value: $interest, placeholder: '例如：手冲、意式、烘焙' })
        if (this.message.length > 0) {
          Text(this.message).fontSize(13)
            .fontColor(this.saved ? Theme.colors().success : Theme.colors().danger).width('100%')
        }
        Button(this.loading ? '正在同步…' : '保存资料')
          .enabled(!this.loading).width('100%').backgroundColor(Theme.colors().brandPrimary)
          .borderRadius(20).onClick(() => this.save())
        Text('头像功能在媒体选择与上传闭环完成前保持只读，不提交占位图。')
          .fontSize(10).fontColor(Theme.colors().textTertiary)
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
