import Testing
@testable import TodoCore
@testable import SQLiteKit

private func titles(_ hits: [QuickFindHit]) -> [String] {
    hits.map { hit in
        switch hit {
        case .task(let t): return "task:" + t.title
        case .tag(let g): return "tag:" + g.title
        case .view(let v): return "view:" + v.title
        }
    }
}

@Test func quickFindMatchesSubstringsInAnyCaseAcrossTasksTagsAndViews() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Квартальный отчёт"))
    _ = try store.createTask(NewTask(title: "Buy Milk"))
    _ = try store.createTag(title: "Отчётность")
    _ = try store.createView(NewTaskView(title: "Reports"))
    #expect(titles(try store.quickFind("ОТЧ")) == ["task:Квартальный отчёт", "tag:Отчётность"])
    #expect(titles(try store.quickFind("milk")) == ["task:Buy Milk"])
    #expect(titles(try store.quickFind("por")) == ["view:Reports"])
    #expect(try store.quickFind("zzz").isEmpty)
    #expect(try store.quickFind("   ").isEmpty)
}

@Test func shortQueriesFallBackToAScan() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Åsa calls"))
    _ = try store.createTag(title: "as-is")
    // Two characters: plain case folding, no diacritic folding, and the built-in views are searched like any
    // other view, so "Trash" answers "as" too.
    #expect(titles(try store.quickFind("as")) == ["tag:as-is", "view:Trash"])
    #expect(titles(try store.quickFind("ås")) == ["task:Åsa calls"])
}

@Test func diacriticsAreFoldedByTheIndex() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Café run"))
    #expect(titles(try store.quickFind("cafe")) == ["task:Café run"])
    _ = try store.createTask(NewTask(title: "n", notes: "Rendezvous at the café tomorrow"))
    #expect(try store.searchNotes("cafe").map(\.task.title) == ["n"])
}

@Test func quickFindHidesTrashedAndDeletedTasks() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "gone fishing"))
    let binned = try store.createTask(NewTask(title: "binned fishing"))
    _ = try store.createTask(NewTask(title: "still fishing"))
    try store.delete(task: gone)
    try store.trash(task: binned)
    #expect(titles(try store.quickFind("fishing")) == ["task:still fishing"])
}

@Test func searchNotesHidesTrashedAndDeletedTasks() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "gone", notes: "herring in the notes"))
    let binned = try store.createTask(NewTask(title: "binned", notes: "herring in the notes"))
    _ = try store.createTask(NewTask(title: "still", notes: "herring in the notes"))
    try store.delete(task: gone)
    try store.trash(task: binned)
    #expect(try store.searchNotes("herring").map(\.task.title) == ["still"])
}

@Test func indexFollowsRenamesAndNoteEdits() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "alpha"))
    try store.update(task: id, [.title("bravo"), .notes("charlie delta")])
    #expect(try store.quickFind("alpha").isEmpty)
    #expect(titles(try store.quickFind("bravo")) == ["task:bravo"])
    #expect(try store.searchNotes("charlie").map(\.task.id) == [id])
    try store.update(task: id, [.notes("echo")])
    #expect(try store.searchNotes("charlie").isEmpty)
}

@Test func notesSearchRanksPrefixesAndSnippets() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "a", notes: "Планирование спринта: планы, планёрка, ещё раз планирование."))
    _ = try store.createTask(NewTask(title: "b", notes: "Один план на неделю."))
    _ = try store.createTask(NewTask(title: "c", notes: "Ничего общего."))
    let hits = try store.searchNotes("план")
    #expect(hits.map(\.task.title) == ["a", "b"])
    #expect(hits[0].snippet.contains("[План") || hits[0].snippet.contains("[план"))
    #expect(hits[0].score <= hits[1].score, "bm25 is smaller for better matches")
    #expect(try store.searchNotes("планы спринт").map(\.task.title) == ["a"], "whole word plus a prefix on the last word")
    #expect(try store.searchNotes("").isEmpty)
}

@Test func queryEscapingTreatsOperatorsAndQuotesLiterally() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "say \"hi\" OR not", notes: "NOT a NEAR b AND \"quoted\""))
    #expect(titles(try store.quickFind("\"hi\" OR")) == ["task:say \"hi\" OR not"])
    #expect(try store.searchNotes("\"quoted\" AND").count == 1)
    #expect(try store.searchNotes("NOT").count == 1)
    #expect(Store.trigramQuery("ab") == nil)
    #expect(Store.trigramQuery(" a\"b\"c ") == "\"a\"\"b\"\"c\"")
    #expect(Store.wordsQuery("  один  два ") == "\"один\" \"два\"*")
    #expect(Store.wordsQuery(" ") == nil)
}

