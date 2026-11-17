import { Theme } from '../components/design-system/Theme'
import { AssetResolver } from '../utils/AssetResolver'
import { GameRecord } from '../models/CultureModels'
import { LocalDataStore } from '../services/LocalDataStore'
import { BackService } from '../services/BackService'

class GameInfo {
  id: string = ''
  name: string = ''
  intro: string = ''
  difficulty: string = ''
  cover: string = 'cover_playground'
}

function game(id: string, name: string, intro: string, difficulty: string, cover: string): GameInfo {
  const item = new GameInfo()
  item.id = id
  item.name = name
  item.intro = intro
  item.difficulty = difficulty
  item.cover = cover
  return item
}

@Component
export struct MessagesPage {
  @State selected: string = ''
  private games: GameInfo[] = [
    game('puzzle', '年画拼图', '交换切块，还原完整年画。', '简单 3×3', 'exhibition_classic'),
    game('difference', '火眼金睛', '在限定时间找出画面差异。', '普通 · 3 处差异', 'banner_festival'),
    game('match', '福气配对', '翻开卡片，记住并配对吉祥纹样。', '简单 · 6 组', 'cover_playground'),
    game('quiz', '年画知识问答', '用应用内文化知识完成挑战。', '普通 · 5 题', 'banner_craft'),
    game('treasure', '纹样寻宝', '按照目标提示找到隐藏纹样。', '困难 · 4 个目标', 'hero_home')
  ]

  build() {
    Stack() {
      Column() {
        Column({ space: 4 }) {
          Text('互动乐园').fontSize(30).fontWeight(FontWeight.Bold).width('100%')
          Text('五种玩法，把文化知识变成发现').fontSize(13).fontColor(Theme.colors().textSecondary).width('100%')
        }.padding({ left: 16, right: 16, top: 16, bottom: 12 }).alignItems(HorizontalAlign.Start)
        Scroll() {
          Column({ space: 14 }) {
            ForEach(this.games, (item: GameInfo) => {
              Stack({ alignContent: Alignment.BottomStart }) {
                Image(AssetResolver.media(item.cover)).width('100%').height(185).objectFit(ImageFit.Cover).borderRadius(22)
                Row() {
                  Column({ space: 5 }) {
                    Text(item.name).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                    Text(item.intro).fontSize(12).fontColor('#FFF7E8').maxLines(1)
                    Text(item.difficulty).fontSize(11).fontColor('#FFE39A')
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Button('开始').height(42).fontSize(13).backgroundColor(Theme.colors().brandPrimary).fontColor('#FFFFFF')
                }.padding(14).width('100%').backgroundColor('rgba(56,45,42,0.52)')
              }.width('100%').onClick(() => { this.selected = item.id; AppStorage.setOrCreate('tabBarHidden', true) })
            }, (item: GameInfo) => item.id)
          }.padding({ left: 16, right: 16, bottom: 28 }).width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off)
      }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
      if (this.selected.length > 0) {
        GameRoom({ gameId: this.selected, onExit: () => { this.selected = ''; AppStorage.setOrCreate('tabBarHidden', false) } })
      }
    }.width('100%').height('100%')
  }
}

@Component
struct GameRoom {
  private backId: number = 0
  @Prop gameId: string = 'puzzle'
  @State phase: string = 'ready'
  @State paused: boolean = false
  @State seconds: number = 0
  @State score: number = 0
  @State message: string = ''
  @State puzzle: number[] = [4, 1, 7, 2, 8, 3, 0, 6, 5]
  @State firstTile: number = -1
  @State found: number[] = []
  @State cards: number[] = [1, 4, 2, 5, 3, 6, 4, 1, 6, 2, 5, 3]
  @State openCards: number[] = []
  @State matched: number[] = []
  @State question: number = 0
  @State correct: number = 0
  @State puzzleSize: number = 3
  @State puzzleImage: string = 'exhibition_classic'
  @State availableWidth: number = 320
  @State answered: boolean = false
  @State steps: number = 0
  @State recordSaved: boolean = false
  onExit: () => void = () => {}
  private timer: number = -1
  private flipTimer: number = -1

  aboutToAppear(): void {
    this.backId = BackService.register(() => { this.requestExit(); return true })
  }

  aboutToDisappear(): void {
    BackService.remove(this.backId)
    if (this.timer >= 0) clearInterval(this.timer)
    if (this.flipTimer >= 0) clearTimeout(this.flipTimer)
  }

