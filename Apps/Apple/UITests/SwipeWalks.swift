import XCTest

/// A row's sideways swipe: the distances that open and close it, its Delete, and the scrolls it leaves alone.
final class SwipeWalks: Walk {
    /// A swipe moves the row aside and stays open on its Delete, which takes the task away, from the store too.
    func testSwipeAndItsDelete() {
        open("/view/" + Self.today)
        let alpha = row("Alpha today")
        let x = alpha.frame.minX
        alpha.swipeLeft()
        XCTAssertTrue(delete(of: "Alpha today").waitForExistence(timeout: 2), "a swipe uncovered no Delete")
        XCTAssertLessThan(alpha.frame.minX, x, "the swiped row stayed where it was")
        delete(of: "Alpha today").tap()
        settle(1)
        XCTAssertFalse(row("Alpha today").exists, "the swipe's Delete left the row")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertTrue(row("Bravo today").waitForExistence(timeout: 2), "Today did not open again")
        XCTAssertFalse(row("Alpha today").exists, "the store kept the deleted task")
    }

    /// A slow drag short of the threshold goes back and one past it stays open; a tap on another row, a right swipe,
    /// another row's swipe and a scroll each close it, and the tap opens nothing.
    func testSwipeRules() {
        open("/view/" + Self.today)
        let bravo = row("Bravo today")
        let charlie = row("Charlie today")
        sideways(bravo, by: -30)
        XCTAssertFalse(delete(of: "Bravo today").exists, "a drag of 30 stayed open short of the threshold")
        sideways(bravo, by: -70)
        XCTAssertTrue(delete(of: "Bravo today").exists, "a drag of 70 went back past the threshold")
        charlie.tap()
        settle()
        XCTAssertFalse(delete(of: "Bravo today").exists, "a tap on another row left the swiped one open")
        XCTAssertEqual(app.textFields.count, 0, "a tap while a row stood open opened a card")
        bravo.swipeLeft()
        XCTAssertTrue(delete(of: "Bravo today").waitForExistence(timeout: 2), "the swipe did not open again")
        at(bravo).withOffset(CGVector(dx: -60, dy: 0))
            .press(forDuration: 0.05, thenDragTo: at(bravo).withOffset(CGVector(dx: 60, dy: 0)), withVelocity: 300,
                   thenHoldForDuration: 0.05)
        settle()
        XCTAssertFalse(delete(of: "Bravo today").exists, "a right swipe left the row open")
        bravo.swipeLeft()
        XCTAssertTrue(delete(of: "Bravo today").waitForExistence(timeout: 2), "the swipe did not open again")
        charlie.swipeLeft()
        settle()
        XCTAssertFalse(delete(of: "Bravo today").exists, "another row's swipe left the first open")
        XCTAssertTrue(delete(of: "Charlie today").exists, "another row's swipe did not open it")
        at(row("Delta today"))
            .press(forDuration: 0.02, thenDragTo: at(row("Alpha today")), withVelocity: 600, thenHoldForDuration: 0.05)
        settle(0.8)
        XCTAssertFalse(delete(of: "Charlie today").exists, "a scroll left the row open")
    }

    /// A still press of .3 s is a tap that opens the card, and a move after .1 s scrolls the list and lifts nothing.
    func testTapAndEarlyMove() {
        open("/view/" + Self.today)
        at(row("Delta today")).press(forDuration: 0.3)
        settle(0.7)
        XCTAssertGreaterThan(app.textFields.count, 0, "a still press of .3 s opened no card")
        XCTAssertFalse(app.buttons["Delete"].exists, "a still press of .3 s opened the menu")
        topmost("Today").tap()
        settle(0.5)
        let todays = ["Alpha today", "Bravo today", "Charlie today", "Delta today"]
        let before = order(todays)
        let y = row("Alpha today").frame.minY
        at(row("Delta today"))
            .press(forDuration: 0.1, thenDragTo: at(row("Alpha today")), withVelocity: 300, thenHoldForDuration: 0.1)
        settle(0.8)
        XCTAssertEqual(order(todays), before, "a move after .1 s moved a row")
        XCTAssertNotEqual(row("Alpha today").frame.minY, y, "a move after .1 s did not scroll")
    }

    /// The list's vertical scroll still starts on a row, quick and slow.
    func testVerticalScrollFromARow() {
        open("/view/" + Self.today)
        let y = row("Alpha today").frame.minY
        at(row("Delta today"))
            .press(forDuration: 0.02, thenDragTo: at(row("Alpha today")), withVelocity: 800, thenHoldForDuration: 0.02)
        settle(0.8)
        let quick = row("Alpha today").frame.minY
        XCTAssertLessThan(quick, y, "a quick drag up from a row did not scroll")
        screen(0.5, 0.8)
            .press(forDuration: 0.02, thenDragTo: screen(0.5, 0.6), withVelocity: 60, thenHoldForDuration: 0.02)
        settle(0.8)
        XCTAssertLessThan(row("Alpha today").frame.minY, quick, "a slow drag up from a row did not scroll")
    }

    /// The tag bar's own sideways scroll beside the swipe: a drag along it scrolls its chips and opens no row.
    func testTagBarBesideTheSwipe() {
        openProject()
        let chip = app.buttons["core"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 2), "Project's tag bar has no core chip")
        let x = chip.frame.minX
        at(chip).press(forDuration: 0.02, thenDragTo: at(chip).withOffset(CGVector(dx: -150, dy: 0)), withVelocity: 300,
                       thenHoldForDuration: 0.05)
        settle(0.8)
        XCTAssertLessThan(chip.frame.minX, x, "a drag along the tag bar did not scroll its chips")
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete'")).count, 0,
            "a drag along the tag bar opened a row's swipe"
        )
    }

    /// A tap on a check while another row stands swiped open closes that row and completes the task, and a plain tap
    /// after it still opens a card.
    func testCompleteWhileARowStandsSwiped() {
        open("/view/" + Self.today)
        row("Bravo today").swipeLeft()
        XCTAssertTrue(delete(of: "Bravo today").waitForExistence(timeout: 2), "Bravo did not stand open")
        app.buttons["Complete: Charlie today"].firstMatch.tap()
        settle(2)
        XCTAssertFalse(delete(of: "Bravo today").exists, "the open row stayed open through another's check")
        XCTAssertFalse(row("Charlie today").exists, "Charlie was not completed")
        row("Delta today").tap()
        XCTAssertTrue(titleField("Delta today").waitForExistence(timeout: 2), "a tap after the check opened no card")
    }

    /// A slow drag of a row sideways by `dx`, let go where it ends.
    private func sideways(_ element: XCUIElement, by dx: CGFloat) {
        at(element).press(
            forDuration: 0.05, thenDragTo: at(element).withOffset(CGVector(dx: dx, dy: 0)), withVelocity: 40,
            thenHoldForDuration: 0.1
        )
        settle()
    }
}
