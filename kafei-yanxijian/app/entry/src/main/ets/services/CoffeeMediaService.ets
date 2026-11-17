import { util } from '@kit.ArkTS'
import { fileIo } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'
import { MediaUploadResult } from '../models/CoffeeModels'
import { CoffeeApi } from './CoffeeApi'

export class PickedCoffeeImage {
  uri: string = ''
  key: string = ''
  sizeBytes: number = 0
  error: string = ''
}

export class CoffeeMediaService {
  static readonly MAX_SOURCE_BYTES: number = 20 * 1024 * 1024
  static readonly MAX_UPLOAD_BYTES: number = 5 * 1024 * 1024
  static readonly MAX_EDGE: number = 2048

  static async pickAndUpload(): Promise<PickedCoffeeImage> {
    const output = new PickedCoffeeImage()
    try {
      const options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      const selected = await new photoAccessHelper.PhotoViewPicker().select(options)
      if (selected.photoUris.length === 0) return output
      output.uri = selected.photoUris[0]
      const data = await CoffeeMediaService.read(output.uri)
      if (data === undefined) {
        output.error = '请选择 20MB 以内且可正常读取的图片'
        return output
      }
      const result = await CoffeeApi.uploadImage(data.mimeType, data.contentBase64)
      if (result.code !== 0 || result.data === undefined) {
        output.error = result.message
        return output
      }
      const uploaded: MediaUploadResult = result.data
      output.key = uploaded.key
      output.sizeBytes = uploaded.sizeBytes
    } catch {
      output.error = '未能读取或上传所选照片，请重试'
    }
    return output
  }

  private static async read(uri: string): Promise<ImageBinary | undefined> {
    let file: fileIo.File | undefined = undefined
    let source: image.ImageSource | undefined = undefined
    let pixelMap: image.PixelMap | undefined = undefined
    let packer: image.ImagePacker | undefined = undefined
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const size = fileIo.statSync(file.fd).size
      if (size <= 0 || size > CoffeeMediaService.MAX_SOURCE_BYTES) return undefined
      source = image.createImageSource(file.fd)
      const info = await source.getImageInfo()
      const longest = Math.max(info.size.width, info.size.height)
      if (longest <= 0) return undefined
      const scale = Math.min(1, CoffeeMediaService.MAX_EDGE / longest)
      pixelMap = await source.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(info.size.width * scale)),
          height: Math.max(1, Math.round(info.size.height * scale))
        }
      })
      packer = image.createImagePacker()
      const packed = await packer.packToData(pixelMap, new JpegPackOption())
      if (packed.byteLength <= 0 || packed.byteLength > CoffeeMediaService.MAX_UPLOAD_BYTES) return undefined
      const data = new ImageBinary()
      data.mimeType = 'image/jpeg'
      data.contentBase64 = new util.Base64Helper().encodeToStringSync(new Uint8Array(packed))
      return data
    } catch {
      return undefined
    } finally {
      if (pixelMap !== undefined) pixelMap.release()
      if (packer !== undefined) packer.release()
      if (source !== undefined) source.release()
      if (file !== undefined) {
        try { fileIo.closeSync(file) } catch {}
      }
    }
  }
}

class ImageBinary {
  mimeType: string = ''
  contentBase64: string = ''
}

class JpegPackOption {
  format: string = 'image/jpeg'
  quality: number = 86
}
