import { router, UIContext } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'

class EmptyRouteParams {
}

export class AppRouter {
  static push(uiContext: UIContext, options: router.RouterOptions): void {
    try {
      uiContext.getRouter().pushUrl(options, (error: BusinessError): void => {
        if (error) {
          console.error(`[COFFEE LAB] 页面跳转失败：${error.code}`)
        }
      })
    } catch {
      console.error('[COFFEE LAB] 页面跳转失败：路由上下文不可用')
    }
  }

  static replace(uiContext: UIContext, options: router.RouterOptions): void {
    try {
      uiContext.getRouter().replaceUrl(options, (error: BusinessError): void => {
        if (error) {
          console.error(`[COFFEE LAB] 页面替换失败：${error.code}`)
        }
      })
    } catch {
      console.error('[COFFEE LAB] 页面替换失败：路由上下文不可用')
    }
  }

  static back(uiContext: UIContext): void {
    try {
      uiContext.getRouter().back()
    } catch {
      console.error('[COFFEE LAB] 页面返回失败：路由上下文不可用')
    }
  }

  static getParams(uiContext: UIContext): Object {
    try {
      return uiContext.getRouter().getParams()
    } catch {
      console.error('[COFFEE LAB] 路由参数读取失败：路由上下文不可用')
      return new EmptyRouteParams()
    }
  }
}
