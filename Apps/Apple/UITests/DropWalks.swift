import XCTest

/// Drops in the list's layout: a row lifted by a press that moves and let go within its block, in another block, or
/// where it takes no place.
final class DropWalks: Walk {
    /// Today's first four rows, in the seeded order.
    private let todaysFirst = ["Alpha today", "Bravo today", "Charlie today", "Delta today"]

    /// A row let go over the lower half of a row lands below it, and over the upper half of one, above it.
    func testDropInsideABlock() {
        open("/view/" + Self.today)
        drag(at(row("Alpha today")), to: at(row("Charlie today"), dy: 12))
        XCTAssertEqual(order(todaysFirst), ["Bravo today", "Charlie today", "Alpha today", "Delta today"])
        drag(at(row("Delta today")), to: at(row("Bravo today"), dy: -12))
        let moved = ["Delta today", "Bravo today", "Charlie today", "Alpha today"]
        XCTAssertEqual(order(todaysFirst), moved)
        relaunch()
        open("/view/" + Self.today)
        XCTAssertEqual(order(todaysFirst), moved, "the store kept the order")
    }

    /// A row let go over the place it was lifted from moves nothing and opens no menu: Bravo let go in Charlie's upper
    /// half, which is where Bravo stands.
    func testDropBackOverTheSource() {
        open("/view/" + Self.today)
        drag(at(row("Bravo today")), to: at(row("Charlie today"), dy: -10))
        XCTAssertEqual(order(todaysFirst), todaysFirst, "a row let go over its own place moved")
        XCTAssertFalse(app.buttons["Delete"].exists, "a hold that ended in a drag opened the menu")
    }

    /// A row let go outside the list, over the status bar, moves nothing, and a tap after it opens a card as before.
    /// Whether the lifted row is left dimmed is not in the accessibility tree; `scripts/ui-walks.sh --record` shows it.
    func testReleaseOutside() {
        open("/view/" + Self.today)
        drag(at(row("Bravo today")), to: screen(0.5, 0.012), hold: 0.6)
        settle(1)
        XCTAssertEqual(order(todaysFirst), todaysFirst, "a row let go outside the list moved")
        row("Charlie today").tap()
        XCTAssertTrue(
            titleField("Charlie today").waitForExistence(timeout: 3), "a tap after the release opened no card"
        )
    }

    /// A row let go in another block lands in it, under that block's header and above the next one's, and the store
    /// keeps it there: Own one held over Core's rows. Then a row of Core held within Core lands where it was let go.
    /// Held, Core is tinted and ringed while Own one is over it, and a line marks Core 1's place within it; neither is
    /// in the accessibility tree, and XCUITest takes no screenshot while its own press holds, so
    /// `scripts/ui-walks.sh --record` records them for a person.
    func testDropIntoAnotherBlock() {
        openProject()
        drag(at(row("Own one")), to: at(row("Core 3")), hold: 3)
        assertStands(row("Own one"), in: "Core", above: "Design", "Own one after its drop over Core 3")
        let core = (1...5).map { "Core \($0)" }
        drag(at(row("Core 1")), to: at(row("Core 4"), dy: 12), hold: 3)
        let moved = ["Core 2", "Core 3", "Core 4", "Core 1", "Core 5"]
        XCTAssertEqual(order(core), moved, "Core 1 let go in Core 4's lower half")
        relaunch()
        openProject()
        assertStands(row("Own one"), in: "Core", above: "Design", "Own one in the store")
        XCTAssertEqual(order(core), moved, "the store kept Core's order")
    }

    /// A task two blocks draw, Both one in Design and in Ops, dragged from Design into Docs: it leaves Design, stays in
    /// Ops and joins Docs, and the store keeps it so.
    func testATaskTwoBlocksDraw() {
        openProject()
        scroll(header("Design"), toY: 140)
        let before = rows("Both one")
        XCTAssertEqual(before.count, 2, "Both one is drawn in Design and in Ops")
        assertStands(before[0], in: "Design", above: "Ops", "the first Both one")
        assertStands(before[1], in: "Ops", above: "Docs", "the second Both one")
        XCTAssertGreaterThan(before[0].frame.minY, 150, "the row stands clear of the auto-scroll at the list's top")
        drag(at(before[0]), to: at(row("Docs one")))
        assertInOpsAndDocs("after the drop")
        relaunch()
        openProject()
        scroll(header("Design"), toY: 140)
        assertInOpsAndDocs("in the store")
    }

