// Sources/TodoCore/Search/Store+Search.swift
import SQLiteKit

/// One answer of quick find. The three kinds travel in one list because the caller shows one list: a person
/// typing into the search field is looking for a thing by its name and does not yet know which kind it is.
public enum QuickFindHit: Equatable, Sendable {
    case task(TodoTask)
    case tag(Tag)
    case view(TaskView)
}

/// One answer of the notes search: the task, the piece of its notes that matched, and how well it matched.
public struct NoteHit: Equatable, Sendable {
    public let task: TodoTask
    /// A window of the notes with the matched words in square brackets, elided with `…` at the edges.
    public let snippet: String
    /// The bm25 score of the match. It is negative and smaller is better, which is the order the hits arrive
    /// in; it is carried out of the core because a caller that merges two searches has to rank across them.
    public let score: Double
}

/// What quick find needs of a hit before it reads the whole thing: a title to order by and an id to settle
/// ties with. Every kind of hit goes through one sort, so a task, a tag and a view in the same answer are in
/// one order rather than in the order each of their reads happened to give.
private protocol Titled {
    var id: EntityID { get }
    var title: String { get }
}

extension Tag: Titled {}
extension TaskView: Titled {}

/// A task as the sort sees it. Tasks are the one kind quick find does not read whole before ordering: there
/// can be fifty thousand of them, and only the handful that survive the limit are worth assembling with
/// their tags.
private struct TitleRow: Titled {
    let id: EntityID
    let title: String
}

extension Store {
    /// Substring search over the titles of tasks, tags and views, in that order and each alphabetically.
    /// Case and diacritics are folded by the trigram index, so `отч` finds `Отчёт` and `cafe` finds `Café`;
    /// what SQLite folds is what the index was built with, and to it `ё` is a letter of its own, not an `е`
    /// with a mark. Trashed and deleted tasks never appear, and so do deleted tags and views.
    ///
    /// `limit` counts hits of all three kinds together, so a query that matches many tasks can push the tags
    /// and views out of the answer. That is the order the caller shows them in, and a caller that wants all
    /// of one kind asks for more room rather than for a different shape. A limit of zero or less asks for no
    /// room and gets nothing, here and in `searchNotes`.
    public func quickFind(_ query: String, limit: Int = 20) throws(StoreError) -> [QuickFindHit] {
        let needle = Store.normalized(query)
        guard limit > 0, !needle.isEmpty else { return [] }
        var hits: [QuickFindHit] = []
        if let match = Store.trigramQuery(needle) {
            let matched = try titleRows(where: "t.rid IN (SELECT rowid FROM tasks_title_fts WHERE tasks_title_fts MATCH ?)", [.text(match)])
            hits += try taskHits(matched, limit: limit)
            let tagIDs = try titleMatches(in: "tags", match)
            hits += Store.byTitle(try tags().filter { tagIDs.contains($0.id) }).map(QuickFindHit.tag)
            let viewIDs = try titleMatches(in: "views", match)
            hits += Store.byTitle(try views().filter { viewIDs.contains($0.id) }).map(QuickFindHit.view)
        } else {
            // Under three characters there is no trigram to look up, and the index cannot answer at all. The
            // titles are scanned in Swift instead, which folds case but not diacritics: `as` finds `as-is`
            // and only `ås` finds `Åsa`. Two characters into a search field is a prefix of the word a person
            // is still typing, so the answer is about to be replaced by the indexed one.
            let folded = needle.lowercased()
            func matches(_ title: String) -> Bool { title.lowercased().contains(folded) }
            hits += try taskHits(try titleRows(where: "1", []).filter { matches($0.title) }, limit: limit)
            hits += Store.byTitle(try tags().filter { matches($0.title) }).map(QuickFindHit.tag)
            hits += Store.byTitle(try views().filter { matches($0.title) }).map(QuickFindHit.view)
        }
        return Array(hits.prefix(limit))
    }

    /// Word search over the notes of tasks, best match first. Every word but the last must be there in full;
    /// the last is a prefix, because it is the word the person is still typing. Trashed and deleted tasks are
    /// hidden here as everywhere else.
    public func searchNotes(_ query: String, limit: Int = 20) throws(StoreError) -> [NoteHit] {
        guard limit > 0, let match = Store.wordsQuery(query) else { return [] }
        // `snippet` brackets the matched words inside a window of twelve tokens. `bm25` is negative and
        // smaller for a better match, so plain ascending order puts the best first, and the id settles ties
        // so that two devices with the same notes answer in the same order.
        let ranked = try sql { () throws(SQLiteError) in
            try db.rows("""
                SELECT t.id, snippet(tasks_notes_fts, 0, '[', ']', '…', 12), bm25(tasks_notes_fts)
                FROM tasks_notes_fts
                JOIN tasks t ON t.rid = tasks_notes_fts.rowid
                JOIN task_tree tt ON tt.id = t.id
                WHERE tasks_notes_fts MATCH ? AND t.deleted = 0 AND tt.trashed = 0
                ORDER BY bm25(tasks_notes_fts), t.id
                LIMIT ?
                """, [.text(match), .integer(Int64(limit))])
        }
        // The ranked read gives the rows of the index; the tasks themselves come from the one loader that
        // knows how to assemble a task with its tags, and the rank order above is what the hits keep.
        let byID = try tasksByID(ranked.map { $0[0].string ?? "" })
        return ranked.compactMap { row in
            guard let task = byID[TaskID(row[0].string ?? "")] else { return nil }
            return NoteHit(task: task, snippet: row[1].string ?? "", score: row[2].double ?? 0)
        }
    }

    // MARK: - Query building

