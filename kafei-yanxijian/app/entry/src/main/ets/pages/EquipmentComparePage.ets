import { AppRouter } from '../utils/AppRouter'
import { Theme } from '../components/design-system/Theme'
import { CoffeeCatalog } from '../services/CoffeeCatalog'
import { EquipmentItem } from '../models/CoffeeModels'

@Component
struct EquipmentSelector {
  @Prop title: string = ''
  @Prop items: EquipmentItem[] = []
  @Prop selectedId: string = ''
  onSelect: (id: string) => void = () => {}

  build() {
    Column({ space: 8 }) {
      Text(this.title).fontSize(12).fontColor(Theme.colors().textSecondary).width('100%')
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.items, (item: EquipmentItem) => {
            Button(item.name)
              .fontSize(12)
              .fontColor(this.selectedId === item.id ? '#F3EBDD' : Theme.colors().textPrimary)
              .backgroundColor(this.selectedId === item.id ? '#241B17' : Theme.colors().surfaceCard)
              .borderRadius(16)
              .onClick(() => this.onSelect(item.id))
          }, (item: EquipmentItem) => item.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }.width('100%')
  }
}

@Component
struct EquipmentCompareRow {
  @Prop label: string = ''
  @Prop left: string = ''
  @Prop right: string = ''

  build() {
    Column({ space: 10 }) {
      Text(this.label).fontSize(11).fontColor(Theme.colors().brandPrimary).width('100%')
      Row({ space: 8 }) {
        Text(this.left).layoutWeight(1).fontSize(13).lineHeight(20).textAlign(TextAlign.Center)
        Text(this.right).layoutWeight(1).fontSize(13).lineHeight(20).textAlign(TextAlign.Center)
      }.width('100%')
    }
    .padding(16)
    .backgroundColor(Theme.colors().surfaceCard)
    .borderRadius(17)
    .width('100%')
  }
}

@Entry
@Component
struct EquipmentComparePage {
  @State leftId: string = 'v60'
  @State rightId: string = 'flatbed'
  private items: EquipmentItem[] = CoffeeCatalog.equipment()

  aboutToAppear(): void {
    const params = AppRouter.getParams(this.getUIContext()) as Record<string, string>
    const requestedId = params ? params['id'] : ''
    if (this.items.some((item: EquipmentItem) => item.id === requestedId)) {
      this.leftId = requestedId
      this.rightId = this.firstOtherId(requestedId)
    }
  }

  private firstOtherId(id: string): string {
    const match = this.items.find((item: EquipmentItem) => item.id !== id)
    return match ? match.id : id
  }

  private selected(id: string): EquipmentItem {
    return this.items.find((item: EquipmentItem) => item.id === id) ?? this.items[0]
  }

  private selectLeft(id: string): void {
    this.leftId = id
    if (this.rightId === id) this.rightId = this.firstOtherId(id)
  }

  private selectRight(id: string): void {
    this.rightId = id
    if (this.leftId === id) this.leftId = this.firstOtherId(id)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Text('‹').fontSize(30).onClick(() => AppRouter.back(this.getUIContext()))
          Text('器具对比').fontSize(26).fontWeight(FontWeight.Bold).margin({ left: 12 })
        }.width('100%')
        Text('分别选择两种器具，下面的原理、适用场景和维护信息会立即切换。')
          .fontSize(12).lineHeight(19).fontColor(Theme.colors().textSecondary).width('100%')
        EquipmentSelector({ title: '左侧器具', items: this.items, selectedId: this.leftId,
          onSelect: (id: string) => this.selectLeft(id) })
        EquipmentSelector({ title: '右侧器具', items: this.items, selectedId: this.rightId,
          onSelect: (id: string) => this.selectRight(id) })
        Row({ space: 8 }) {
          Text(this.selected(this.leftId).name)
            .layoutWeight(1).fontSize(18).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .padding(18).backgroundColor('#241B17').fontColor('#F3EBDD').borderRadius(18)
          Text(this.selected(this.rightId).name)
            .layoutWeight(1).fontSize(18).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .padding(18).backgroundColor('#241B17').fontColor('#F3EBDD').borderRadius(18)
        }.width('100%')
        EquipmentCompareRow({ label: '分类', left: this.selected(this.leftId).category, right: this.selected(this.rightId).category })
        EquipmentCompareRow({ label: '工作原理', left: this.selected(this.leftId).principle, right: this.selected(this.rightId).principle })
        EquipmentCompareRow({ label: '适用人群', left: this.selected(this.leftId).suitableFor, right: this.selected(this.rightId).suitableFor })
        EquipmentCompareRow({ label: '优势与局限', left: this.selected(this.leftId).tradeoffs, right: this.selected(this.rightId).tradeoffs })
        EquipmentCompareRow({ label: '清洁维护', left: this.selected(this.leftId).maintenance, right: this.selected(this.rightId).maintenance })
        Text('对比内容是器具结构的一般性理解，实际结果仍取决于咖啡豆、研磨、水质和操作。')
          .fontSize(11).lineHeight(18).fontColor(Theme.colors().textTertiary).margin({ bottom: 24 })
      }.padding(16).width('100%')
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
  }
}