  private title(): string {
    if (this.gameId === 'puzzle') return '年画拼图'
    if (this.gameId === 'difference') return '火眼金睛'
    if (this.gameId === 'match') return '福气配对'
    if (this.gameId === 'quiz') return '年画知识问答'
    return '纹样寻宝'
  }

  private start(): void {
    if (this.phase === 'playing') return
    this.phase = 'playing'
    this.paused = false
    this.seconds = 0
    this.score = 0
    this.message = ''
    this.firstTile = -1
    this.found = []
    this.openCards = []
    this.matched = []
    this.question = 0
    this.correct = 0
    this.steps = 0
    this.answered = false
    this.recordSaved = false
    const puzzleValues: number[] = []
    for (let p = 0; p < this.puzzleSize * this.puzzleSize; p++) puzzleValues.push(p)
    this.puzzle = this.shuffle(puzzleValues)
    this.cards = this.shuffle([1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6])
    this.timer = setInterval(() => {
      if (!this.paused && this.phase === 'playing') {
        this.seconds++
        if ((this.gameId === 'difference' || this.gameId === 'treasure') && this.seconds >= 60) this.finish(false)
      }
    }, 1000)
  }

  private shuffle(values: number[]): number[] {
    const copy = values.slice()
    for (let i = copy.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      const temp = copy[i]
      copy[i] = copy[j]
      copy[j] = temp
    }
    if (copy.length > 1 && copy.every((value: number, index: number) => value === index)) {
      const temp = copy[0]; copy[0] = copy[1]; copy[1] = temp
    }
    return copy
  }

  private finish(success: boolean): void {
    if (this.phase === 'finished') return
    this.phase = 'finished'
    if (this.timer >= 0) clearInterval(this.timer)
    if (success && this.gameId !== 'quiz') this.score = Math.max(this.score, 1000 - this.seconds * 5)
    const record = new GameRecord()
    record.recordId = `record-${Date.now()}`
    record.gameId = this.gameId
    record.score = this.score
    record.durationSeconds = this.seconds
    record.detail = this.gameId === 'quiz' ? `${this.correct}/5 题正确` : success ?
      `完成 · ${this.steps} 步${this.gameId === 'puzzle' ? ' · ' + this.puzzleSize + '×' + this.puzzleSize : ''}` : '超时或退出'
    record.completedAt = Date.now()
    LocalDataStore.saveGameRecord(record).then(() => this.recordSaved = true)
      .catch(() => this.message = '成绩保存失败，请检查设备存储空间')
  }

  private choosePuzzle(index: number): void {
    if (this.firstTile < 0) {
      this.firstTile = index
      return
    }
    const copy = this.puzzle.slice()
    const value = copy[this.firstTile]
    copy[this.firstTile] = copy[index]
    copy[index] = value
    this.steps++
    this.puzzle = copy
    this.firstTile = -1
    let complete = true
    for (let i = 0; i < copy.length; i++) if (copy[i] !== i) complete = false
    if (complete) this.finish(true)
  }

  private findPoint(index: number): void {
    if (this.found.indexOf(index) >= 0) return
    this.found = this.found.concat([index])
    this.score += 200
    this.message = '找到一处！'
    if (this.found.length >= 3) this.finish(true)
  }

  private flipCard(index: number): void {
    if (this.matched.indexOf(index) >= 0 || this.openCards.indexOf(index) >= 0) return
    if (this.openCards.length >= 2) return
    const opened = this.openCards.concat([index])
    this.openCards = opened
    if (opened.length === 2) {
      this.steps++
      if (this.cards[opened[0]] === this.cards[opened[1]]) {
        this.matched = this.matched.concat(opened)
        this.openCards = []
        this.score += 120
        if (this.matched.length === this.cards.length) this.finish(true)
      } else {
        this.message = '再记一记这两个位置'
        this.flipTimer = setTimeout(() => { this.openCards = []; this.message = '' }, 1500)
      }
    }
  }

  private answer(index: number): void {
    if (this.answered) return
    this.answered = true
    const answers: number[] = [1, 0, 2, 1, 0]
    if (index === answers[this.question]) {
      this.correct++
      this.score += 200
      this.message = '回答正确：' + this.explanation(this.question)
    } else {
      this.message = '正确答案解析：' + this.explanation(this.question)
    }
  }

  private nextQuestion(): void {
    if (!this.answered) return
    if (this.question >= 4) this.finish(true)
    else { this.question++; this.answered = false; this.message = '' }
  }

