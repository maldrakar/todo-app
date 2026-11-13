// Sources/TodoCore/Query/TitleOrder.swift

/// The order of titles: by a key that is the title with its case folded in every script the standard library's
/// Unicode tables cover, `Ялта` with `ялта` as `Apple` with `apple` (#45). This is the one statement of that order. A
/// list sorted by title asks it of SQL by `sqlName`, quick find asks it of the tasks, tags and views it sorts in
/// Swift, the task list asks it of the chips on its tag bar, and the command line of a task's tags, so that a title
/// stands in the same place in each. Both sides compare keys by their UTF-8 bytes: SQLite does so in a database whose
/// text is UTF-8, which every file the store creates is, and `Key` does so in Swift, where `<` on strings compares the
/// composed form and would put a title spelled with a combining mark, as a name copied from the Finder is, somewhere
/// other than where SQL puts it. A file another program made in UTF-16 sorts every text column by UTF-16 bytes, this
/// key among them, and puts Cyrillic ahead of Latin in a list where Swift puts it after.
///
/// The key is computed by the read that orders by it and is never stored. A stored key would keep the fold of
/// whichever version of the app wrote it, and the standard library's tables move with its Unicode version, while a
/// key that is never stored has nothing to migrate and nothing a peer could send in its place. SQLite's own folds
/// cannot stand in for it: `NOCASE` and `lower()` fold the 26 letters of ASCII and nothing else, which is all SQLite
/// has without ICU (ADR-0001), and they sorted a Cyrillic title by its bytes, every capital ahead of every small
/// letter.
///
/// It takes case out of the comparison and nothing else. `ё` beside `е` and an order that is right per language are
/// collation, which needs ICU; `Store.folded`, which makes that pair one letter, is the search's and not this.
///
/// `package` and not `public`, like `trimmed()`: every caller is in this package.
package enum TitleOrder {
    /// The name `Store` defines `folded(_:)` under on its connection, which `FilterCompiler` orders by.
    static let sqlName = "title_key"

    /// The title with its case folded, which is the key: SQL is handed it as text and `Key` holds its bytes.
    static func folded(_ title: String) -> String { title.lowercased() }

    /// The key as Swift compares it, by its UTF-8 bytes. Each key copies them out once, which is cheaper for a sort
    /// than reading them through the text at every comparison: 50,000 Russian titles with their ids sort in 48 ms
    /// this way, against 82 compared as strings and 96 walking two `UTF8View`s (release).
    package struct Key: Comparable {
        private let bytes: [UInt8]

        fileprivate init(_ folded: String) { bytes = Array(folded.utf8) }

        package static func < (lhs: Key, rhs: Key) -> Bool { lhs.bytes.lexicographicallyPrecedes(rhs.bytes) }
    }

    /// The key a title is ordered by.
    package static func key(of title: String) -> Key { Key(folded(title)) }
}
