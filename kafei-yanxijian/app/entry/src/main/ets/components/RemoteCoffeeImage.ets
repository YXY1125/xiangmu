import { http } from '@kit.NetworkKit'
import { image } from '@kit.ImageKit'
import { Theme } from './design-system/Theme'
import { HttpClient } from '../services/HttpClient'
import { SessionStore } from '../services/SessionStore'
import { CoffeeSync } from '../services/CoffeeSync'

@Component
export struct RemoteCoffeeImage {
  @Prop @Watch('refresh') imageKey: string = ''
  @Prop label: string = '咖啡图片'
  @Prop imageHeight: number = 160
  @StorageLink('coffeeDataRevision') @Watch('refresh') revision: number = 0
  @State pixel: image.PixelMap | undefined = undefined
  @State failed: boolean = false
  private requestSerial: number = 0

  aboutToAppear(): void { this.load() }
  aboutToDisappear(): void {
    this.requestSerial += 1
    this.pixel?.release()
    this.pixel = undefined
  }
  private refresh(): void {
    this.requestSerial += 1
    this.pixel?.release()
    this.pixel = undefined
    this.load()
  }
  private async load(): Promise<void> {
    if (this.imageKey.length === 0) return
    const serial = ++this.requestSerial
    const request = http.createHttp()
    this.failed = false
    try {
      const headers: Record<string, string> = {
        'X-Tenant-Id': HttpClient.tenantId(),
        'Authorization': `Bearer ${HttpClient.getToken()}`
      }
      const result = await request.request(`${HttpClient.getBaseUrl()}/biz/kafyj.zy.huawei/media/images/${this.imageKey}`, {
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 12000,
        readTimeout: 20000
      })
      if (result.responseCode === 401) {
        await SessionStore.clearSession()
        CoffeeSync.resetForAccountChange()
      }
      if (result.responseCode !== 200) throw new Error('image unavailable')
      const source = image.createImageSource(result.result as ArrayBuffer)
      const map = await source.createPixelMap()
      source.release()
      if (serial !== this.requestSerial) { map.release(); return }
      this.pixel?.release()
      this.pixel = map
    } catch {
      if (serial === this.requestSerial) this.failed = true
    } finally {
      request.destroy()
    }
  }

  build() {
    Stack() {
      if (this.pixel) {
        Image(this.pixel).width('100%').height(this.imageHeight).objectFit(ImageFit.Cover).accessibilityText(this.label)
      } else if (this.failed) {
        Column({ space: 8 }) {
          Text('图片暂不可用').fontSize(12).fontColor(Theme.colors().textSecondary)
          Text('重新加载').fontSize(12).fontColor(Theme.colors().brandPrimary).onClick(() => this.load())
        }
      } else {
        LoadingProgress().width(24).height(24).color(Theme.colors().brandPrimary)
      }
    }.width('100%').height(this.imageHeight).backgroundColor(Theme.colors().surfacePage).borderRadius(14).clip(true)
  }
}
