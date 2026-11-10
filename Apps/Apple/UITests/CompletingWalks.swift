import XCTest

/// Completing a task from its check, on a row, on an open card and on a subtask: where it goes, and putting it back.
final class CompletingWalks: Walk {
    /// A completed row leaves its block for the Done strip, whose count goes from the seed's two to three and which
    /// holds the row when it opens; the store keeps it done.
    ///
    /// The row's hold of .7 s before it leaves is not asserted: XCUITest waits for the app to be idle before each
    /// reading, so a reading taken .3 s after the tap comes after the hold has played. A recording shows it
    /// (`scripts/ui-walks.sh --record`).
    func testCompleteIntoTheDoneStrip() {
        open("/view/" + Self.today)
        app.buttons["Complete: Charlie today"].firstMatch.tap()
        XCTAssertTrue(row("Charlie today").waitForNonExistence(timeout: 3), "the completed row stayed in its block")
        let strip = doneStrip()
        XCTAssertTrue(strip.label.hasPrefix("Done today · 3"), "the strip reads \(strip.label), not three done today")
        strip.tap()
        let done = app.buttons["Mark as not done: Charlie today"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 2), "the strip does not hold the row")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertTrue(doneStrip().label.hasPrefix("Done today · 3"), "the store did not keep the task done")
    }

    /// A task two blocks draw, Both one in Design and in Ops, completed from one of its checks: both rows leave, and
    /// the store keeps it done.
    func testCompleteATaskTwoBlocksDraw() {
        openProject()
        let checks = app.buttons.matching(identifier: "Complete: Both one")
        for _ in 0..<6 where checks.firstMatch.frame.minY > 420 {
            app.swipeUp()
            settle()
        }
        XCTAssertEqual(rows("Both one").count, 2, "Both one is not drawn in Design and in Ops")
        checks.firstMatch.tap()
        settle(2)
        XCTAssertEqual(rows("Both one").count, 0, "a row of Both one stayed after its check")
        relaunch()
        openProject()
        for _ in 0..<6 where !row("Ops one").exists {
            app.swipeUp()
            settle()
        }
        XCTAssertTrue(row("Ops one").exists, "Ops' block did not come into sight")
        XCTAssertEqual(rows("Both one").count, 0, "the store did not keep Both one done")
    }

    /// A row completed and put back through the strip's check: it stands open in its block again, and the store keeps
    /// it open.
    ///
    /// The old walk tapped the strip's check .3, .45 and .6 s into the row's leaving; XCUITest waits for the app to be
    /// idle before a tap, so the second tap lands when the motion has ended, and only the end of it is asserted here.
    func testCompleteAndPutBack() {
        open("/view/" + Self.today)
        doneStrip().tap()
        app.buttons["Complete: Filler 14"].firstMatch.tap()
        let undo = app.buttons["Mark as not done: Filler 14"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "the completed row did not come into the open strip")
        undo.tap()
        XCTAssertTrue(
            app.buttons["Complete: Filler 14"].waitForExistence(timeout: 3), "the row put back did not stand open again"
        )
        XCTAssertFalse(undo.exists, "the row put back stayed in the strip")
        relaunch()
        open("/view/" + Self.today)
        scrollToTheEnd()
        XCTAssertTrue(app.buttons["Complete: Filler 14"].exists, "the store did not keep the task open")
    }

    /// An open card's check tapped with the keyboard up in its title: the card leaves and the keyboard goes with it,
    /// and the store keeps the task done.
    ///
    /// The keyboard standing through the card's hold of .7 s, and going in the same frames as the card, is not
    /// asserted: XCUITest waits for the app to be idle before each reading, so only the end of the motion is read.
    func testCompleteAnOpenCardWithTheKeyboardUp() {
        open("/view/" + Self.today)
        row("Alpha today").tap()
        let title = titleField("Alpha today")
        XCTAssertTrue(title.waitForExistence(timeout: 2), "Alpha's card did not open")
        title.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2), "a tap on the title brought no keyboard")
        app.buttons["Complete: Alpha today"].firstMatch.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 3), "the card stayed after its check")
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "the keyboard stayed after the card left"
        )
        XCTAssertFalse(row("Alpha today").exists, "the completed task left a row in its block")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertTrue(doneStrip().label.hasPrefix("Done today · 3"), "the store did not keep the task done")
    }

    /// A subtask's check there and back in the open card, and the store keeps it open.
    func testSubtaskCompletedAndReopened() {
        openSpec()
        app.buttons["Complete: Find the coupon"].firstMatch.tap()
        let done = app.buttons["Mark as not done: Find the coupon"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 2), "the subtask's check did not complete it")
        done.tap()
        let reopened = app.buttons["Complete: Find the coupon"].firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 2), "the subtask's check did not reopen it")
        relaunch()
        openSpec()
        XCTAssertTrue(app.buttons["Complete: Find the coupon"].exists, "the store did not keep the subtask open")
    }

    /// The card of "Review the list screen spec", in Upcoming on tomorrow, opened by a tap on its row.
    private func openSpec() {
        open("/view/" + Self.upcoming)
        row("Review the list screen spec").tap()
        XCTAssertTrue(
            titleField("Review the list screen spec").waitForExistence(timeout: 2), "the spec's card did not open"
        )
    }

    /// The Done strip's capsule, "Done today · N", at the end of the list.
    private func doneStrip() -> XCUIElement {
        let strip = row("Done today")
        for _ in 0..<5 where !(strip.exists && strip.isHittable) {
            app.swipeUp()
            settle()
        }
        XCTAssertTrue(strip.exists && strip.isHittable, "the Done strip did not come into sight")
        return strip
    }

    /// The list scrolled to its end, where Today's last rows and the Done strip stand.
    private func scrollToTheEnd() {
        for _ in 0..<4 { app.swipeUp() }
        settle()
    }

    /// Every row of a task, one per block that draws it.
    private func rows(_ title: String) -> [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).allElementsBoundByIndex
    }
}
