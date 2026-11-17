import { Notification } from '../models/ArtModels'
import { ArtService, ArtError } from '../services/ArtService'
import { SessionStore } from '../services/SessionStore'
import { LoadState } from '../components/LoadState'

@Component
export struct MessagesPage {
  @State items: Notification[] = []
  @State loading: boolean = true
  @State error: string = ''
  @State busyId: string = ''
  @StorageLink('sessionRevision') @Watch('load') revision: number = 0
  onBack: () => void = () => {}
  onOpen: (kind: string, id: string) => void = () => {}
  private requestId: number = 0
  aboutToAppear(): void { this.load() }
  private async load(): Promise<void> {
    const request = ++this.requestId,session = SessionStore.revision()
    this.loading = true; this.error = ''; this.items = []
    try { const items = await ArtService.notifications(); if (request === this.requestId && session === SessionStore.revision()) this.items = items }
    catch (error) { if (request === this.requestId && session === SessionStore.revision()) this.error = (error as ArtError).message || '通知读取失败' }
    finally { if (request === this.requestId) this.loading = false }
  }
  private async read(item: Notification,open: boolean): Promise<void> {
    const session = SessionStore.revision(); this.busyId = item.id; this.error = ''
    try {
      if (!item.readAt) await ArtService.readNotification(item.id)
      if (session !== SessionStore.revision()) return
      if (open && item.targetRoute.startsWith('artwork:')) this.onOpen('artwork', item.targetRoute.slice(8))
      else if (open && item.targetRoute === 'feedback') this.onOpen('feedback', '')
      else await this.load()
    } catch (error) { if (session === SessionStore.revision()) this.error = (error as ArtError).message || '操作未完成，请重试' }
    finally { this.busyId = '' }
  }
  build() {
    Column({ space: 16 }) {
      Row() { Button('返回').backgroundColor('#F9EDE2').fontColor('#493B3A').onClick(() => this.onBack()); Blank(); Text('消息通知').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#493B3A') }.width('100%')
      if (this.loading || this.error) LoadState({ loading: this.loading, message: this.error, onRetry: () => this.load() }).layoutWeight(1)
      else if (this.items.length === 0) LoadState({ emptyText: '暂无消息，作品审核和反馈进度会显示在这里', emptyImage: 'empty_notifications' }).layoutWeight(1)
      else List({ space: 12 }) {
        ForEach(this.items, (item: Notification) => {
          ListItem() {
            Column({ space: 10 }) {
              Text(item.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#493B3A').width('100%')
              Text(item.body).fontSize(14).fontColor('#76615E').lineHeight(24).width('100%')
              Row({ space: 12 }) {
                if (!item.readAt) Button('标记已读').fontSize(12).backgroundColor('#FBE0E7').fontColor('#A93635').enabled(!this.busyId).onClick(() => this.read(item, false))
                else Text('已读').fontSize(12).fontColor('#53785D')
                if (item.targetRoute.startsWith('artwork:') || item.targetRoute === 'feedback') Button('查看详情').fontSize(12).backgroundColor('#A93635').enabled(!this.busyId).onClick(() => this.read(item, true))
              }.width('100%')
            }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(18)
          }
        }, (item: Notification) => item.id)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
    }.width('100%').height('100%').padding(20).backgroundColor('#FFF8F0')
  }
}
