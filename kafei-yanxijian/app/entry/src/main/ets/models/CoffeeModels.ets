export class KnowledgeItem {
  id: string = ''
  title: string = ''
  category: string = ''
  summary: string = ''
  readingMinutes: number = 0
  observation: string = ''
  practice: string = ''

  constructor(id: string, title: string, category: string, summary: string, minutes: number,
    observation: string, practice: string) {
    this.id = id
    this.title = title
    this.category = category
    this.summary = summary
    this.readingMinutes = minutes
    this.observation = observation
    this.practice = practice
  }
}

export class RecipeItem {
  id: string = ''
  name: string = ''
  method: string = ''
  ratio: number = 15
  temperature: number = 92
  flavor: string = ''
  dose: number = 15
  water: number = 225
  durationSeconds: number = 150
  steps: string[] = []

  constructor(id: string, name: string, method: string, ratio: number, temperature: number, flavor: string,
    dose: number, water: number, durationSeconds: number, steps: string[]) {
    this.id = id
    this.name = name
    this.method = method
    this.ratio = ratio
    this.temperature = temperature
    this.flavor = flavor
    this.dose = dose
    this.water = water
    this.durationSeconds = durationSeconds
    this.steps = steps
  }
}

export class EquipmentItem {
  id: string = ''
  name: string = ''
  category: string = ''
  principle: string = ''
  suitableFor: string = ''
  usage: string = ''
  tradeoffs: string = ''
  maintenance: string = ''

  constructor(id: string, name: string, category: string, principle: string, suitableFor: string,
    usage: string, tradeoffs: string, maintenance: string) {
    this.id = id
    this.name = name
    this.category = category
    this.principle = principle
    this.suitableFor = suitableFor
    this.usage = usage
    this.tradeoffs = tradeoffs
    this.maintenance = maintenance
  }
}

export class BrewRecordDraft {
  coffeeName: string = ''
  bean: string = ''
  dose: number = 15
  water: number = 225
  temperature: number = 92
  grind: string = '中细研磨'
  durationSeconds: number = 150
  method: string = '手冲'
  equipment: string = 'V60'
  note: string = ''
  imageKey: string = ''
}

export class FlavorScores {
  acidity: number = 3
  sweetness: number = 3
  bitterness: number = 3
  body: number = 3
  aroma: number = 3
  aftertaste: number = 3
  overall: number = 3

  average(): number {
    return (this.acidity + this.sweetness + this.bitterness + this.body + this.aroma + this.aftertaste + this.overall) / 7
  }
}

export class UserSummary {
  learningCount: number = 0
  brewCount: number = 0
  recipeCount: number = 0
  evaluationCount: number = 0
  favoriteCount: number = 0
  recipeFavoriteCount: number = 0
  checkInCount: number = 0
  experience: number = 0

  levelName(): string {
    if (this.experience >= 1200) return '咖啡研习大师'
    if (this.experience >= 700) return '精品咖啡探索家'
    if (this.experience >= 360) return '进阶研习者'
    if (this.experience >= 160) return '咖啡爱好者'
    if (this.experience >= 60) return '初阶探索者'
    return '咖啡新手'
  }
}

export class CoffeeRecord {
  id: string = ''
  kind: string = ''
  status: string = 'active'
  version: number = 1
  parentVersionId: string = ''
  createdAt: string = ''
  updatedAt: string = ''
  payload: RecordPayload = new RecordPayload()
}

export class RecordPayload {
  coffeeName: string = ''
  bean: string = ''
  method: string = ''
  equipment: string = ''
  grind: string = ''
  note: string = ''
  name: string = ''
  steps: string = ''
  flavor: string = ''
  knowledgeId: string = ''
  targetType: string = ''
  targetId: string = ''
  imageKey: string = ''
  coverKey: string = ''
  dose: number = 0
  water: number = 0
  temperature: number = 0
  durationSeconds: number = 0
  ratio: number = 0
  tags: string[] = []
  scores: FlavorScores = new FlavorScores()
}

export class CoffeeRecordList {
  items: CoffeeRecord[] = []
}

export class UserRecipeDraft {
  name: string = ''
  bean: string = ''
  ratio: number = 15
  temperature: number = 92
  method: string = '手冲'
  steps: string = ''
  flavor: string = ''
  coverKey: string = ''
}

export class MediaUploadResult {
  key: string = ''
  sizeBytes: number = 0
}

export class ActivityDay {
  date: string = ''
  label: string = ''
  brewCount: number = 0
  learningCount: number = 0
  evaluationCount: number = 0
}

export class MethodCount {
  name: string = ''
  count: number = 0
}

export class ActivityStats {
  days: ActivityDay[] = []
  methods: MethodCount[] = []
}

export class UserProfile {
  nickname: string = ''
  bio: string = ''
  interestDirections: string[] = []
  updatedAt: string = ''
}

export class EvaluationAverages {
  acidity: number = 0
  sweetness: number = 0
  bitterness: number = 0
  body: number = 0
  aroma: number = 0
  aftertaste: number = 0
  overall: number = 0
}

export class TagCount {
  name: string = ''
  count: number = 0
}

export class EvaluationStats {
  count: number = 0
  averages: EvaluationAverages = new EvaluationAverages()
  tags: TagCount[] = []
}
