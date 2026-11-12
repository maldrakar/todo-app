import XCTest

/// A column's card carried within its column, across the board and over a column that takes none, and the board's own
/// scroll under it. Every walk starts on Project shown as Columns: its own column first, then Core, Design, Ops, Docs,
/// Either and Weekly.
final class ColumnWalks: Walk {
    override func setUpWithError() throws {
        try super.setUpWithError()
        openProject()
        setColumns()
    }

    /// A card let go over the next column lands in it, whether let go at once at the screen's edge, before the board
    /// scrolls, or held a moment over the column, and the store keeps it there: Own two and Own one into Core. Held,
    /// Core is tinted and ringed, which the accessibility tree does not hold and XCUITest cannot capture while its own
    /// press holds; `scripts/ui-walks.sh --record` records it for a person.
    func testDropIntoAColumn() {
        drag(at(row("Own two")), to: screen(0.92, 0.5), hold: 0.05)
        assertSameColumn("Own two", as: "Core 1", "Own two let go at once at the edge")
        drag(at(row("Own one")), to: screen(0.8, 0.5), hold: 3)
        assertSameColumn("Own one", as: "Core 1", "Own one held over Core")
        relaunch()
        openProject()
        assertProjectShowsColumns()
        assertSameColumn("Own two", as: "Core 1", "Own two in the store")
        assertSameColumn("Own one", as: "Core 1", "Own one in the store")
    }

    /// A card carried to the screen's edge and held a moment: the board scrolls a column on, the card is let go over
    /// that column and lands in it, and the board comes to rest on a column. The store keeps the card there.
    func testDropAcrossColumnsAsTheBoardScrolls() {
        let columns = ["Project", "Core", "Design", "Ops", "Docs", "Either", "Weekly"]
        let margin = header("Project").frame.minX
        drag(at(row("Own two")), to: screen(0.95, 0.5), hold: 0.45)
        settle(1.2)
        assertSameColumn("Own two", as: "Design one", "Own two let go as the board scrolled")
        XCTAssertTrue(
            columns.contains { abs(header($0).frame.minX - margin) <= 1 },
            "the board did not come to rest on a column: its headers stand at \(columns.map { header($0).frame.minX })"
        )
        relaunch()
        openProject()
        assertProjectShowsColumns()
        assertSameColumn("Own two", as: "Design one", "Own two in the store")
    }

    /// A card carried to the screen's very edge and held: the board scrolls to its end, and the card, let go past the
    /// last column, over "+ Add list", lands in the column nearest the point, the last one, Weekly, which the store
    /// keeps.
    func testHeldToTheEndOfTheBoard() {
        drag(at(row("Own two")), to: screen(0.5, 0.5).withOffset(CGVector(dx: 195, dy: 0)), hold: 3)
        settle(1.2)
        XCTAssertLessThanOrEqual(
            app.buttons["Add list"].firstMatch.frame.maxX, app.frame.width, "the board did not scroll to its end"
        )
        assertSameColumn("Own two", as: "Wk one", "Own two let go past the last column")
        relaunch()
        openProject()
        assertProjectShowsColumns()
        assertSameColumn("Own two", as: "Wk one", "Own two in the store")
    }

    /// A card let go at the screen's very edge a moment after it got there, where the drag can end with no drop at all:
    /// the card stays in its own column, there and once the board is swiped back to its start. The board may be left
    /// between two columns, a cost accepted in #177.
    func testReleaseAtTheVeryEdge() {
        let margin = header("Project").frame.minX
        drag(at(row("Own two")), to: screen(0.99, 0.5), hold: 0.2)
        settle(1.2)
        assertSameColumn("Own two", as: "Own one", "Own two let go at the very edge")
        app.swipeRight()
        settle(1)
        app.swipeRight()
        settle(1)
        XCTAssertEqual(header("Project").frame.minX, margin, accuracy: 1, "the board is not back at its start")
        assertSameColumn("Own two", as: "Own one", "Own two with the board back at its start")
    }

    /// A card held at the screen's foot over a column longer than the screen: the system scrolls that column under it,
    /// and the card, Core 3, let go there lands at the column's end, below Core 12, which the store keeps.
    func testColumnScrollsUnderAHeldCard() {
        app.swipeLeft()
        settle(1)
        let top = row("Core 1").frame.minY
        drag(at(row("Core 3")), to: screen(0.5, 0.985), hold: 2.5)
        XCTAssertLessThan(row("Core 1").frame.minY, top, "Core did not scroll under the held card")
        assertSameColumn("Core 3", as: "Core 12", "Core 3 let go at the foot")
        XCTAssertEqual(order(["Core 12", "Core 3"]), ["Core 12", "Core 3"], "Core 3 let go at the foot")
        relaunch()
        openProject()
        assertProjectShowsColumns()
        XCTAssertEqual(order(["Core 12", "Core 3"]), ["Core 12", "Core 3"], "the store kept Core's order")
    }

    /// A card let go over a column that takes no drop stays in its own, and the store keeps it there: Docs one over
    /// Either, whose rule, "either1" or "home", is a rule of alternatives that no one edit of a task satisfies
    /// (`docs/specs/list-screen.md`, section 6). Either draws no slot and no tint, which the accessibility tree does
    /// not hold; `scripts/ui-walks.sh --record` records them for a person.
    func testDropOverAColumnThatTakesNone() {
        let margin = header("Project").frame.minX
        board(to: "Docs", margin: margin)
        let docs = row("Docs one").frame.minX
        let release = screen(0.8, 0.5)
        XCTAssertGreaterThan(release.screenPoint.x, row("Docs one").frame.maxX, "the release is not past Docs's cards")
        drag(at(row("Docs one")), to: release, hold: 1)
        assertOnlyInDocs(at: docs, "Docs one let go over Either")
        relaunch()
        openProject()
        assertProjectShowsColumns()
        board(to: "Docs", margin: margin)
        assertOnlyInDocs(at: docs, "Docs one in the store")
    }

    // MARK: - Reading the board

    /// The board swiped a column at a time until `column`'s title stands at `margin`, where the first column's stood.
    private func board(to column: String, margin: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            let title = header(column)
            let offset = title.exists ? title.frame.minX - margin : .infinity
            if abs(offset) <= 1 { return }
            offset > 0 ? app.swipeLeft() : app.swipeRight()
            settle(1)
        }
        XCTFail("the board did not come to rest on \(column)", file: file, line: line)
    }

    /// Asserts that Docs one is drawn once, at `x`, where it stood in Docs's column: a drop Either took would have
    /// moved it into Either, or drawn it there too.
    private func assertOnlyInDocs(at x: CGFloat, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(
            rows("Docs one").count, 1, "\(what): it is drawn in more than one column", file: file, line: line
        )
        XCTAssertEqual(
            row("Docs one").frame.minX, x, accuracy: 1, "\(what): it left Docs's column", file: file, line: line
        )
    }

    /// Asserts that two cards stand in one column: the same left edge, within a point.
    private func assertSameColumn(
        _ card: String, as other: String, _ what: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(
            row(card).exists && row(other).exists, "\(what): \(card) or \(other) is not drawn", file: file, line: line
        )
        XCTAssertEqual(
            row(card).frame.minX, row(other).frame.minX, accuracy: 1,
            "\(what): it stands in another column than \(other)", file: file, line: line
        )
    }
}
