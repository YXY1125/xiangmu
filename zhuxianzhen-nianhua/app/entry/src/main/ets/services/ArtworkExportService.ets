import { common } from '@kit.AbilityKit'
import { componentSnapshot } from '@kit.ArkUI'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { LocalDataStore } from './LocalDataStore'

class PngOption {
  format: string = 'image/png'
  quality: number = 100
}

class AlbumConfig {
  title: string = '朱仙镇年画作品'
  fileNameExtension: string = 'png'
  photoType: photoAccessHelper.PhotoType = photoAccessHelper.PhotoType.IMAGE
  subtype: photoAccessHelper.PhotoSubtype = photoAccessHelper.PhotoSubtype.DEFAULT
}

export class ArtworkExportService {
  static lastError: string = ''

  static async capture(componentId: string, context: common.UIAbilityContext, targetWidth: number, targetHeight: number): Promise<string> {
    ArtworkExportService.lastError = ''
    const owner = LocalDataStore.ownerId()
    try {
      const pixelMap = await componentSnapshot.get(componentId)
      const size = (await pixelMap.getImageInfo()).size
      await pixelMap.scale(targetWidth / size.width, targetHeight / size.height)
      const packer = image.createImagePacker()
      const directory = `${context.filesDir}/artworks/${encodeURIComponent(owner)}`
      if (!fileIo.accessSync(directory)) fileIo.mkdirSync(directory, true)
      const path = `${directory}/zxznh-artwork-${Date.now()}.png`
      const opened = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
      try {
        await packer.packToFile(pixelMap, opened.fd, new PngOption())
      } finally {
        fileIo.closeSync(opened)
        packer.release()
        pixelMap.release()
      }
      if (fileIo.statSync(path).size > 800) return path
      ArtworkExportService.lastError = '导出的图片文件无效，请重试'
    } catch {
      ArtworkExportService.lastError = '作品渲染失败，请稍后重试'
    }
    return ''
  }

  static async saveToAlbum(context: common.UIAbilityContext, path: string, title: string): Promise<boolean> {
    ArtworkExportService.lastError = ''
    const config = new AlbumConfig()
    config.title = title
    try {
      const helper = photoAccessHelper.getPhotoAccessHelper(context)
      const targets = await helper.showAssetsCreationDialog([fileUri.getUriFromPath(path)], [config])
      if (targets.length === 0) {
        ArtworkExportService.lastError = '已取消保存到系统相册'
        await helper.release()
        return false
      }
      const source = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      const destination = fileIo.openSync(targets[0], fileIo.OpenMode.READ_WRITE)
      try {
        await fileIo.copyFile(source.fd, destination.fd)
      } finally {
        fileIo.closeSync(destination)
        fileIo.closeSync(source)
        await helper.release()
      }
      return true
    } catch {
      ArtworkExportService.lastError = '未能写入系统相册，请检查可用空间后重试'
      return false
    }
  }
}