    /// The whole query as one trigram phrase, or nil when it is too short for the index to answer: FTS5
    /// indexes three characters at a time, so two of them match nothing rather than everything. It normalizes
    /// what it is given, because it is also the door the tests knock on, and normalizing twice changes
    /// nothing. Internal rather than private for those tests, and for nobody else.
    static func trigramQuery(_ text: String) -> String? {
        let needle = normalized(text)
        guard needle.count >= 3 else { return nil }
        return quoted(needle)
    }

    /// One quoted word per word of the query, and a prefix star on the last of them when it ends in a letter
    /// or a digit — the shape of a word still being typed. A last word that ends in anything else is finished
    /// by the punctuation that ends it: `C#` tokenizes to `c`, and a star there would search for every word
    /// that begins with a `c` and rank the notes that never mentioned `C#` above the one that did. Nil when
    /// the query holds no word. Internal for the tests, like `trigramQuery`.
    static func wordsQuery(_ text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard let last = words.last?.last else { return nil }
        var parts = words.map { quoted(String($0)) }
        if last.isLetter || last.isNumber { parts[parts.count - 1] += "*" }
        return parts.joined(separator: " ")
    }

    /// The ends trimmed, so that the space a keyboard adds after a word does not change the answer. What is
    /// between the words is left alone: the trigram index holds a title byte for byte, so collapsing a run of
    /// spaces here would make a title that holds one unreachable by the text a person reads on the screen.
    private static func normalized(_ text: String) -> String {
        var trimmed = Substring(text)
        while let first = trimmed.first, first.isWhitespace { trimmed.removeFirst() }
        while let last = trimmed.last, last.isWhitespace { trimmed.removeLast() }
        return String(trimmed)
    }

    /// A string in FTS5 syntax: double quotes around it, inner quotes doubled. Everything inside is literal
    /// text, so `OR`, `NOT`, `NEAR` and the quotes a person typed are searched for and not obeyed.
    private static func quoted(_ text: String) -> String {
        "\"" + text.replacing("\"", with: "\"\"") + "\""
    }

    // MARK: - Reads behind quick find

    /// The id and title of the tasks a clause selects, with the deleted and the trashed already out —
    /// inherited trash included, which is what the join on the tree is for. Two columns rather than whole
    /// tasks: the scan under three characters reads every visible row here, and a task read whole brings its
    /// tags with it, one more statement per five hundred rows for tasks the answer is about to drop.
    private func titleRows(where clause: String, _ params: [Value]) throws(StoreError) -> [TitleRow] {
        try sql { () throws(SQLiteError) in
            let rows = try db.rows("SELECT t.id, t.title FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND tt.trashed = 0 AND (\(clause))", params)
            return rows.map { TitleRow(id: EntityID($0[0].string ?? ""), title: $0[1].string ?? "") }
        }
    }

    /// The best `limit` of those rows, read whole and in the order the titles put them in. The order has to
    /// be decided before the cut, and it cannot be `ORDER BY ... COLLATE NOCASE` in the statement above:
    /// `NOCASE` folds the ASCII letters and nothing else, which is all SQLite has without ICU (ADR-0001), so
    /// a Cyrillic title would sort by its bytes — every capital before every lowercase — and a limit would
    /// drop the title that comes first in the alphabet a person actually reads.
    private func taskHits(_ rows: [TitleRow], limit: Int) throws(StoreError) -> [QuickFindHit] {
        let chosen = Store.byTitle(rows).prefix(limit)
        let byID = try tasksByID(chosen.map(\.id.rawValue))
        return chosen.compactMap { byID[$0.id].map(QuickFindHit.task) }
    }

    /// The ids whose title matched, out of one of the three trigram indexes. The schema names every one of
    /// them after its table, so the caller names the table alone and cannot pair it with the wrong index; the
    /// name reaching the statement is a literal from a call site above, and the query a person typed only
    /// ever reaches the parameter.
    private func titleMatches(in table: String, _ match: String) throws(StoreError) -> Set<EntityID> {
        let index = "\(table)_title_fts"
        return try sql { () throws(SQLiteError) in
            let rows = try db.rows("SELECT id FROM \(table) WHERE rid IN (SELECT rowid FROM \(index) WHERE \(index) MATCH ?)", [.text(match)])
            return Set(rows.map { EntityID($0[0].string ?? "") })
        }
    }

    /// Whichever of the ids are still there, keyed by id, in the chunks SQLite's parameter limit allows.
    private func tasksByID(_ ids: [String]) throws(StoreError) -> [TaskID: TodoTask] {
        var byID: [TaskID: TodoTask] = [:]
        for chunk in Store.chunked(ids) {
            let loaded = try loadTasks(where: "t.id IN (\(Store.placeholders(chunk.count)))", chunk.map { .text($0) }, orderBy: "t.id")
            for task in loaded { byID[task.id] = task }
        }
        return byID
    }

    /// Alphabetical by title, with the id settling ties, for every kind of hit. `lowercased` folds the case
    /// of every alphabet the standard library knows, which is what makes one order out of a read in SQL and
    /// a read in Swift.
    ///
    /// Each title is folded once, before the sort, and not inside the comparison: a trigram that matches
    /// fifty thousand titles is compared some seventeen times per row, and a fold in there is two strings
    /// allocated per comparison — 130 ms of a search that takes 17 ms this way.
    private static func byTitle<Item: Titled>(_ items: [Item]) -> [Item] {
        items.map { (key: $0.title.lowercased(), id: $0.id.rawValue, item: $0) }
            .sorted { ($0.key, $0.id) < ($1.key, $1.id) }
            .map(\.item)
    }
}