@Test func limitCapsEachSearch() throws {
    let store = try makeStore()
    for index in 0..<5 { _ = try store.createTask(NewTask(title: "chore \(index)", notes: "chore \(index)")) }
    #expect(try store.quickFind("chore", limit: 2).count == 2)
    #expect(try store.searchNotes("chore", limit: 2).count == 2)
    #expect(try store.quickFind("chore", limit: 0).isEmpty)
    #expect(try store.searchNotes("chore", limit: 0).isEmpty)
    // No room asked for is no room. A negative limit is a caller's slip, and `prefix` would trap on it while
    // SQLite would read it as no limit at all, so the two searches would disagree as loudly as they can.
    #expect(try store.quickFind("chore", limit: -1).isEmpty)
    #expect(try store.searchNotes("chore", limit: -1).isEmpty)
}

@Test func hitsOfEveryKindAreAlphabeticalByOneRule() throws {
    let store = try makeStore()
    for title in ["Ялта zzz", "август zzz", "Берлин zzz"] {
        _ = try store.createTask(NewTask(title: title))
        _ = try store.createTag(title: title)
    }
    let alphabetical = ["август zzz", "Берлин zzz", "Ялта zzz"]
    #expect(titles(try store.quickFind("zzz", limit: 50)) == alphabetical.map { "task:" + $0 } + alphabetical.map { "tag:" + $0 })
    // The order decides which rows the limit keeps, so a rule that folds only the Latin letters would drop
    // the title that comes first in the alphabet a person reads.
    #expect(titles(try store.quickFind("zzz", limit: 2)) == ["task:август zzz", "task:Берлин zzz"])
}

@Test func aLastWordEndingInPunctuationIsAWholeWord() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "cs", notes: "Learn C# and F#"))
    _ = try store.createTask(NewTask(title: "money", notes: "Costs 5% more"))
    _ = try store.createTask(NewTask(title: "cake", notes: "Bake a cake"))
    #expect(try store.searchNotes("C#").map(\.task.title) == ["cs"], "a star after a word the tokenizer ends at searches for every word beginning with c")
    #expect(Store.wordsQuery("C#") == "\"C#\"")
    #expect(Store.wordsQuery("план") == "\"план\"*")
}

@Test func aTitleIsFoundBySpellingItAsItIsWritten() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Buy  milk"))
    #expect(titles(try store.quickFind("buy  milk")) == ["task:Buy  milk"])
    #expect(titles(try store.quickFind("  buy  milk  ")) == ["task:Buy  milk"], "the ends are trimmed, the middle is what the index holds")
    #expect(try store.quickFind("buy milk").isEmpty, "a trigram match is literal: one space is not two")
}

@Test func deletedTagsAndViewsAndInheritedTrashStayOut() throws {
    let store = try makeStore()
    let tag = try store.createTag(title: "zebra tag")
    let view = try store.createView(NewTaskView(title: "zebra view"))
    let parent = try store.createTask(NewTask(title: "zebra parent", notes: "zebra in the notes"))
    _ = try store.createTask(NewTask(title: "zebra child", notes: "zebra in the notes", parent: parent))
    _ = try store.createTask(NewTask(title: "zebra loner", notes: "zebra in the notes"))
    try store.delete(tag: tag)
    try store.delete(view: view)
    try store.trash(task: parent)
    #expect(titles(try store.quickFind("zebra")) == ["task:zebra loner"])
    #expect(try store.searchNotes("zebra").map(\.task.title) == ["zebra loner"])
}

@Test func yoAndYeAreOneLetterToQuickFind() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Квартальный отчёт"))
    _ = try store.createTask(NewTask(title: "Годовой отчет"))
    _ = try store.createTag(title: "Отчётность")
    _ = try store.createView(NewTaskView(title: "Ёлки-палки"))
    // Issue #47: `ё` is the letter a person types as `е` and writes as `ё`, so a search spelled either way
    // answers the same. The fold is the index's, and the title keeps the spelling it was given.
    let both = ["task:Годовой отчет", "task:Квартальный отчёт", "tag:Отчётность"]
    #expect(titles(try store.quickFind("отчет")) == both)
    #expect(titles(try store.quickFind("отчёт")) == both)
    #expect(titles(try store.quickFind("ёлки")) == ["view:Ёлки-палки"])
    #expect(titles(try store.quickFind("елки")) == ["view:Ёлки-палки"])
}

@Test func yoAndYeAreOneLetterToTheNotesSearch() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "a", notes: "сдать отчёт вовремя"))
    _ = try store.createTask(NewTask(title: "b", notes: "черновик отчета"))
    #expect(Set(try store.searchNotes("отчет").map(\.task.title)) == ["a", "b"])
    #expect(Set(try store.searchNotes("отчёт").map(\.task.title)) == ["a", "b"])
}

