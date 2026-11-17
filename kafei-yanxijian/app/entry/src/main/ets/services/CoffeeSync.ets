/** 全局轻量修订号：真实写操作成功后递增，所有统计/列表据此重新拉取服务端。 */
export class CoffeeSync {
  static revision(): number {
    return AppStorage.get<number>('coffeeDataRevision') ?? 0
  }

  static bump(): void {
    AppStorage.setOrCreate('coffeeDataRevision', CoffeeSync.revision() + 1)
  }

  static resetForAccountChange(): void {
    CoffeeSync.bump()
  }
}
