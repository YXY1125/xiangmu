import { CharacterProfile, CultureArticle, Exhibition } from '../models/CultureModels'

/** Shared by live search and keyboard submit; an empty query never matches everything. */
export class CultureSearch {
  static matches(query: string, fields: string[]): boolean {
    const terms = query.trim().toLowerCase().split(/\s+/).filter((term: string) => term.length > 0)
    const text = fields.join(' ').toLowerCase()
    return terms.length > 0 && terms.every((term: string) => text.indexOf(term) >= 0)
  }

  static characters(query: string, items: CharacterProfile[]): CharacterProfile[] {
    return items.filter((item: CharacterProfile) => CultureSearch.matches(query,
      [item.name, item.series, item.personality, item.origin, item.meaning, item.story]))
  }

  static articles(query: string, items: CultureArticle[]): CultureArticle[] {
    return items.filter((item: CultureArticle) => CultureSearch.matches(query,
      [item.title, item.category, item.summary, item.body]))
  }

  static exhibitions(query: string, items: Exhibition[]): Exhibition[] {
    return items.filter((item: Exhibition) => CultureSearch.matches(query, [item.title, item.intro]))
  }
}