  private requestExit(): void {
    if (this.phase !== 'playing') { this.onExit(); return }
    this.paused = true
    AlertDialog.show({ title: '结束本局挑战？', message: '结束后会保存当前成绩。',
      primaryButton: { value: '结束并结算', action: () => { this.paused = false; this.finish(false) } },
      secondaryButton: { value: '继续游戏', action: () => this.paused = false },
      cancel: () => this.paused = false })
  }

  private explanation(index: number): string {
    const values: string[] = ['木版年画通过刻版和印制形成图像。', '朱砂红常传递热烈喜庆的感受。', '不同颜色可由不同色版依次完成。', '门神题材寄托守护家宅的愿望。', '纹样寓意需结合地域和画面语境理解。']
    return values[index]
  }

  build() {
    Column() {
      Row() {
        Button('‹').fontSize(30).width(44).height(44).backgroundColor('transparent').fontColor(Theme.colors().textPrimary)
          .onClick(() => this.requestExit())
        Text(this.title()).fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Button(this.paused ? '继续' : '暂停').fontSize(12).height(38).backgroundColor(Theme.colors().surfaceCard)
          .fontColor(Theme.colors().textPrimary).onClick(() => this.paused = !this.paused)
      }.padding({ left: 10, right: 12, top: 10 }).width('100%')
      Row() {
        Text(`用时 ${this.seconds}s`).fontSize(12).fontColor(Theme.colors().textSecondary)
        Blank()
        Text(`得分 ${this.score}`).fontSize(12).fontColor(Theme.colors().brandPrimary)
      }.padding({ left: 18, right: 18, top: 8, bottom: 8 }).width('100%')
      if (this.phase === 'ready') {
        Scroll() {
        Column({ space: 16 }) {
          Image(AssetResolver.media('cover_playground')).width(270).height(270).objectFit(ImageFit.Cover).borderRadius(28)
          Text(this.title()).fontSize(28).fontWeight(FontWeight.Bold)
          Text('准备好后开始，进行中可暂停或退出。成绩会保存到“我的”。').fontSize(14)
            .lineHeight(22).fontColor(Theme.colors().textSecondary).textAlign(TextAlign.Center).width(280)
          if (this.gameId === 'puzzle') {
            Text('选择画面').fontSize(14).fontWeight(FontWeight.Bold)
            Row({ space: 10 }) {
              ForEach(['exhibition_classic', 'exhibition_doorgods', 'exhibition_mythology'], (id: string) => {
                Image(AssetResolver.media(id)).width(78).height(64).objectFit(ImageFit.Cover).borderRadius(10)
                  .border({ width: this.puzzleImage === id ? 3 : 0, color: Theme.colors().brandAccent })
                  .onClick(() => this.puzzleImage = id)
              }, (id: string) => id)
            }
            Row({ space: 8 }) {
              this.Difficulty('简单 3×3', 3)
              this.Difficulty('普通 4×4', 4)
              this.Difficulty('困难 5×5', 5)
            }
          }
          Button('开始游戏').width(220).height(52).backgroundColor(Theme.colors().brandPrimary).fontColor('#FFFFFF')
            .borderRadius(26).onClick(() => this.start())
        }.padding({ top: 10, bottom: 24 }).width('100%').justifyContent(FlexAlign.Center)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      } else if (this.phase === 'finished') {
        Column({ space: 14 }) {
          Text('挑战结束').fontSize(30).fontWeight(FontWeight.Bold)
          Text(`得分 ${this.score}`).fontSize(22).fontColor(Theme.colors().brandPrimary)
          Text(`用时 ${this.seconds} 秒 · ${this.recordSaved ? '记录已保存' : '成绩尚未保存'}`).fontSize(13).fontColor(Theme.colors().textSecondary)
          Button('再玩一次').width(200).height(50).backgroundColor(Theme.colors().brandPrimary).fontColor('#FFFFFF')
            .onClick(() => this.start())
          Button('返回乐园').width(200).height(48).backgroundColor(Theme.colors().surfaceCard)
            .fontColor(Theme.colors().textPrimary).onClick(() => this.onExit())
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.paused) {
        Column({ space: 16 }) {
          Text('游戏已暂停').fontSize(28).fontWeight(FontWeight.Bold)
          Button('继续').width(180).height(50).backgroundColor(Theme.colors().brandPrimary).fontColor('#FFFFFF')
            .onClick(() => this.paused = false)
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        this.GameContent()
      }
      if (this.message.length > 0 && this.phase === 'playing') {
        Text(this.message).fontSize(12).fontColor(Theme.colors().brandPrimary).padding(12).width('100%').textAlign(TextAlign.Center)
      }
    }.width('100%').height('100%').backgroundColor(Theme.colors().surfacePage)
      .onAreaChange((_oldArea: Area, area: Area) => this.availableWidth = Number(area.width))
  }

  @Builder
  GameContent() {
    Column() {
      if (this.gameId === 'puzzle') {
        Text('点击两块进行交换').fontSize(13).fontColor(Theme.colors().textSecondary).margin({ bottom: 12 })
        Grid() {
          ForEach(this.puzzle, (tile: number, index: number) => {
            GridItem() {
              Stack() {
                Image(AssetResolver.media(this.puzzleImage)).width(this.boardWidth()).height(this.boardWidth()).objectFit(ImageFit.Fill)
                  .position({ x: -(tile % this.puzzleSize) * this.tileSize(), y: -Math.floor(tile / this.puzzleSize) * this.tileSize() })
                Text(`${tile + 1}`).fontSize(12).fontColor('#FFFFFF').backgroundColor('rgba(0,0,0,0.35)').padding(3)
              }.width(this.tileSize()).height(this.tileSize()).clip(true)
                .border({ width: this.firstTile === index ? 3 : 1, color: this.firstTile === index ? '#D6A64D' : '#FFFDF8' })
                .onClick(() => this.choosePuzzle(index))
            }
          }, (tile: number, index: number) => `${index}-${tile}`)
        }.columnsTemplate(this.gridTemplate()).rowsTemplate(this.gridTemplate()).width(this.boardWidth()).height(this.boardWidth())
      } else if (this.gameId === 'difference') {
        Text('对比两幅年画，点击右图新增的 3 个纹样').fontSize(12).fontColor(Theme.colors().textSecondary).margin({ bottom: 10 })
        Row({ space: 8 }) { this.DifferenceScene(false); this.DifferenceScene(true) }.width(this.boardWidth())
      } else if (this.gameId === 'match') {
        Text(`翻开并配对 6 组吉祥纹样 · ${this.steps} 步`).fontSize(13).fontColor(Theme.colors().textSecondary).margin({ bottom: 12 })
        Grid() {
          ForEach(this.cards, (value: number, index: number) => {
            GridItem() {
              Column() {
                Text(this.matched.indexOf(index) >= 0 || this.openCards.indexOf(index) >= 0 ? this.cardSymbol(value) : '年')
                  .fontSize(26).fontColor(this.matched.indexOf(index) >= 0 ? '#382D2A' : this.openCards.indexOf(index) >= 0 ? Theme.colors().brandPrimary : '#FFFFFF')
              }.width(72).height(72).justifyContent(FlexAlign.Center).id(`match-card-${index}`)
                .backgroundColor(this.matched.indexOf(index) >= 0 ? '#DCEAE4' : this.openCards.indexOf(index) >= 0 ? '#FFFDF8' : Theme.colors().brandPrimary)
                .borderRadius(14).onClick(() => this.flipCard(index))
            }
          }, (_value: number, index: number) => `${index}`)
        }.columnsTemplate('1fr 1fr 1fr').columnsGap(10).rowsGap(10).width(250)
      } else if (this.gameId === 'quiz') {
        Text(`第 ${this.question + 1} / 5 题`).fontSize(13).fontColor(Theme.colors().brandPrimary).margin({ bottom: 10 })
        Column({ space: 18 }) {
          Text(this.questionText()).fontSize(22).fontWeight(FontWeight.Bold).lineHeight(32).textAlign(TextAlign.Center)
          ForEach(this.options(), (option: string, index: number) => {
            Button(option).width(300).height(52).fontSize(14).backgroundColor(Theme.colors().surfaceCard)
              .fontColor(Theme.colors().textPrimary).borderRadius(18).enabled(!this.answered).onClick(() => this.answer(index))
          }, (option: string) => option)
          if (this.answered) {
            Button(this.question === 4 ? '查看成绩' : '下一题').height(46).backgroundColor(Theme.colors().brandPrimary)
              .fontColor('#FFFFFF').onClick(() => this.nextQuestion())
          }
        }
      } else {
        Text('目标：依次找到 祥云、牡丹、如意、铜钱').fontSize(13).fontColor(Theme.colors().textSecondary).margin({ bottom: 10 })
        Stack() {
          Image(AssetResolver.media('hero_home')).width(this.boardWidth()).height(this.boardWidth() * 1.1).objectFit(ImageFit.Cover).borderRadius(18)
            .onClick(() => this.message = '没有找到目标纹样')
          this.Treasure(0, 'motif_cloud', 0.08, 0.10)
          this.Treasure(1, 'motif_peony', 0.72, 0.24)
          this.Treasure(2, 'motif_ruyi', 0.18, 0.75)
          this.Treasure(3, 'motif_coin', 0.72, 0.90)
        }.width(this.boardWidth()).height(this.boardWidth() * 1.1)
      }
    }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  Difficulty(label: string, size: number) {
    Button(label).height(38).fontSize(10).padding({ left: 10, right: 10 })
      .backgroundColor(this.puzzleSize === size ? Theme.colors().brandPrimary : Theme.colors().surfaceCard)
      .fontColor(this.puzzleSize === size ? '#FFFFFF' : Theme.colors().textPrimary)
      .onClick(() => this.puzzleSize = size)
  }

  private tileSize(): number { return this.boardWidth() / this.puzzleSize }
  private boardWidth(): number { return Math.max(220, Math.min(320, this.availableWidth - 24)) }

  @Builder
  DifferenceScene(changed: boolean) {
    Column({ space: 6 }) {
      Text(changed ? '寻找变化' : '原图').fontSize(12).fontColor(Theme.colors().brandPrimary)
      Stack() {
        Image(AssetResolver.media('banner_festival')).width((this.boardWidth() - 8) / 2).height(this.boardWidth() * 0.9)
          .objectFit(ImageFit.Cover).borderRadius(14).onClick(() => {
            if (changed) { this.message = '这里没有变化'; this.score = Math.max(0, this.score - 30) }
          })
        if (changed) {
          this.Hotspot(0, 0.08, 0.20)
          this.Hotspot(1, 0.60, 0.48)
          this.Hotspot(2, 0.30, 0.72)
        }
      }.width((this.boardWidth() - 8) / 2).height(this.boardWidth() * 0.9)
    }
  }

  private gridTemplate(): string {
    if (this.puzzleSize === 5) return '1fr 1fr 1fr 1fr 1fr'
    if (this.puzzleSize === 4) return '1fr 1fr 1fr 1fr'
    return '1fr 1fr 1fr'
  }

  @Builder
  Hotspot(index: number, x: number, y: number) {
    Stack() {
      Image(AssetResolver.media(index === 0 ? 'motif_cloud' : index === 1 ? 'motif_peony' : 'motif_coin')).width(36).height(36)
      if (this.found.indexOf(index) >= 0) Text('✓').fontSize(22).fontColor('#FFFFFF').backgroundColor('#527E70')
    }.width(44).height(44).id(`difference-hit-${index}`)
      .position({ x: x * (this.boardWidth() - 8) / 2, y: y * this.boardWidth() * 0.9 }).onClick(() => this.findPoint(index))
  }

  @Builder
  Treasure(index: number, label: string, x: number, y: number) {
    Stack() {
      Image(AssetResolver.media(label)).width(36).height(36)
      if (this.found.indexOf(index) >= 0) Text('✓').fontSize(24).fontColor('#FFFFFF').backgroundColor('#527E70')
    }.width(44).height(44).id(`treasure-hit-${index}`)
      .position({ x: x * this.boardWidth(), y: y * this.boardWidth() }).onClick(() => {
        if (index === this.found.length) {
          this.found = this.found.concat([index]); this.score += 180
          if (this.found.length >= 4) this.finish(true)
        } else this.message = '请按目标顺序寻找'
      })
  }

  private cardSymbol(value: number): string {
    const symbols: string[] = ['福', '云', '花', '狮', '吉', '春']
    return symbols[value - 1]
  }

  private questionText(): string {
    const values: string[] = ['木版年画最关键的制作媒介之一是什么？', '哪种颜色在本应用品牌中代表热烈喜庆？', '套色印刷的颜色通常如何完成？', '门神题材常寄托什么愿望？', '理解吉祥纹样寓意时应该注意什么？']
    return values[this.question]
  }

  private options(): string[] {
    const values: string[][] = [
      ['玻璃板', '雕刻木版', '金属屏幕'], ['朱砂红', '荧光蓝', '纯黑'], ['一次喷涂', '随机涂色', '不同色版依次印制'],
      ['追求速度', '守护家宅', '记录天气'], ['结合地域与语境', '只有唯一解释', '忽略画面内容']
    ]
    return values[this.question]
  }
}
