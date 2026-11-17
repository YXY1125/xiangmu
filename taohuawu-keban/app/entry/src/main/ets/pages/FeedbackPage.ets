import { Feedback, FeedbackRequest } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { SessionStore } from '../services/SessionStore'
import { LoadState } from '../components/LoadState'

@Component
export struct FeedbackPage {
  @State items: Feedback[] = []
  @State body: string = ''
  @State category: string = 'suggestion'
  @State loading: boolean = true
  @State busy: boolean = false
  @State error: string = ''
  @State notice: string = ''
  @StorageLink('sessionRevision') @Watch('sessionChanged') revision: number = 0
  private owner: number = -1
  onBack: () => void = () => {}
  aboutToAppear(): void { this.owner = SessionStore.revision(); this.load() }
  private sessionChanged(): void { if (this.owner !== SessionStore.revision()) { this.body = ''; this.items = []; this.onBack() } }
  private async load(): Promise<void> {
    this.loading = true; this.error = ''
    try { const items = await ArtService.feedbacks(); if (this.owner === SessionStore.revision()) this.items = items }
    catch (error) { if (this.owner === SessionStore.revision()) this.error = (error as ArtError).message || '反馈记录读取失败' }
    finally { this.loading = false }
  }
  private async send(): Promise<void> {
    this.busy = true; this.error = ''; this.notice = ''
    try {
      const input = new FeedbackRequest(); input.category = this.category; input.body = this.body
      await ArtService.sendFeedback(input)
      if (this.owner !== SessionStore.revision()) return
      this.body = ''; this.notice = '反馈已提交，可在下方查看处理进度。'; await this.load()
    } catch (error) { if (this.owner === SessionStore.revision()) this.error = (error as ArtError).message || '提交失败，请保留内容重试' }
    finally { this.busy = false }
  }
  build() {
    Column({ space: 16 }) {
      Row() { Button('返回').backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.onBack()); Blank(); Text('意见反馈').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#493B3A') }.width('100%')
      Scroll() {
        Column({ space: 16 }) {
          Text('告诉我们遇到的问题或希望增加的能力。请勿填写密码、证件或无关个人信息。').fontSize(14).fontColor('#76615E').lineHeight(23)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(['suggestion', 'bug', 'content', 'other'], (kind: string) => {
              Button(kind === 'suggestion' ? '产品建议' : kind === 'bug' ? '使用问题' : kind === 'content' ? '内容纠错' : '其他反馈')
                .fontSize(12).margin(4).backgroundColor(this.category === kind ? '#A93635' : '#F9EDE2').fontColor(this.category === kind ? '#FFFFFF' : '#493B3A').onClick(() => { this.category = kind })
            })
          }.width('100%')
          TextArea({ text: this.body, placeholder: '描述问题、发生步骤或建议' }).height(150).maxLength(2000).onChange((value: string) => { this.body = value })
          Button(this.busy ? '提交中…' : '提交反馈').width('100%').enabled(!this.busy && this.body.trim().length > 0).backgroundColor('#A93635').onClick(() => this.send())
          if (this.notice) Text(this.notice).fontSize(14).fontColor('#53785D')
          if (this.error) Text(this.error).fontSize(14).fontColor('#A93635').onClick(() => this.load())
          Text('我的反馈记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%')
          if (this.loading) LoadState({ loading: true })
          else if (this.items.length === 0) LoadState({ emptyText: '还没有反馈记录', emptyImage: 'empty_notifications' })
          ForEach(this.items, (item: Feedback) => {
            Column({ space: 10 }) {
              Text(item.body).fontSize(16).fontColor('#493B3A')
              Text(item.status === 'submitted' ? '已提交' : item.status === 'reviewing' ? '处理中' : item.status === 'replied' ? '已回复' : '已结束').fontSize(12).fontColor('#A93635')
              if (item.reply) Text(`印坊回复：${item.reply}`).fontSize(14).fontColor('#53785D').lineHeight(24)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor('#FFFFFF').borderRadius(18)
          }, (item: Feedback) => item.id)
        }.width('100%').padding({ bottom: 24 })
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }.width('100%').height('100%').padding(20).backgroundColor('#FFF8F0')
  }
}
