import XCTest

/// Show as: the layouts the screen's "…" offers and a list switched between them.
final class ShowAsWalks: Walk {
    /// Show as offers List, checked, and Columns where the list has columns to show: disabled with its reason on
    /// Today, which has one block, and enabled on Upcoming, which has a block per day.
    ///
    /// The reason's words are not an element of the system menu's accessibility tree, so they are read from the line
    /// they add to their item: Columns stands taller than List where it carries them, and as tall where it does not.
    func testShowAsOffersColumnsWhereThereAreSome() {
        open("/view/" + Self.today)
        let today = showAs()
        XCTAssertTrue(today.list.isEnabled, "List is disabled on Today")
        XCTAssertTrue(today.list.isSelected, "List is not checked on Today, which is shown as a list")
        XCTAssertFalse(today.columns.isEnabled, "Columns is enabled on Today, which has one block")
        XCTAssertGreaterThan(
            today.columns.frame.height, today.list.frame.height + 20, "Columns carries no reason on Today"
        )
        closeShowAs()
        open("/view/" + Self.upcoming)
        let upcoming = showAs()
        XCTAssertTrue(upcoming.list.isEnabled, "List is disabled on Upcoming")
        XCTAssertTrue(upcoming.columns.isEnabled, "Columns is disabled on Upcoming, which has a block per day")
        XCTAssertEqual(
            upcoming.columns.frame.height, upcoming.list.frame.height, accuracy: 1,
            "Columns carries a reason on Upcoming"
        )
        closeShowAs()
    }

    /// Show as there and back three times: after each round the board scrolled sideways, and in the list a row's swipe
    /// opens and a drag in a scrolled list lands.
    func testShowAsRoundTrip() {
        openProject()
        for round in 1...3 {
            setColumns()
            let x = row("Design one").frame.minX
            app.swipeLeft()
            settle(0.8)
            XCTAssertLessThan(row("Design one").frame.minX, x, "the board did not scroll in round \(round)")
            app.swipeRight()
            settle(0.8)
            setList()
            row("Own two").swipeLeft()
            XCTAssertTrue(delete(of: "Own two").waitForExistence(timeout: 2), "no swipe after round \(round)")
            topmost("Project").tap()
            settle()
            // Scrolled a little, so that a drop's point has to be carried into the content.
            scrollSlowly(from: 0.6, to: 0.52)
            let own = order(["Own one", "Own two"])
            XCTAssertEqual(own.count, 2, "Own one and Own two are not both in sight in round \(round)")
            guard own.count == 2 else { return }
            drag(at(row(own[0])), to: at(row(own[1]), dy: 12))
            XCTAssertEqual(order(["Own one", "Own two"]), [own[1], own[0]], "no drag after round \(round)")
            scrollSlowly(from: 0.52, to: 0.6)
        }
    }

    /// After a round through Columns, a row dragged low in a long list lands where it is let go: the board's frames
    /// left behind do not take the drop.
    func testReorderLowAfterColumnsRoundTrip() {
        openProject()
        let rows = (1...12).map { "Core \($0)" }
        setColumns()
        setList()
        settle()
        drag(at(row("Core 3")), to: at(row("Core 6"), dy: 12))
        let landed = [
            "Core 1", "Core 2", "Core 4", "Core 5", "Core 6", "Core 3", "Core 7", "Core 8", "Core 9", "Core 10",
            "Core 11", "Core 12",
        ]
        XCTAssertEqual(order(rows), landed, "Core 3 did not land under Core 6")
        relaunch()
        openProject()
        XCTAssertEqual(order(rows), landed, "the store did not keep the order")
    }

    /// Show as › List from the screen's "…".
    private func setList() {
        app.buttons["More"].firstMatch.tap()
        settle(0.5)
        app.buttons["List"].firstMatch.tap()
        settle(1)
    }

    /// Show as opened from the screen's "…": its List and Columns.
    private func showAs() -> (list: XCUIElement, columns: XCUIElement) {
        app.buttons["More"].firstMatch.tap()
        let list = app.collectionViews.buttons["List"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 2), "… opened no Show as")
        return (list, app.collectionViews.buttons["Columns"].firstMatch)
    }

    /// Show as closed by a tap beside it.
    private func closeShowAs() {
        app.tap()
        XCTAssertTrue(app.collectionViews.buttons["List"].waitForNonExistence(timeout: 2), "Show as stayed open")
    }
}
