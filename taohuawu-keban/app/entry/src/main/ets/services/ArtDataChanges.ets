import { SessionStore } from './SessionStore'

// Payload-free invalidation, separate from authentication/navigation revisions.
// Only server-confirmed writes in the still-current account may invalidate data.
export class ArtDataChanges {
  static confirmed(ownerRevision: number): void {
    if (ownerRevision !== SessionStore.revision() || !SessionStore.userId()) return
    AppStorage.setOrCreate('artDataRevision', (AppStorage.get<number>('artDataRevision') ?? 0) + 1)
  }
}
