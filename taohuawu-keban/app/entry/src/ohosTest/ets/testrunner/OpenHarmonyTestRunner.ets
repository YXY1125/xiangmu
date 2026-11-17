import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import type { Driver, On, Component } from '@ohos.UiTest'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { componentSnapshot } from '@kit.ArkUI'

// Compiled only in entry@ohosTest. No credentials, session injection or API replacement in the app.
const APP: string = 'thwkb.zh.huawei'
export default class OpenHarmonyTestRunner implements TestRunner {
  private driver: Driver | undefined = undefined
  private selector: On | undefined = undefined
  private step: string = 'prepare'
  private scrollId: string = ''
  private reason: string = 'none'
  onPrepare(): void {}
  onRun(): void {
    // Let the system complete the test-runner lifecycle before creating the native UiTest driver.
    setTimeout(() => { this.runFlow() }, 1000)
  }
  private async runFlow(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    try {
      this.step = 'start-entry'
      await delegator.startAbility({ bundleName: APP, abilityName: 'EntryAbility', parameters: { thwkbLocalApi: true } })
      this.reason = 'driver-create-after-ability'
      const uiTest = await import('../uitest/UiRuntime')
      this.driver = uiTest.createDriver()
      this.selector = uiTest.selectors()
      this.step = 'wait-focused-app'
      await this.waitId('thwkb-main-tabs')
      this.step = 'assert-local-mode'
      await this.ui().assertComponentExist(this.by().text('本地联调 · 文件存储 · 非生产服务'))
      this.step = 'open-auth'
      await this.clickText('我的')
      await this.ui().delayMs(1000)
      const suffix: string = Date.now().toString()
      const loginEntry = await this.ui().findComponent(this.by().id('mine-login'))
      if (loginEntry) {
      await this.clickId('mine-login')
      this.scrollId = 'auth-scroll'
      await this.clickId('auth-toggle-mode')
      this.step = 'registration-input'
      const username: string = 'deviceqa_' + suffix
      const password: string = util.generateRandomUUID(true) + 'A1!'
      await this.input('auth-username', username)
      await this.input('auth-password', password)
      await this.input('auth-confirm-password', password)
      await this.input('auth-realname', '设备闭环验证')
      await this.input('auth-phone', '139' + suffix.slice(-8))
      this.step = 'registration-consent'
      await this.clickId('auth-consent')
      await this.clickId('auth-submit')
      await this.ui().delayMs(2000)
      // A system tracking prompt is not bypassed or accepted by this test.
      // If present, stop for explicit refusal/handling instead of touching another window.
      await this.guard()
      this.step = 'wait-auth-overlay-closed'
      await this.waitAbsent('auth-submit')
      // Session revision deliberately rebuilds the business container on the home tab.
      await this.clickText('我的')
      await this.waitText('编辑个人资料')
      await this.passed('native registration and trusted profile')
      } else {
        await this.waitText('编辑个人资料')
        await this.passed('existing native account session restored; registration not repeated')
      }
      this.scrollId = 'mine-scroll'
      const initialWorks = Number(await (await this.element('mine-work-count')).getText())
      const initialDrafts = Number(await (await this.element('mine-draft-count')).getText())
      if (!Number.isFinite(initialWorks) || !Number.isFinite(initialDrafts)) throw new Error('Initial statistics unavailable')
      this.step = 'choose-template'
      this.scrollId = ''
      await this.clickText('工坊')
      this.scrollId = 'workshop-scroll'
      // Actual template identity from the app-owned public content fixture, not an invented endpoint.
      const templates = await this.element('workshop-scroll')
      const useTemplate = await templates.scrollSearch(this.by().text('使用模板'))
      if (!useTemplate) throw new Error('No actual template button available')
      await this.guard(); await useTemplate.click(); await this.ui().delayMs(1000)
      this.scrollId = 'editor-scroll'
      this.step = 'editor-transforms'
      await this.waitId('editor-rotate')
      this.step = 'editor-rotate'
      await this.clickId('editor-rotate')
      await this.waitText('旋转 15°')
      this.reason = 'capture-rotated'
      if (!await this.ui().screenCap(delegator.getAppContext().cacheDir + '/thwkb-editor-rotated.png')) throw new Error('Rotation screenshot failed')
      this.reason = 'undo-rotation'
      await this.clickId('editor-undo')
      await this.waitText('旋转 0°')
      this.reason = 'measure-canvas'
      const canvas = await (await this.element('creationExportCanvas')).getBounds()
      await this.passed('canvas-bounds=' + [canvas.left, canvas.top, canvas.right, canvas.bottom].join(','))
      if (!await this.ui().screenCap(delegator.getAppContext().cacheDir + '/thwkb-editor-baseline.png')) throw new Error('Baseline screenshot failed')
      this.reason = 'full-resolution-snapshot'
      const pixels = await componentSnapshot.get('creationExportCanvas', { scale: 800 / (canvas.right - canvas.left), waitUntilRenderFinished: true })
      try {
        const info = await pixels.getImageInfo()
        if (Math.abs(info.size.width - 800) > 2 || Math.abs(info.size.height - 1000) > 4) throw new Error('Reduced preview degraded export resolution')
        await this.passed('native full-resolution snapshot width=' + info.size.width + ' height=' + info.size.height)
      } finally { pixels.release() }
      this.step = 'editor-scale-buttons'
      this.reason = 'measure-initial-layer'
      const initialScale: string = await (await this.element('editor-scale-value')).getText()
      const before = await (await this.element('canvas-selected-layer')).getBounds()
      await this.clickId('editor-scale-up')
      const larger = await (await this.element('canvas-selected-layer')).getBounds()
      if (larger.right - larger.left <= before.right - before.left + 5) throw new Error('Visible layer did not grow')
      if (!await this.ui().screenCap(delegator.getAppContext().cacheDir + '/thwkb-editor-scaled.png')) throw new Error('Scale screenshot failed')
      await this.clickId('editor-scale-down')
      if (await (await this.element('editor-scale-value')).getText() !== initialScale) throw new Error('Scale down button had no effect')
      await this.clickId('editor-undo')
      await this.clickId('editor-undo')
      if (await (await this.element('editor-scale-value')).getText() !== initialScale) throw new Error('Scale undo failed')
      await this.passed('scale button changes actual layer bounds and undo restores scale')
      this.step = 'editor-scale-slider'
      const slider = await (await this.element('editor-scale-slider')).getBounds()
      await this.guard(); await this.ui().click(Math.round(slider.left + (slider.right - slider.left) * .7), Math.round((slider.top + slider.bottom) / 2))
      await this.ui().delayMs(300)
      if (await (await this.element('editor-scale-value')).getText() === initialScale) throw new Error('Slider had no effect')
      await this.clickId('editor-undo')
      if (await (await this.element('editor-scale-value')).getText() !== initialScale) throw new Error('Slider undo failed')
      await this.passed('native slider changes scale and one undo restores its starting value')
      this.step = 'editor-pan'
      const center = await (await this.element('canvas-selected-layer')).getBoundsCenter()
      const start = await (await this.element('canvas-selected-layer')).getBounds()
      await this.guard(); await this.ui().swipe(center.x, center.y, center.x + 45, center.y + 25, 300)
      await this.ui().delayMs(300)
      const moved = await (await this.element('canvas-selected-layer')).getBounds()
      if (moved.left - start.left < 20) throw new Error('Pan did not move visible layer')
      await this.clickId('editor-undo')
      const restored = await (await this.element('canvas-selected-layer')).getBounds()
      if (Math.abs(restored.left - start.left) > 3 || Math.abs(restored.top - start.top) > 3) throw new Error('Pan undo did not restore initial position')
      await this.passed('native pan moves visible layer and a single undo restores the complete gesture')
      this.step = 'editor-remove-undo'
      await this.clickId('editor-layer-remove')
      if (await this.ui().findComponent(this.by().id('canvas-selected-layer'))) throw new Error('Removed template layer still visible')
      await this.clickId('editor-undo')
      await this.waitId('canvas-selected-layer')
      await this.passed('remove and undo update the actual single-layer template canvas')
      await this.clickId('editor-rotate'); await this.clickId('editor-scale-up')
      const savedScale = await (await this.element('editor-scale-value')).getText()
      await this.input('editor-title', '设备真实保存-' + suffix)
      this.step = 'save-draft'
      await this.clickId('editor-save-draft')
      await this.waitText('草稿已同步保存')
      await this.passed('native editor saves draft after server acknowledgement')
      this.step = 'draft-statistics'
      await this.clickText('返回'); this.scrollId = ''
      await this.clickText('我的'); this.scrollId = 'mine-scroll'
      await this.waitText('编辑个人资料')
      await this.assertCounts(initialWorks, initialDrafts + 1)
      if (!await this.ui().screenCap(delegator.getAppContext().cacheDir + '/thwkb-personal-draft.png')) throw new Error('Draft statistics capture failed')
      await this.clickId('mine-open-drafts'); this.scrollId = 'library-scroll'
      await this.clickText('继续编辑'); this.scrollId = 'editor-scroll'
      await this.waitId('editor-rotate')
      await this.passed('draft save updates personal statistics and draft library without logout')
      this.step = 'save-completed'
      await this.clickId('editor-save-completed')
      await this.waitText('作品已保存，可继续编辑')
      await this.passed('native editor saves completed creation')
      this.step = 'restore-from-list'
      await this.clickText('返回'); await this.ui().delayMs(600)
      await this.clickId('library-back'); this.scrollId = 'mine-scroll'
      await this.waitText('编辑个人资料')
      await this.assertCounts(initialWorks + 1, initialDrafts)
      if (!await this.ui().screenCap(delegator.getAppContext().cacheDir + '/thwkb-personal-completed.png')) throw new Error('Completed statistics capture failed')
      await this.clickId('mine-open-works'); this.scrollId = 'library-scroll'
      await this.clickText('继续编辑')
      await this.waitId('editor-rotate')
      this.scrollId = 'editor-scroll'
      const title = await (await this.element('editor-title')).getText()
      if (title !== '设备真实保存-' + suffix) throw new Error('Recovered title differs')
      await this.waitText('旋转 15°')
      if (await (await this.element('editor-scale-value')).getText() !== savedScale) throw new Error('Recovered scale differs')
      await this.passed('saved creation reopens from personal works; draft count decreases and work count increases')
      await this.passed('rotation and scale persist through save and actual list reopen')
      this.step = 'rename-personal-work'
      await this.input('editor-title', '设备同步更新-' + suffix)
      await this.clickId('editor-save-completed'); await this.waitText('作品已保存，可继续编辑')
      await this.clickText('返回'); this.scrollId = 'library-scroll'
      const workList = await this.element('library-scroll')
      if (!await workList.scrollSearch(this.by().text('设备同步更新-' + suffix))) throw new Error('Renamed work not refreshed in personal library')
      if (!await this.ui().screenCap(delegator.getAppContext().cacheDir + '/thwkb-personal-works.png')) throw new Error('Work list capture failed')
      await this.clickId('library-back'); this.scrollId = 'mine-scroll'
      await this.waitText('编辑个人资料'); await this.assertCounts(initialWorks + 1, initialDrafts)
      await this.clickText('工坊'); this.scrollId = 'workshop-scroll'
      await this.clickText('设备同步更新-' + suffix)
      await this.waitId('editor-rotate'); this.scrollId = 'editor-scroll'
      if (await (await this.element('editor-title')).getText() !== '设备同步更新-' + suffix) throw new Error('Workshop still has obsolete title')
      await this.passed('rename refreshes personal works and workshop without duplicates; statistics unchanged')
      await delegator.finishTest('THWKB_UI_COMPLETE subset=transforms-personal-statistics-save-reopen; export/account-switch not tested', 0)
    } catch (error) {
      // Never print framework exceptions: native input failures may include their supplied text.
      const code: number = (error as BusinessError).code || 0
      const name: string = (error as Error).name
      const safeName: string = ['Error', 'TypeError', 'ReferenceError', 'BusinessError'].includes(name) ? name : 'unclassified'
      if (this.step === 'wait-focused-app') {
        // No credentials or form inputs have been created at this point. Classify only known runtime faults.
        const message: string = (error as Error).message || ''
        if (message.includes('not callable')) this.reason += '-not-callable'
        if (message.includes('not a function')) this.reason += '-not-a-function'
        if (message.includes('undefined')) this.reason += '-undefined'
        if (message.includes('null')) this.reason += '-null'
        if (message.includes('findComponent')) this.reason += '-findComponent'
        if (message.includes('read')) this.reason += '-read'
      }
      await delegator.finishTest('THWKB_UI_FAILED step=' + this.step + ' reason=' + this.reason + ' type=' + safeName + ' code=' + code.toString() + '; sensitive diagnostics suppressed', -1)
    }
  }
  private async assertCounts(works: number, drafts: number): Promise<void> {
    const actualWorks = Number(await (await this.element('mine-work-count')).getText())
    const actualDrafts = Number(await (await this.element('mine-draft-count')).getText())
    if (actualWorks !== works || actualDrafts !== drafts) throw new Error('Personal statistics differ from saved creation status')
    await this.passed('personal-counts works=' + actualWorks + ' drafts=' + actualDrafts)
  }
  private async guard(): Promise<void> {
    const window = await this.ui().findWindow({ bundleName: APP, focused: true })
    if (!window) { this.reason = 'app-window-not-focused'; throw new Error('Target app no longer focused') }
  }
  private async element(id: string): Promise<Component> {
    await this.guard()
    let component = await this.ui().findComponent(this.by().id(id))
    if (!component && this.scrollId) {
      const scroll = await this.ui().findComponent(this.by().id(this.scrollId))
      if (scroll) component = await scroll.scrollSearch(this.by().id(id))
    }
    if (!component) { this.reason = 'missing-id-' + id; throw new Error('Required UI component unavailable') }
    return component
  }
  private async clickId(id: string): Promise<void> {
    const component = await this.element(id)
    await this.guard(); await component.click(); await this.ui().delayMs(400)
  }
  private async clickText(value: string): Promise<void> {
    await this.guard()
    let component = await this.ui().findComponent(this.by().text(value))
    if (!component && this.scrollId) {
      const scroll = await this.ui().findComponent(this.by().id(this.scrollId))
      if (scroll) component = await scroll.scrollSearch(this.by().text(value))
    }
    if (!component) throw new Error('Required text component unavailable')
    await component.click(); await this.ui().delayMs(500)
  }
  private async input(id: string, value: string): Promise<void> {
    const component = await this.element(id)
    await this.guard(); await component.inputText(value); await this.ui().delayMs(250)
  }
  private async waitText(value: string): Promise<void> {
    await this.guard()
    const component = await this.ui().waitForComponent(this.by().text(value), 12000)
    if (!component) { this.reason = 'expected-result-not-visible'; throw new Error('Expected result unavailable') }
  }
  private async waitId(id: string): Promise<void> {
    let component: Component | undefined = undefined
    for (let attempt: number = 0; attempt < 24; attempt++) {
      this.reason = 'construct-id-selector'
      const selector = this.by().id(id)
      this.reason = 'driver-find-component'
      component = await this.ui().findComponent(selector)
      if (component) break
      this.reason = 'driver-delay'
      await this.ui().delayMs(500)
    }
    if (!component) { this.reason = 'expected-id-not-mounted'; throw new Error('Expected component unavailable') }
    this.reason = 'guard-focused-window'
    await this.guard()
    this.reason = 'none'
  }
  private async passed(name: string): Promise<void> {
    await abilityDelegatorRegistry.getAbilityDelegator().print('THWKB_UI_PASS ' + name + '\n')
  }
  private async waitAbsent(id: string): Promise<void> {
    for (let attempt: number = 0; attempt < 24; attempt++) {
      await this.guard()
      if (!await this.ui().findComponent(this.by().id(id))) return
      await this.ui().delayMs(500)
    }
    this.reason = 'auth-overlay-still-visible'; throw new Error('Authentication has not completed')
  }
  private ui(): Driver {
    if (!this.driver) { this.reason = 'native-driver-not-created'; throw new Error('Native UI driver unavailable') }
    return this.driver
  }
  private by(): On {
    if (!this.selector) throw new Error('Native UI selector unavailable')
    return this.selector
  }
}
