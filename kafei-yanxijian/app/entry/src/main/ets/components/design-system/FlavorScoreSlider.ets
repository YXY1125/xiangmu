import { Theme } from './Theme'

/** Two-way bound flavor score control; label and thumb always read the same state. */
@Component
export struct FlavorScoreSlider {
  @Prop label: string = ''
  @Link value: number

  build() {
    Column({ space: 4 }) {
      Row() {
        Text(this.label).fontSize(13).layoutWeight(1)
        Text(`${this.value}/5`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.colors().brandPrimary)
      }.width('100%')
      Slider({ value: this.value, min: 1, max: 5, step: 1 })
        .selectedColor(Theme.colors().brandPrimary)
        .onChange((score: number) => { this.value = Math.round(score) })
    }
    .padding(13)
    .backgroundColor(Theme.colors().surfaceCard)
    .borderRadius(16)
    .width('100%')
  }
}
