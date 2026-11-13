import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

private let today = Day(year: 2026, month: 11, day: 13)

/// The seven titles of #45, in the order they are created: what `COLLATE NOCASE` returned for them put every
/// capital ahead of every small letter and the two spellings of "апельсин" at opposite ends.
private let seven = ["Ёлка", "Апельсин", "Банан", "Яблоко", "абрикос", "апельсин", "ёжик"]

private func sortedByTitle(_ store: Store, descending: Bool = false) throws -> [String] {
    let view = try store.createView(NewTaskView(title: "By title", filter: .status([.open]), sort: [SortKey(.title, descending: descending)]))
    return try store.tasks(in: view, today: today).map(\.title)
}

/// A list sorted by title ignores case in Cyrillic as it does in Latin: each pair of spellings stands together,
/// in the order of their ranks, and the capitals are no longer a block ahead of the small letters. `ё` keeps its
/// place after `я`, where its code point puts it: sorting it beside `е` is collation, which needs ICU (ADR-0001).
@Test func aListSortedByTitleIgnoresCaseInEveryScript() throws {
    let store = try makeStore()
    for title in seven { try store.createTask(NewTask(title: title)) }
    #expect(try sortedByTitle(store) == ["абрикос", "Апельсин", "апельсин", "Банан", "Яблоко", "ёжик", "Ёлка"])
    #expect(try sortedByTitle(store, descending: true) == ["Ёлка", "ёжик", "Яблоко", "Банан", "Апельсин", "апельсин", "абрикос"])
}

/// Titles that differ only in case are equal to the order, so the tail that makes it total decides between them as
/// it decides between equal titles: the rank, then the id. The ranks run against the ids, so that neither the ids
/// alone nor the titles' bytes give this order.
@Test func titlesThatDifferOnlyInCaseStandByRankThenID() throws {
    let store = try makeStore()
    let stamp = HLC(millis: 1_000, counter: 0)
    var ops: [JournalOperation] = []
    for (id, title, rank) in [("c", "АПЕЛЬСИН", "i"), ("b", "Апельсин", "i"), ("a", "апельсин", "j")] {
        ops += [store.op(.task, id, "title", .text(title), stamp), store.op(.task, id, "rank", .text(rank), stamp)]
    }
    try store.apply(ops)
    #expect(try sortedByTitle(store) == ["Апельсин", "АПЕЛЬСИН", "апельсин"])
}

/// Tags and views are ordered in Swift and tasks in SQL, and the two orders are one: the same titles come out of
/// quick find, as tags and as views, in the order a list sorted by title gives them as tasks.
@Test func tagsAndViewsOrderTheirTitlesAsAListOfTasksDoes() throws {
    let store = try makeStore()
    let titles = ["Ёлка", "Банан", "Яблоко", "абрикос", "ёжик", "Апельсин", "Zebra", "apple"].map { $0 + " zzz" }
    for title in titles {
        try store.createTask(NewTask(title: title))
        try store.createTag(title: title)
        try store.createView(NewTaskView(title: title))
    }
    let tasks = try sortedByTitle(store)
    var tags: [String] = []
    var views: [String] = []
    for hit in try store.quickFind("zzz", limit: 100) {
        switch hit {
        case .task: break
        case .tag(let tag): tags.append(tag.title)
        case .view(let view): views.append(view.title)
        }
    }
    #expect(tasks == ["apple zzz", "Zebra zzz", "абрикос zzz", "Апельсин zzz", "Банан zzz", "Яблоко zzz", "ёжик zzz", "Ёлка zzz"])
    #expect(tags == tasks)
    #expect(views == tasks)
}

/// A title spelled with a combining mark, as a name copied from the Finder is, stands in one place in a list sorted by
/// title and in quick find. SQLite compares the keys by their bytes, where `и` and a combining breve come before
/// `ия`; Swift's `<` compares the composed form, where that `й` comes after it.
@Test func aTitleWithACombiningMarkStandsInOnePlaceInSQLAndInSwift() throws {
    let store = try makeStore()
    let decomposed = "\u{438}\u{306}ка zzz"
    for title in ["ия zzz", decomposed, "йод zzz"] {
        try store.createTask(NewTask(title: title))
        try store.createTag(title: title)
        try store.createView(NewTaskView(title: title))
    }
    let tasks = try sortedByTitle(store)
    var tags: [String] = []
    var views: [String] = []
    for hit in try store.quickFind("zzz", limit: 100) {
        switch hit {
        case .task: break
        case .tag(let tag): tags.append(tag.title)
        case .view(let view): views.append(view.title)
        }
    }
    // Swift's `==` reads the two spellings of `й` as one text, so what the three lists are compared on is where
    // `ия` stands.
    #expect(tasks.firstIndex(of: "ия zzz") == 1)
    #expect(tags.firstIndex(of: "ия zzz") == 1)
    #expect(views.firstIndex(of: "ия zzz") == 1)
}
