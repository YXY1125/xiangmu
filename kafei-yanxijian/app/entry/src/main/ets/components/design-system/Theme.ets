/**
 * HCDS Theme — ArkTS strict-mode compatible token accessors.
 * Source of truth: knowledge/design-system/tokens.json
 */

export type ColorMode = 'light' | 'dark' | 'system'

export class ThemeColors {
  brandPrimary: string = '#B47A43'
  brandPrimaryPressed: string = '#8F5C30'
  brandPrimaryContainer: string = '#EAD9C5'
  brandOnPrimary: string = '#FFFFFF'
  brandDeep: string = '#241B17'
  brandAccent: string = '#687C68'
  surfacePage: string = '#F3EBDD'
  surfaceSubtle: string = '#E7DAC9'
  surfaceCard: string = '#FFFDFC'
  surfaceGlass: string = 'rgba(255,253,252,0.78)'
  surfaceInverse: string = '#241B17'
  textPrimary: string = '#3B2A20'
  textSecondary: string = '#725E51'
  textTertiary: string = '#A28D7B'
  textOnInverse: string = '#F9F1E7'
  strokeHairline: string = 'rgba(59,42,32,0.08)'
  strokeStrong: string = 'rgba(59,42,32,0.18)'
  success: string = '#687C68'
  successContainer: string = '#DCE5D8'
  warning: string = '#A9682E'
  warningContainer: string = '#F6E4C8'
  danger: string = '#A8463B'
  dangerContainer: string = '#F5DDD8'
  info: string = '#5E736F'
  overlayScrim: string = 'rgba(36,27,23,0.48)'
  chart1: string = '#B47A43'
  chart2: string = '#687C68'
  chart3: string = '#D8A15D'
  chart4: string = '#7C5B48'
  chart5: string = '#A4A98A'
}

export class ThemeSpace {
  s0: number = 0
  s1: number = 4
  s2: number = 8
  s3: number = 12
  s4: number = 16
  s5: number = 20
  s6: number = 24
  s7: number = 32
  s8: number = 40
  s9: number = 48
  s10: number = 64
  pageX: number = 16
  pageY: number = 16
  section: number = 32
  cardPadding: number = 16
  listItemY: number = 12
  inline: number = 8
  textStack: number = 2
}

export class ThemeRadius {
  // Official: https://developer.huawei.com/consumer/cn/doc/design-guides/corner-radius-parameter-0000002556468705
  xs: number = 4
  sm: number = 8
  md: number = 16
  lg: number = 20
  xl: number = 24
  sheet: number = 32
  pill: number = 999
}

export class ThemeTypeScale {
  // Official HarmonyOS phone tokens (vp)
  // https://developer.huawei.com/consumer/cn/doc/design-guides/typography-0000002622688363
  displayL: number = 56
  displayM: number = 48
  displayS: number = 38
  titleL: number = 30
  titleM: number = 24
  titleS: number = 20
  subtitleL: number = 18
  subtitleM: number = 16
  subtitleS: number = 14
  bodyL: number = 16
  bodyM: number = 14
  bodyS: number = 12
  captionL: number = 12
  captionM: number = 10

  // HCDS aliases → official phone scale
  display: number = 38
  title1: number = 30
  title2: number = 24
  title3: number = 20
  body: number = 16
  callout: number = 16
  subhead: number = 14
  footnote: number = 12
  caption: number = 12
  overline: number = 10
}

export class ThemeMotion {
  instant: number = 80
  fast: number = 150
  normal: number = 240
  slow: number = 320
  emphasis: number = 420
  staggerMs: number = 45
}

export class ThemeIconSize {
  sm: number = 16
  md: number = 20
  lg: number = 24
  xl: number = 28
  minTouch: number = 44
}

export class ThemeNav {
  tabHeight: number = 68
  tabMax: number = 5
}

export class Theme {
  static readonly space: ThemeSpace = new ThemeSpace()
  static readonly radius: ThemeRadius = new ThemeRadius()
  static readonly type: ThemeTypeScale = new ThemeTypeScale()
  static readonly motion: ThemeMotion = new ThemeMotion()
  static readonly icon: ThemeIconSize = new ThemeIconSize()
  static readonly nav: ThemeNav = new ThemeNav()

  private static mode: ColorMode = 'system'
  private static forcedDark: boolean = false

  static setColorMode(mode: ColorMode): void {
    Theme.mode = mode
  }

  static setForcedDark(dark: boolean): void {
    Theme.forcedDark = dark
  }

  static isDark(): boolean {
    if (Theme.mode === 'dark') {
      return true
    }
    if (Theme.mode === 'light') {
      return false
    }
    return Theme.forcedDark
  }

  static colors(): ThemeColors {
    if (Theme.isDark()) {
      return Theme.darkColors()
    }
    return Theme.lightColors()
  }

  static applyBrandPrimary(hex: string): void {
    AppStorage.setOrCreate('brandPrimary', hex)
  }

  static lightColors(): ThemeColors {
    return new ThemeColors()
  }

  static darkColors(): ThemeColors {
    const c = new ThemeColors()
    c.brandPrimary = '#D7A66F'
    c.brandPrimaryPressed = '#E5BC8C'
    c.brandPrimaryContainer = '#513823'
    c.brandOnPrimary = '#241B17'
    c.brandDeep = '#160F0C'
    c.brandAccent = '#A8B59B'
    c.surfacePage = '#17110E'
    c.surfaceSubtle = '#211813'
    c.surfaceCard = '#2A1F1A'
    c.surfaceGlass = 'rgba(42,31,26,0.78)'
    c.surfaceInverse = '#F3EBDD'
    c.textPrimary = '#F7EFE4'
    c.textSecondary = '#D8C7B2'
    c.textTertiary = '#AA9685'
    c.textOnInverse = '#241B17'
    c.strokeHairline = 'rgba(243,235,221,0.10)'
    c.strokeStrong = 'rgba(243,235,221,0.20)'
    c.success = '#A8B59B'
    c.successContainer = '#2D3A2C'
    c.warning = '#E2AF70'
    c.warningContainer = '#493018'
    c.danger = '#E48E80'
    c.dangerContainer = '#4A211D'
    c.info = '#A8B59B'
    c.overlayScrim = 'rgba(0,0,0,0.56)'
    c.chart1 = '#D7A66F'
    c.chart2 = '#A8B59B'
    c.chart3 = '#E2AF70'
    c.chart4 = '#C89B83'
    c.chart5 = '#D8C7B2'
    return c
  }

  static shadowSm(): string {
    return Theme.isDark() ? '0 1vp 2vp rgba(0,0,0,0.25)' : '0 1vp 2vp rgba(10,37,64,0.04)'
  }

  static shadowMd(): string {
    return Theme.isDark() ? '0 4vp 16vp rgba(0,0,0,0.35)' : '0 4vp 16vp rgba(10,37,64,0.06)'
  }
}