    /// A block that takes no drop, Either, whose rule is a choice of tags: Docs one let go over its rows stays where it
    /// was, and the drag after it lands under Ops' header. Whether anything stays dimmed is not in the accessibility
    /// tree; `scripts/ui-walks.sh --record` shows it.
    func testABlockThatTakesNoDrop() {
        openProject()
        scroll(header("Ops"), toY: 180)
        let y = row("Docs one").frame.minY
        drag(at(row("Docs one")), to: at(row("Either one")), hold: 1)
        XCTAssertEqual(row("Docs one").frame.minY, y, accuracy: 1, "Docs one moved when let go over Either")
        assertStands(row("Docs one"), in: "Docs", above: "Either", "Docs one after its release over Either")
        drag(at(row("Docs one")), to: at(row("Ops one")))
        assertStands(row("Docs one"), in: "Ops", above: "Docs", "Docs one after its drop over Ops one")
    }

    /// A row let go on a folded block's header lands in that block, which stays folded, and the store keeps both:
    /// Own one on Core's header, read where Core is unfolded after the app is launched again.
    func testDropIntoAFoldedBlock() {
        openProject()
        app.buttons["Fold Core"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Unfold Core"].waitForExistence(timeout: 2), "Core's chevron did not fold it")
        XCTAssertFalse(row("Core 1").exists, "folded, Core still draws its rows")
        drag(at(row("Own one")), to: at(header("Core")))
        XCTAssertFalse(row("Own one").exists, "Own one did not leave Project's own block for the folded Core")
        XCTAssertFalse(row("Core 1").exists, "the drop unfolded Core")
        relaunch()
        openProject()
        XCTAssertFalse(row("Own one").exists, "the store has Own one back in Project's own block")
        XCTAssertTrue(app.buttons["Unfold Core"].exists, "the store lost Core's fold")
        app.buttons["Unfold Core"].firstMatch.tap()
        settle()
        assertStands(row("Own one"), in: "Core", above: "Design", "Own one in the store, Core unfolded")
    }

    /// A row carried past the screen's foot: the system scrolls the list under it to the end, and the row lands there,
    /// let go 25 points above the screen's foot, inside the home indicator's inset; then another let go 13 points above
    /// it lands at the end too.
    func testAutoScroll() {
        open("/view/" + Self.today)
        drag(at(row("Alpha today")), to: screen(0.5, 0.971), hold: 2.5)
        XCTAssertLessThan(
            row("Filler 14").frame.maxY, app.frame.height, "the list did not scroll to its end under the held row"
        )
        XCTAssertEqual(
            order(["Filler 14", "Alpha today"]), ["Filler 14", "Alpha today"], "Alpha let go 25 above the foot"
        )
        drag(at(row("Filler 14")), to: screen(0.5, 0.985), hold: 1)
        let end = ["Filler 13", "Alpha today", "Filler 14"]
        XCTAssertEqual(order(end), end, "Filler 14 let go 13 above the foot")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertEqual(order(end), end, "the store kept the order")
    }

    /// A row lifted and let go while a card's title is being typed: it lands, and the keyboard stays up through the
    /// drag.
    func testLiftWithTheKeyboardUp() {
        open("/view/" + Self.today)
        openCard("Echo today")
        titleField("Echo today").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "the keyboard is not up before the lift")
        drag(at(row("Alpha today")), to: at(row("Charlie today"), dy: 12))
        XCTAssertEqual(
            order(["Alpha today", "Bravo today", "Charlie today"]), ["Bravo today", "Charlie today", "Alpha today"]
        )
        XCTAssertGreaterThan(app.keyboards.count, 0, "the keyboard went down during the drag")
    }

    /// A list inside that groups, Weekly by day, takes no reorder of its rows: Wk three let go in Wk two's upper half
    /// (the same day) and Wk one in Wk three's lower half (another day) move nothing. Let go over Core's last row, Wk
    /// three lands in Core, and the store keeps it there. Design, Ops, Docs and Either are folded first, so that Core's
    /// end and Weekly, the last list inside Project, stand on one screen.
    func testGroupedList() {
        openProject()
        scroll(header("Design"), toY: 350)
        for list in ["Design", "Ops", "Docs", "Either"] {
            app.buttons["Fold " + list].firstMatch.tap()
            XCTAssertTrue(
                app.buttons["Unfold " + list].waitForExistence(timeout: 2), "\(list)'s chevron did not fold it"
            )
        }
        let weekly = ["Wk one", "Wk two", "Wk three"]
        drag(at(row("Wk three")), to: at(row("Wk two"), dy: -14), hold: 3)
        XCTAssertEqual(order(weekly), weekly, "Wk three let go in Wk two's upper half, the same day, moved")
        drag(at(row("Wk one")), to: at(row("Wk three"), dy: 14), hold: 0.6)
        XCTAssertEqual(order(weekly), weekly, "Wk one let go in Wk three's lower half, another day, moved")
        drag(at(row("Wk three")), to: at(row("Core 12")), hold: 3)
        for _ in 0..<3 { app.swipeDown(velocity: .fast) }
        settle(1)
        assertStands(row("Wk three"), in: "Core", above: "Design", "Wk three after its drop over Core 12")
        relaunch()
        openProject()
        assertStands(row("Wk three"), in: "Core", above: "Design", "Wk three in the store")
    }

