import { componentSnapshot } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import { fileIo, fileUri, picker } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { systemShare } from '@kit.ShareKit'
import { SessionStore } from './SessionStore'

class PngOptions implements image.PackingOption {
  format: string = 'image/png'
  quality: number = 100
}
class PngRecord implements systemShare.SharedRecord {
  utd: string = 'general.png'
  uri: string = ''
  title: string = '桃花坞刻版作品'
}
class ShareOptions implements systemShare.ShareControllerOptions {}

export class ExportService {
  static async clearTemporaryExports(context: common.UIAbilityContext): Promise<number> {
    const names = await fileIo.listFile(context.cacheDir)
    let removed: number = 0
    for (const name of names) {
      if (!/^thwkb_export_[0-9]+\.png$/.test(name)) continue
      const filename = `${context.cacheDir}/${name}`
      if (!(await fileIo.stat(filename)).isFile()) continue
      await fileIo.unlink(filename); removed++
    }
    return removed
  }
  private static async bytes(componentId: string, scale: number): Promise<ArrayBuffer> {
    const pixels = await componentSnapshot.get(componentId, { scale: scale, waitUntilRenderFinished: true })
    const packer = image.createImagePacker()
    try { return await packer.packing(pixels, new PngOptions()) }
    finally { packer.release(); pixels.release() }
  }
  private static async write(uri: string, bytes: ArrayBuffer): Promise<void> {
    const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    try {
      let offset: number = 0
      while (offset < bytes.byteLength) {
        const chunk = bytes.slice(offset)
        const written = await fileIo.write(file.fd, chunk)
        if (written <= 0) throw new Error('文件写入未完成')
        offset += written
      }
      await fileIo.fsync(file.fd)
    } finally { await fileIo.close(file) }
  }
  static async save(context: common.UIAbilityContext, componentId: string, title: string, scale: number = 1): Promise<boolean> {
    const session = SessionStore.revision()
    const bytes = await ExportService.bytes(componentId, scale)
    if (session !== SessionStore.revision()) throw new Error('账号已变化，请重新操作')
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [`${title.replace(/[\\/:*?"<>|]/g, '_').slice(0, 40) || '桃花印记'}.png`]
    options.fileSuffixChoices = ['PNG 图片|.png']
    const destinations = await new picker.DocumentViewPicker(context).save(options)
    if (destinations.length === 0) return false
    if (session !== SessionStore.revision()) throw new Error('账号已变化，请重新操作')
    await ExportService.write(destinations[0], bytes)
    return true
  }
  static async share(context: common.UIAbilityContext, componentId: string, title: string, scale: number = 1): Promise<void> {
    const session = SessionStore.revision()
    const bytes = await ExportService.bytes(componentId, scale)
    if (session !== SessionStore.revision()) throw new Error('账号已变化，请重新操作')
    const filename = `${context.cacheDir}/thwkb_export_${Date.now()}.png`
    await ExportService.write(filename, bytes)
    const record = new PngRecord(); record.uri = fileUri.getUriFromPath(filename); record.title = title || '桃花坞刻版作品'
    await new systemShare.ShareController(new systemShare.SharedData(record)).show(context, new ShareOptions())
  }
}
