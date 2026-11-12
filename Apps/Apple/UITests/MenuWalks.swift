import XCTest

/// The menu a still hold opens, on a row and on a column's card, and the hold that opens nothing.
///
/// While a row's menu stands, the app never tells XCUITest that its animations have ended, and XCUITest waits a minute
/// for that around every event that reaches the app: after a hold that opens the menu, and before each tap while it
/// stands. The holds are aimed at their points of the screen through the springboard, after which XCUITest waits for
/// the springboard alone; a tap has no such way round, so each tap on a standing menu costs that minute.
final class MenuWalks: Walk {
    /// The system's process under the app, through which a hold is aimed.
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// A still hold opens the system's menu, with Delete; a tap outside closes it and opens nothing, and its Delete
    /// takes the row away, from the store too.
    func testStillHoldOpensTheMenu() {
        open("/view/" + Self.today)
        let delete = app.buttons["Delete"].firstMatch
        onScreen(row("Delta today")).press(forDuration: 1.2)
        XCTAssertTrue(delete.waitForExistence(timeout: 2), "no menu after a still hold")
        screen(0.5, 0.75).tap()
        XCTAssertTrue(delete.waitForNonExistence(timeout: 2), "the menu stayed after a tap outside")
        XCTAssertTrue(row("Delta today").exists, "the tap that closed the menu took the row away")
        XCTAssertEqual(app.textFields.count, 0, "the tap that closed the menu opened a card")
        onScreen(row("Delta today")).press(forDuration: 1.2)
        XCTAssertTrue(delete.waitForExistence(timeout: 2), "no menu after the second still hold")
        delete.tap()
        XCTAssertTrue(row("Delta today").waitForNonExistence(timeout: 2), "the menu's Delete left the row")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertTrue(row("Charlie today").waitForExistence(timeout: 2), "Today did not open again")
        XCTAssertFalse(row("Delta today").exists, "the store kept the deleted task")
    }

    /// A still hold on a column's card opens the same menu, and its Delete takes the card away, from the store too.
    func testCardMenu() {
        openProject()
        setColumns()
        let delete = app.buttons["Delete"].firstMatch
        onScreen(row("Own two")).press(forDuration: 1.2)
        XCTAssertTrue(delete.waitForExistence(timeout: 2), "no menu after a still hold on a card")
        delete.tap()
        XCTAssertTrue(row("Own two").waitForNonExistence(timeout: 2), "the menu's Delete left the card")
        relaunch()
        openProject()
        XCTAssertTrue(row("Own one").waitForExistence(timeout: 2), "Project did not open again")
        XCTAssertFalse(row("Own two").exists, "the store kept the deleted task")
    }

    /// An open card has no menu and no lift: a still hold in its title field opens no Delete, and a hold and a move
    /// from it moves no row and leaves the card in its place.
    func testOpenCardIsNotLifted() {
        open("/view/" + Self.today)
        let titles = ["Alpha today", "Charlie today", "Delta today"]
        openCard("Bravo today")
        let field = titleField("Bravo today")
        onScreen(field).press(forDuration: 1.2)
        settle()
        XCTAssertFalse(app.buttons["Delete"].exists, "a still hold in the card's field opened the row's menu")
        onScreen(field).press(forDuration: 0.6, thenDragTo: onScreen(row("Delta today")), withVelocity: 400,
                              thenHoldForDuration: 0.3)
        settle(0.8)
        XCTAssertEqual(order(titles), titles, "a hold and a move from the card's field moved a row")
        XCTAssertGreaterThan(field.frame.minY, row("Alpha today").frame.minY, "the card left its place under Alpha")
        XCTAssertLessThan(field.frame.minY, row("Charlie today").frame.minY, "the card left its place over Charlie")
    }

    /// The centre of an element, as a point of the screen reached through the springboard, so that an event there waits
    /// for the springboard to be idle and not for the app.
    private func onScreen(_ element: XCUIElement) -> XCUICoordinate {
        let frame = element.frame
        return springboard.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY))
    }
}
