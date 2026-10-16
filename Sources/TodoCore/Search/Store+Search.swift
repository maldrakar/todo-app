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
    /// A window of the notes with the matched words in square brackets, elided with `…` at the edges, in the
    /// spelling the note holds and not the one the index searched.
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
    /// Case and diacritics are folded by the trigram index, so `отч` finds `Отчёт` and `cafe` finds `Café`,
    /// and `ё` and `е` are one letter to it because the index is built over a copy in which they are one
    /// (`Schema.version3`). Trashed and deleted tasks never appear, and so do deleted tags and views.
    ///
    /// `limit` counts hits of all three kinds together, so a query that matches many tasks can push the tags
    /// and views out of the answer. That is the order the caller shows them in, and a caller that wants all
    /// of one kind asks for more room rather than for a different shape. A limit of zero or less asks for no
    /// room and gets nothing, here and in `searchNotes`.
    public func quickFind(_ query: String, limit: Int = 20) throws(StoreError) -> [QuickFindHit] {
        let needle = query.trimmed()
        guard limit > 0, !needle.isEmpty else { return [] }
        var hits: [QuickFindHit] = []
        if let match = Store.trigramQuery(needle) {
            let matched = try titleRows(matching: "t.rid IN (SELECT rowid FROM tasks_title_fts WHERE tasks_title_fts MATCH ?)", [.text(match)])
            hits += try taskHits(matched, limit: limit)
            let tagIDs = try titleMatches(in: "tags", match)
            hits += Store.byTitle(try tags().filter { tagIDs.contains($0.id) }).map(QuickFindHit.tag)
            let viewIDs = try titleMatches(in: "views", match)
            hits += Store.byTitle(try views().filter { viewIDs.contains($0.id) }).map(QuickFindHit.view)
        } else {
            // Under three characters there is no trigram to look up, and the index cannot answer at all. The
            // titles are scanned in Swift instead, which folds case and the one pair the index folds, but no
            // diacritics: `as` finds `as-is`, `еж` finds `Ёж`, and only `ås` finds `Åsa`. Two characters into
            // a search field is a prefix of the word a person is still typing, so the answer is about to be
            // replaced by the indexed one.
            let wanted = Store.folded(needle).lowercased()
            func matches(_ title: String) -> Bool { Store.folded(title).lowercased().contains(wanted) }
            hits += try taskHits(try titleRows().filter { matches($0.title) }, limit: limit)
            hits += Store.byTitle(try tags().filter { matches($0.title) }).map(QuickFindHit.tag)
            hits += Store.byTitle(try views().filter { matches($0.title) }).map(QuickFindHit.view)
        }
        return Array(hits.prefix(limit))
    }

    /// Word search over the notes of tasks, best match first. Every word but the last must be there in full;
    /// the last is a prefix, because it is the word the person is still typing. Case, the diacritics SQLite's
    /// own tables cover and the pair `е`/`ё` are folded by the index, as they are in `quickFind`. Trashed and
    /// deleted tasks are hidden here as everywhere else.
    public func searchNotes(_ query: String, limit: Int = 20) throws(StoreError) -> [NoteHit] {
        guard limit > 0, let match = Store.wordsQuery(query) else { return [] }
        // `snippet` brackets the matched words inside a window of twelve tokens, and it speaks the text the
        // index holds, which is the folded copy (`Schema.version3`). It is asked twice: once with marks that
        // say where the brackets and the elisions go, and once with no marks at all, which is that same
        // window as plain text. `instr` finds the plain window in the folded copy and `substr` cuts the same
        // span out of the notes themselves — the fold replaces one character with one character, so the two
        // are measured in the same positions — and what crosses into Swift is that cut and not the notes,
        // which the spec allows to be megabytes. SQLite still reads the note to do it, and folds a copy of it
        // to search, as `snippet()` already read it before this; what the copy costs is freed with the row.
        //
        // `bm25` is negative and smaller for a better match, so plain ascending order puts the best first,
        // and the id settles ties so that two devices with the same notes answer in the same order. The
        // hits are materialized before the cut so that the window is chosen once per hit and not per
        // mention of it.
        let ranked = try sql { () throws(SQLiteError) in
            try db.rows("""
                WITH hit AS MATERIALIZED (
                    SELECT t.rid AS rid, t.id AS id, bm25(tasks_notes_fts) AS score,
                           snippet(tasks_notes_fts, 0, char(1), char(2), char(3), 12) AS marked,
                           snippet(tasks_notes_fts, 0, '', '', '', 12) AS plain
                    FROM tasks_notes_fts
                    JOIN tasks t ON t.rid = tasks_notes_fts.rowid
                    JOIN task_tree tt ON tt.id = t.id
                    WHERE tasks_notes_fts MATCH ? AND t.deleted = 0 AND tt.trashed = 0
                    ORDER BY bm25(tasks_notes_fts), t.id
                    LIMIT ?
                )
                SELECT hit.id, hit.marked, hit.score,
                       substr(t.notes, instr(t.notes_fold, hit.plain), length(hit.plain))
                FROM hit JOIN tasks t ON t.rid = hit.rid
                ORDER BY hit.score, hit.id
                """, [.text(match), .integer(Int64(limit))])
        }
        // The ranked read gives the rows of the index; the tasks themselves come from the one loader that
        // knows how to assemble a task with its tags, and the rank order above is what the hits keep.
        let byID = try tasksByID(ranked.map { $0[0].string ?? "" })
        return ranked.compactMap { row in
            guard let task = byID[TaskID(row[0].string ?? "")] else { return nil }
            let snippet = Store.snippet(marked: row[1].string ?? "", cutFrom: row[3].string ?? "")
            return NoteHit(task: task, snippet: snippet, score: row[2].double ?? 0)
        }
    }

    // MARK: - Query building

    /// The pair the index folds and SQLite does not: `ё` is written where `е` is typed and typed where `е` is
    /// written. The index holds a copy of every title and every note with the pair collapsed
    /// (`Schema.version3`), so a query is collapsed the same way before it is asked.
    ///
    /// It walks unicode scalars because the column it mirrors is written with `replace`, which does the same:
    /// Swift compares strings by canonical equivalence, so `text.replacing("ё", with: "е")` would also fold an
    /// `е` that carries a combining diaeresis, and the query would then look for something the index does not
    /// hold. One scalar for one scalar also keeps every position in the text where it was, which is what lets
    /// `searchNotes` cut a window out of the notes by a position measured in the copy. Internal for the tests
    /// that hold it to the schema, and for nobody else.
    static func folded(_ text: String) -> String {
        // A text without the pair is its own fold, and the scan under three characters asks this of every
        // title in the database.
        guard text.unicodeScalars.contains(where: { $0 != foldedScalar($0) }) else { return text }
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars { scalars.append(foldedScalar(scalar)) }
        return String(scalars)
    }

    private static func foldedScalar(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        switch scalar {
        case "ё": "е"
        case "Ё": "Е"
        default: scalar
        }
    }

    /// The whole query as one trigram phrase, or nil when it is too short for the index to answer: FTS5
    /// indexes three characters at a time, so two of them match nothing rather than everything. It trims what
    /// it is given, because it is also the door the tests knock on, and trimming twice changes nothing.
    /// Internal rather than private for those tests, and for nobody else.
    static func trigramQuery(_ text: String) -> String? {
        let needle = text.trimmed()
        guard needle.count >= 3 else { return nil }
        return quoted(folded(needle))
    }

    /// One quoted word per word of the query, and a prefix star on the last of them when it ends in a letter
    /// or a digit — the shape of a word still being typed. A last word that ends in anything else is finished
    /// by the punctuation that ends it: `C#` tokenizes to `c`, and a star there would search for every word
    /// that begins with a `c` and rank the notes that never mentioned `C#` above the one that did. Nil when
    /// the query holds no word. Internal for the tests, like `trigramQuery`.
    static func wordsQuery(_ text: String) -> String? {
        let words = folded(text).split(whereSeparator: \.isWhitespace)
        guard let last = words.last?.last else { return nil }
        var parts = words.map { quoted(String($0)) }
        if last.isLetter || last.isNumber { parts[parts.count - 1] += "*" }
        return parts.joined(separator: " ")
    }

    /// Characters no note is expected to hold, so that what fts5 added to the window can be told apart from
    /// what the person wrote there — square brackets in a note are their own, and the search does not read
    /// them as its own marks.
    private static let openMark: Unicode.Scalar = "\u{1}"
    private static let closeMark: Unicode.Scalar = "\u{2}"
    private static let elisionMark: Unicode.Scalar = "\u{3}"
    private static let marks: Set<Unicode.Scalar> = [openMark, closeMark, elisionMark]

    /// The window a person reads: the marks fts5 left become the brackets and the ellipsis, and every other
    /// character comes from `window`, which is that same span of the notes in the spelling they were written.
    ///
    /// The two are the same length unless the notes hold the marks above themselves, in which case the span
    /// was cut at the wrong place or not at all; the folded text is shown then, which is what the search
    /// answered before it learned to cut, rather than a window slid by a character. Such a note also reads
    /// its own marks back as brackets, since nothing tells them from the ones fts5 added — a note can print
    /// a highlight the search did not make, and that is all it can do.
    private static func snippet(marked: String, cutFrom window: String) -> String {
        let unmarked = Array(marked.unicodeScalars.filter { !marks.contains($0) })
        let original = Array(window.unicodeScalars)
        let source = original.count == unmarked.count ? original : unmarked
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(marked.unicodeScalars.count)
        var index = 0
        for scalar in marked.unicodeScalars {
            switch scalar {
            case openMark: scalars.append("[")
            case closeMark: scalars.append("]")
            case elisionMark: scalars.append("…")
            default:
                scalars.append(source[index])
                index += 1
            }
        }
        return String(scalars)
    }

    /// A string in FTS5 syntax: double quotes around it, inner quotes doubled. Everything inside is literal
    /// text, so `OR`, `NOT`, `NEAR` and the quotes a person typed are searched for and not obeyed.
    private static func quoted(_ text: String) -> String {
        "\"" + text.replacing("\"", with: "\"\"") + "\""
    }

    // MARK: - Reads behind quick find

    /// The id and title of every task a person can see — the deleted and the trashed are out, inherited
    /// trash included, which is what the join on the tree is for. Without a clause that is the whole visible
    /// table, which is what the scan under three characters reads; with one it is the tasks the clause
    /// selects, and the scan's `?` parameters go in beside it.
    ///
    /// Two columns rather than whole tasks: a task read whole brings its tags with it, one more statement per
    /// five hundred rows, and the answer is about to drop all but a page of them.
    private func titleRows(matching clause: String? = nil, _ params: [Value] = []) throws(StoreError) -> [TitleRow] {
        let selection = clause.map { " AND (\($0))" } ?? ""
        return try sql { () throws(SQLiteError) in
            let rows = try db.rows("SELECT t.id, t.title FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND tt.trashed = 0\(selection)", params)
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
