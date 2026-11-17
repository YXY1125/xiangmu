export class BrewMath {
  static water(dose: number, ratio: number): number {
    if (dose <= 0 || ratio < 12 || ratio > 18) return 0
    return Math.round(dose * ratio)
  }

  static stageWater(total: number, percent: number): number {
    if (total <= 0 || percent < 0 || percent > 100) return 0
    return Math.round(total * percent / 100)
  }

  static validRatio(ratio: number): boolean {
    return ratio >= 12 && ratio <= 18
  }
}
