// Sources/TodoCore/Query/TitleOrder.swift

/// The order of titles: by a key that is the title with its case folded in every script the standard library's
/// Unicode tables cover, `Ялта` with `ялта` as `Apple` with `apple` (#45). This is the one statement of that order. A
/// list sorted by title asks it of SQL by `sqlName`, quick find asks it of the tasks, tags and views it sorts in
/// Swift, the task list asks it of the chips on its tag bar, and the command line of a task's tags, so that a title
/// stands in the same place in each. Both sides compare keys by their UTF-8 bytes: SQLite does so with any text, and
/// `Key` does so in Swift, where `<` on strings compares the composed form and would put a title spelled with a
/// combining mark, as a name copied from the Finder is, somewhere other than where SQL puts it.
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
    /// The name `Store` defines the key's text under on its connection, which `FilterCompiler` orders by.
    static let sqlName = "title_key"

    /// A title's place in the order, equal to another and before it by the bytes of the folded title, as SQLite
    /// compares the same text.
    package struct Key: Comparable {
        /// The title with its case folded, which is what SQL is handed to order by.
        let text: String

        package static func < (lhs: Key, rhs: Key) -> Bool { lhs.text.utf8.lexicographicallyPrecedes(rhs.text.utf8) }

        package static func == (lhs: Key, rhs: Key) -> Bool { lhs.text.utf8.elementsEqual(rhs.text.utf8) }
    }

    /// The key a title is ordered by.
    package static func key(of title: String) -> Key { Key(text: title.lowercased()) }
}
