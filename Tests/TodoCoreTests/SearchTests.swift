import Testing
@testable import TodoCore

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
