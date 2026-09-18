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

/// What quick find needs of a tag or a view: a title to match and to sort by, and an id to settle ties with.
/// Tasks are not among them — they are matched, hidden and ordered by the SQL that reads them, because the
/// trashed ones have to fall away before the limit is applied, and only the query knows the tree.
private protocol Titled {
    var id: EntityID { get }
    var title: String { get }
}

extension Tag: Titled {}
extension TaskView: Titled {}

extension Store {
    /// Substring search over the titles of tasks, tags and views, in that order and each alphabetically.
    /// Case and diacritics are folded by the trigram index, so `отч` finds `Отчёт` and `cafe` finds `Café`.
    /// Trashed and deleted tasks never appear; deleted tags and views are already gone from the reads below.
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
            hits += try loadTasks(
                where: "tt.trashed = 0 AND t.rid IN (SELECT rowid FROM tasks_title_fts WHERE tasks_title_fts MATCH ?)",
                [.text(match)], orderBy: Store.titleOrder, limit: limit
            ).map(QuickFindHit.task)
            let tagIDs = try titleMatches(in: "tags", index: "tags_title_fts", match)
            hits += Store.byTitle(try tags().filter { tagIDs.contains($0.id) }).map(QuickFindHit.tag)
            let viewIDs = try titleMatches(in: "views", index: "views_title_fts", match)
            hits += Store.byTitle(try views().filter { viewIDs.contains($0.id) }).map(QuickFindHit.view)
        } else {
            // Under three characters there is no trigram to look up, and the index cannot answer at all. The
            // titles are scanned in Swift instead, which folds case but not diacritics: `as` finds `as-is`
            // and only `ås` finds `Åsa`. Two characters into a search field is a prefix of the word a person
            // is still typing, so the answer is about to be replaced by the indexed one.
            let folded = needle.lowercased()
            func matches(_ title: String) -> Bool { title.lowercased().contains(folded) }
            hits += try loadTasks(where: "tt.trashed = 0", [], orderBy: Store.titleOrder)
                .filter { matches($0.title) }.prefix(limit).map(QuickFindHit.task)
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
        let byID = try tasks(ids: ranked.map { $0[0].string ?? "" })
        return ranked.compactMap { row in
            guard let task = byID[TaskID(row[0].string ?? "")] else { return nil }
            return NoteHit(task: task, snippet: row[1].string ?? "", score: row[2].double ?? 0)
        }
    }

    // MARK: - Query building

    /// The whole query as one trigram phrase, or nil when it is too short for the index to answer: FTS5
    /// indexes three characters at a time, so two of them match nothing rather than everything.
    static func trigramQuery(_ text: String) -> String? {
        let needle = normalized(text)
        guard needle.count >= 3 else { return nil }
        return quoted(needle)
    }

    /// One quoted word per word of the query, the last one as a prefix; nil when the query holds no word.
    static func wordsQuery(_ text: String) -> String? {
        var words = text.split(whereSeparator: \.isWhitespace).map { quoted(String($0)) }
        guard !words.isEmpty else { return nil }
        words[words.count - 1] += "*"
        return words.joined(separator: " ")
    }

    /// Runs of whitespace collapsed and the ends trimmed, so that a query keeps the shape a person typed it
    /// in without the trailing space that a keyboard adds.
    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// A string in FTS5 syntax: double quotes around it, inner quotes doubled. Everything inside is literal
    /// text, so `OR`, `NOT`, `NEAR` and the quotes a person typed are searched for and not obeyed.
    private static func quoted(_ text: String) -> String {
        "\"" + text.split(separator: "\"", omittingEmptySubsequences: false).joined(separator: "\"\"") + "\""
    }

    // MARK: - Reads shared by the two searches

    /// Alphabetical by title, with the id settling ties. `NOCASE` folds the ASCII letters only, which is what
    /// SQLite has without ICU (ADR-0001); a title it cannot fold sorts by its bytes, the same way everywhere.
    private static let titleOrder = "t.title COLLATE NOCASE, t.id"

    /// The ids whose title matched, out of one of the three trigram indexes. The table and index names are
    /// literals from the call sites above, and the query a person typed only ever reaches the parameter.
    private func titleMatches(in table: String, index: String, _ match: String) throws(StoreError) -> Set<EntityID> {
        try sql { () throws(SQLiteError) in
            let rows = try db.rows("SELECT id FROM \(table) WHERE rid IN (SELECT rowid FROM \(index) WHERE \(index) MATCH ?)", [.text(match)])
            return Set(rows.map { EntityID($0[0].string ?? "") })
        }
    }

    /// Whichever of the ids are still there, keyed by id, in the chunks SQLite's parameter limit allows.
    private func tasks(ids: [String]) throws(StoreError) -> [TaskID: TodoTask] {
        var byID: [TaskID: TodoTask] = [:]
        for chunk in Store.chunked(ids) {
            let loaded = try loadTasks(where: "t.id IN (\(Store.placeholders(chunk.count)))", chunk.map { .text($0) }, orderBy: "t.id")
            for task in loaded { byID[task.id] = task }
        }
        return byID
    }

    /// Tags or views alphabetically, the counterpart of `titleOrder` for the two reads that sort in Swift.
    /// Unlike `NOCASE` this folds the case of every alphabet, so a Cyrillic title sorts by its letters here
    /// and by its bytes in SQL — within one kind of hit the order is the one its own read gives.
    private static func byTitle<Item: Titled>(_ items: [Item]) -> [Item] {
        items.sorted { ($0.title.lowercased(), $0.id.rawValue) < ($1.title.lowercased(), $1.id.rawValue) }
    }
}
