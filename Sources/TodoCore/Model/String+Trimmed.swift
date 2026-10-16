// Sources/TodoCore/Model/String+Trimmed.swift

extension String {
    /// The same text with the whitespace at either end gone, and the whitespace between words untouched.
    ///
    /// The one trim there is (`docs/style.md`, "One shape everywhere it fits"): the search trims a query with
    /// it, and a feature the title it is about to write, so that the space a keyboard adds after a word neither
    /// changes an answer nor ends up in a name. What is between the words is left alone, because it is part of
    /// the name: the trigram index holds a title byte for byte, so collapsing a run of spaces would make a title
    /// that holds one unreachable by the text a person reads on the screen. A title is trimmed by the feature
    /// that writes it and never by the store, which keeps the title it is given: what a title has to be is the
    /// client's policy (`docs/style.md`, "A lower layer holds no policy of its client").
    ///
    /// Both ends are walked with `while` loops and nothing recurses: a run of spaces in a title that arrived
    /// from sync is as data-shaped as a chain of parents (`docs/style.md`).
    public func trimmed() -> String {
        var text = Substring(self)
        while let first = text.first, first.isWhitespace { text.removeFirst() }
        while let last = text.last, last.isWhitespace { text.removeLast() }
        return String(text)
    }
}