    /// A row let go over a block that shows only its "+ Add task", Project's own block once its two tasks are deleted,
    /// lands in that block, above the "Add task" row, and the store keeps it there: Core 1 held over the right half of
    /// the screen at that row's height. Held, the block is tinted, which the accessibility tree does not hold;
    /// `scripts/ui-walks.sh --record` records it.
    func testDropIntoAnEmptyOwnBlock() {
        openProject()
        for title in ["Own one", "Own two"] {
            row(title).swipeLeft()
            XCTAssertTrue(
                delete(of: title).waitForExistence(timeout: 2), "the swipe on \(title) uncovered no Delete"
            )
            delete(of: title).tap()
            settle(1)
            XCTAssertFalse(row(title).exists, "\(title)'s Delete left the row")
        }
        let add = topAddTask()
        drag(at(row("Core 1")), to: screen(0.8, add.frame.midY / app.frame.height), hold: 3)
        assertAboveTheTopAddTask("Core 1", "Core 1 after its drop")
        relaunch()
        openProject()
        assertAboveTheTopAddTask("Core 1", "Core 1 in the store")
    }

    // MARK: - Reading Project


    /// The topmost "Add task" row, which ends the first block.
    private func topAddTask() -> XCUIElement {
        app.buttons.matching(identifier: "Add task").allElementsBoundByIndex.min { $0.frame.minY < $1.frame.minY }
            ?? app.buttons["Add task"].firstMatch
    }

    /// Asserts that a row stands in a block of Project: under the block's header and above the next block's.
    private func assertStands(
        _ row: XCUIElement, in block: String, above next: String, _ what: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(row.exists, "\(what): the row is not drawn", file: file, line: line)
        XCTAssertTrue(
            header(block).exists && header(next).exists, "\(what): \(block)'s or \(next)'s header is not drawn",
            file: file, line: line
        )
        let y = row.frame.minY
        XCTAssertGreaterThan(
            y, header(block).frame.minY, "\(what): it stands above \(block)'s header", file: file, line: line
        )
        XCTAssertLessThan(
            y, header(next).frame.minY, "\(what): it stands below \(next)'s header", file: file, line: line
        )
    }

    /// Asserts that Both one stands once in Ops and once in Docs, and no longer in Design.
    private func assertInOpsAndDocs(_ when: String, file: StaticString = #filePath, line: UInt = #line) {
        let both = rows("Both one")
        XCTAssertEqual(both.count, 2, "\(when): Both one is not drawn twice", file: file, line: line)
        assertStands(both[0], in: "Ops", above: "Docs", "\(when), the first Both one", file: file, line: line)
        assertStands(both[1], in: "Docs", above: "Either", "\(when), the second Both one", file: file, line: line)
    }

    /// Asserts that a row stands in Project's own block, above its "Add task" row and so above Core's header.
    private func assertAboveTheTopAddTask(
        _ title: String, _ what: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(row(title).exists, "\(what): the row is not drawn", file: file, line: line)
        XCTAssertLessThan(
            row(title).frame.minY, topAddTask().frame.minY, "\(what): it stands below the own block's Add task",
            file: file, line: line
        )
        XCTAssertLessThan(
            row(title).frame.minY, header("Core").frame.minY, "\(what): it stands below Core's header",
            file: file, line: line
        )
    }

    // MARK: - Scrolling

    /// The list scrolled by slow drags that end still, so that it does not coast, until an element's top stands about
    /// `y` points from the screen's top.
    private func scroll(_ element: XCUIElement, toY y: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.exists, "the element to scroll to is not drawn", file: file, line: line)
        for _ in 0..<6 {
            let distance = y - element.frame.minY
            if abs(distance) <= 12 { return }
            let step = max(-360, min(360, distance))
            let start = screen(0.5, step > 0 ? 0.3 : 0.75)
            start.press(
                forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: step)), withVelocity: 300,
                thenHoldForDuration: 0.3
            )
            settle(0.6)
        }
        XCTAssertEqual(
            element.frame.minY, y, accuracy: 12, "the list did not scroll to where the walk needs it",
            file: file, line: line
        )
    }
}
