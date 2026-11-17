@Observed
export class FlowerMaterial {
  id: string = ''
  name: string = ''
  alias: string = ''
  category: string = ''
  family: string = ''
  flowerLanguage: string = ''
  colors: string[] = []
  season: string = ''
  care: string = ''
  pairing: string = ''
  atlasKey: string = 'atlas_main'
  atlasIndex: number = 0
  favorite: boolean = false
}

export class StudioObject {
  materialId: string = ''
  objectId: string = ''
  name: string = ''
  assetKey: string = 'rose'
  atlasKey: string = ''
  atlasIndex: number = 0
  x: number = 100
  y: number = 90
  scale: number = 0.7
  rotation: number = 0
  zIndex: number = 1
}

export class StudioSnapshot {
  background: string = 'cream'
  container: string = 'vase'
  objects: StudioObject[] = []
}

@Observed
export class FlowerWork {
  id: string = ''
  title: string = ''
  authorName: string = ''
  coverKey: string = 'hero_home'
  themeName: string = ''
  likeCount: number = 0
  liked: boolean = false
  collected: boolean = false
  visibility: string = 'public'
  updatedAt: string = ''
  canvas: StudioSnapshot = new StudioSnapshot()
}

@Observed
export class FlowerTutorial {
  id: string = ''
  title: string = ''
  summary: string = ''
  category: string = ''
  difficulty: string = ''
  minutes: number = 0
  progress: number = 0
  favorite: boolean = false
  materialIds: string[] = []
  tools: string[] = []
  steps: TutorialStep[] = []
}

@Observed
export class TutorialStep {
  index: number = 1
  title: string = ''
  instruction: string = ''
  imageKey: string = 'cover_tutorial'
}

@Observed
export class FlowerEvent {
  id: string = ''
  title: string = ''
  theme: string = ''
  summary: string = ''
  startsAt: string = ''
  endsAt: string = ''
  status: string = ''
  joined: boolean = false
  rules: string[] = []
  recommendedMaterialIds: string[] = []
}

@Observed
export class FlowerTheme {
  id: string = ''
  name: string = ''
  introduction: string = ''
  recommendedMaterialIds: string[] = []
  recommendedContainer: string = 'vase'
  requirements: string[] = []
}

@Observed
export class FlowerChallenge {
  id: string = ''
  type: string = ''
  name: string = ''
  introduction: string = ''
  recommendedMaterialIds: string[] = []
  requirements: string[] = []
}

@Observed
export class UserAchievement {
  id: string = ''
  title: string = ''
  description: string = ''
  current: number = 0
  target: number = 1
  unlocked: boolean = false
  unlockedAt: string = ''
}

@Observed
export class LearningRecord {
  id: string = ''
  title: string = ''
  category: string = ''
  step: number = 0
  completed: boolean = false
  progress: number = 0
  updatedAt: string = ''
}

@Observed
export class EventRecord {
  eventId: string = ''
  title: string = ''
  status: string = ''
  joinedAt: string = ''
  submissions: EventSubmissionRecord[] = []
}

@Observed
export class EventSubmissionRecord {
  id: string = ''
  workId: string = ''
  submittedAt: string = ''
}

export class MeDashboardPayload {
  collectedWorks: FlowerWork[] = []
  favoriteMaterials: FlowerMaterial[] = []
  favoriteTutorials: FlowerTutorial[] = []
  learning: LearningRecord[] = []
  eventRecords: EventRecord[] = []
}

export class HomePayload {
  dailyLanguage: string = ''
  dailyInspiration: string = ''
  materials: FlowerMaterial[] = []
  tutorials: FlowerTutorial[] = []
  works: FlowerWork[] = []
  events: FlowerEvent[] = []
}

export class PagePayload<T> {
  items: T[] = []
  total: number = 0
}

export class EmptyFlowerPayload {}
