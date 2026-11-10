import XCTest

/// Drops in the list's layout: a row lifted by a press that moves and let go within its block, in another block, or
/// where it takes no place.
final class DropWalks: Walk {
    /// A row let go over the lower half of a row lands below it, and over the upper half of one, above it.
    func testDropInsideABlock() {
        open("/view/" + Self.today)
        let titles = ["Alpha today", "Bravo today", "Charlie today", "Delta today"]
        drag(at(row("Alpha today")), to: at(row("Charlie today"), dy: 12))
        XCTAssertEqual(order(titles), ["Bravo today", "Charlie today", "Alpha today", "Delta today"])
        drag(at(row("Delta today")), to: at(row("Bravo today"), dy: -12))
        XCTAssertEqual(order(titles), ["Delta today", "Bravo today", "Charlie today", "Alpha today"])
        relaunch()
        open("/view/" + Self.today)
        XCTAssertEqual(order(titles), ["Delta today", "Bravo today", "Charlie today", "Alpha today"], "the store kept the order")
    }
}
