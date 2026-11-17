export class ArtRoute {
  kind: string = ''
  id: string = ''
  tab: number = 0
}
/** Owned by the current session's root component; never persisted across account changes. */
export class NavigationHistory {
  private entries: ArtRoute[] = []
  push(kind: string, id: string, tab: number): void {
    const route = new ArtRoute(); route.kind = kind; route.id = id; route.tab = tab
    this.entries.push(route)
  }
  pop(): ArtRoute | undefined { return this.entries.pop() }
  clear(): void { this.entries = [] }
  hasEntries(): boolean { return this.entries.length > 0 }
}