@Test func shortQueriesFoldYoInTheScanAsWell() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Ёж"))
    // Under three characters the answer comes from the scan in Swift, and it folds the same letters as the
    // index, so the two paths do not disagree on the word a person is halfway through typing.
    #expect(titles(try store.quickFind("еж")) == ["task:Ёж"])
    #expect(titles(try store.quickFind("ёж")) == ["task:Ёж"])
}

@Test func aRenameKeepsTheFoldedIndexInStep() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "alpha", notes: "bravo"))
    try store.update(task: id, [.title("Ёлка"), .notes("под ёлкой")])
    #expect(titles(try store.quickFind("елка")) == ["task:Ёлка"])
    #expect(try store.searchNotes("елкой").map(\.task.id) == [id])
    #expect(try store.quickFind("alpha").isEmpty)
}

@Test func theFoldOfTheQueryIsTheFoldOfTheSchema() throws {
    let store = try makeStore()
    // `е` with a combining diaeresis is not `ё` to SQLite's `replace`, and Swift's `String.replacing` would
    // fold it anyway because it compares canonically. The two would then disagree about what the index
    // holds, so the fold walks unicode scalars.
    let written = "Ёж, ёлка, Е и е, е\u{0308}, Café"
    let id = try store.createTask(NewTask(title: written))
    let stored = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT title_fold FROM tasks WHERE id = ?", [.text(id.rawValue)])
    }
    #expect(Store.folded(written) == "Еж, елка, Е и е, е\u{0308}, Café")
    // Scalar by scalar, because `==` on two strings folds canonical equivalence away and this is the one
    // test where the difference between `ё` and `е` plus a mark is the whole point.
    #expect(stored.first?[0].string?.unicodeScalars.map(\.value) == Store.folded(written).unicodeScalars.map(\.value),
            "the column the index is built from and the fold the query uses are one rule")
    #expect(Store.trigramQuery(" Ёлка ") == "\"Елка\"")
    #expect(Store.wordsQuery("ёж и ёлка") == "\"еж\" \"и\" \"елка\"*")
}

@Test func theNotesSnippetShowsTheNoteAsItWasWritten() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "a", notes: "Сдать [квартальный] отчёт вовремя, а ещё позвонить."))
    let hit = try #require(try store.searchNotes("отчет").first)
    // The index holds a folded copy, so the snippet fts5 builds is folded too. What the person reads is
    // their own note: the window is cut out of the original text, and the brackets land where the index
    // put them.
    #expect(hit.snippet.contains("[отчёт]"))
    #expect(hit.snippet.contains("ещё"))
    #expect(hit.snippet.contains("[квартальный]"), "the square brackets of the note itself are not mistaken for the ones the search adds")
}

@Test func aLongNoteIsStillCutOutOfTheOriginal() throws {
    let store = try makeStore()
    let filler = String(repeating: "слово ", count: 40)
    _ = try store.createTask(NewTask(title: "a", notes: filler + "найти ёлку " + filler))
    let hit = try #require(try store.searchNotes("елку").first)
    #expect(hit.snippet.contains("[ёлку]"))
    #expect(hit.snippet.hasPrefix("…") && hit.snippet.hasSuffix("…"), "a window in the middle of a long note is elided on both sides")
}

@Test func aNoteThatHoldsTheMarksTheSearchUsesIsShownFolded() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "a", notes: "Сдать \u{1}отчёт\u{2} вовремя"))
    let hit = try #require(try store.searchNotes("отчет").first)
    // The marks are how fts5 says where the brackets belong, and a note that holds them itself — from a
    // person or from a peer, which is the same thing here — cannot be told apart from them. The folded
    // window is shown then, and never a window slid by a character or a mark passed on to the caller.
    #expect(hit.snippet == "Сдать [[отчет]] вовремя", "the note's own marks read back as brackets, and the window does not move")
    #expect(!hit.snippet.unicodeScalars.contains { $0.value < 0x20 })
}

@Test func aRenameAwayFromYoLeavesNothingBehindInTheIndex() throws {
    let store = try makeStore()
    let task = try store.createTask(NewTask(title: "Ёлка", notes: "под ёлкой"))
    let tag = try store.createTag(title: "Ёлочное")
    let view = try store.createView(NewTaskView(title: "Ёлочные дела"))
    try store.update(task: task, [.title("Сосна"), .notes("под сосной")])
    try store.update(tag: tag, [.title("Сосновое")])
    try store.update(view: view, [.title("Сосновые дела")])
    // The half of a trigger that deletes has to hand the index the same text the half that inserts gave it,
    // which is the folded copy. Handing it the original deletes nothing, and the old rows answer for ever:
    // `'integrity-check'` says nothing either, because an index with rows the content no longer has is
    // well formed to fts5.
    #expect(try store.quickFind("елоч").isEmpty)
    #expect(try store.searchNotes("елкой").isEmpty)
    #expect(titles(try store.quickFind("сосно")) == ["tag:Сосновое", "view:Сосновые дела"])
}
