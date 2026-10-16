import Testing
import TodoCore

/// The ends go and the middle stays: the space a keyboard adds after a word is no part of a title or a query,
/// and a run of spaces between two words is part of both, since the trigram index holds a title byte for byte.
/// Whitespace is what `Character.isWhitespace` says it is, so a newline, a tab, the no-break space and the
/// ideographic space go too.
@Test func trimmingTakesTheWhitespaceAtTheEndsAndLeavesTheMiddle() {
    #expect("  Buy  milk \n".trimmed() == "Buy  milk")
    #expect("\t\u{00A0}Отчёт за год\u{3000}".trimmed() == "Отчёт за год")
    #expect("Buy milk".trimmed() == "Buy milk")
    #expect(" \n\t ".trimmed() == "", "nothing but whitespace trims to nothing, which is what empty means to a title")
    #expect("".trimmed() == "")
}
