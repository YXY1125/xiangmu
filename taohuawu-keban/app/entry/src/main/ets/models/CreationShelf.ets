import { Creation, UserProfile } from './ArtModels'

// Saved work is a completed editable Creation, not an immutable publication
// Artwork. Publishing must never be required merely to see one's saved work.
export class CreationShelf {
  static completed(items: Creation[]): Creation[] { return CreationShelf.select(items, 'completed') }
  static drafts(items: Creation[]): Creation[] { return CreationShelf.select(items, 'draft') }
  private static select(items: Creation[], status: string): Creation[] {
    return items.filter(item => item.status === status).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt) || a.id.localeCompare(b.id))
  }
  static profile(profile: UserProfile, items: Creation[]): UserProfile {
    const result = new UserProfile()
    result.userId = profile.userId; result.nickname = profile.nickname; result.avatarKey = profile.avatarKey; result.bio = profile.bio
    result.workCount = CreationShelf.completed(items).length; result.draftCount = CreationShelf.drafts(items).length
    result.favoriteCount = profile.favoriteCount
    return result
  }
}
