// Sources/TodoCore/Query/TitleOrder.swift

/// The order of titles: by a key that is the title with its case folded in every script the standard library's
/// Unicode tables cover, `Ялта` with `ялта` as `Apple` with `apple` (#45). This is the one statement of that order. A
/// list sorted by title asks it of SQL by `sqlName`, quick find asks it of the tasks, tags and views it sorts in
/// Swift, and the task list asks it of the chips on its tag bar, so that a title stands in the same place in each.
/// SQLite compares two keys by their bytes and Swift by `<`, and the two agree on text in the composed form a
/// keyboard types.
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
    /// The name `Store` defines `key(of:)` under on its connection, which `FilterCompiler` orders by.
    static let sqlName = "title_key"

    /// The key a title is ordered by.
    package static func key(of title: String) -> String { title.lowercased() }
}
