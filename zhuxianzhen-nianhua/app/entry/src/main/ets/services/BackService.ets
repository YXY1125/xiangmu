class BackTarget {
  id: number = 0
  handle: () => boolean = () => false
}
export class BackService {
  private static targets: BackTarget[] = []
  private static sequence: number = 0
  static register(handle: () => boolean): number {
    const target = new BackTarget()
    target.id = ++BackService.sequence
    target.handle = handle
    BackService.targets.push(target)
    return target.id
  }
  static remove(id: number): void {
    BackService.targets = BackService.targets.filter((target: BackTarget) => target.id !== id)
  }
  static dispatch(): boolean {
    const snapshot = BackService.targets.slice().reverse()
    for (const target of snapshot) if (target.handle()) return true
    return false
  }
}
