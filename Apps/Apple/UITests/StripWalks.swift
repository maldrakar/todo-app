import XCTest

/// The sentence strip at the screen's foot laid under the floating "+" and the columns, never over them (#193): the
/// window's, for a link that does not read; the sidebar's, for a link to a list that is gone; and the list's own, for
/// a link to a group the list is not grouped by. And what a list's own strip says.
final class StripWalks: Walk {
    private static let rootSentence = "The link could not be opened."
    private static let sidebarSentence = "The list could not be opened."
    private static let ownSentence = "This list is not grouped that way, so the group could not be opened."

    /// How far the floating "+" stands above the screen's bottom, or above a strip's top while one shows: the phone's
    /// `bottomMargin`, 30, of `phoneFloatingButton` in `Sources/Features/TaskList/TaskList+Metrics.swift`.
    private static let plusMargin: CGFloat = 30

    /// How far a strip's text stands below the strip's top: SwiftUI's default `.padding()`, 16 points on iOS, which
    /// every strip takes, the window's and the sidebar's in `RootView.sentenceStrip`
    /// (`Apps/Apple/Sources/TodoAppleUI/RootView.swift`) and the list's own in `listsSentence`
    /// (`Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsTree.swift`).
    private static let stripPadding: CGFloat = 16

    // MARK: - The floating "+"

    /// With no strip, the "+" stands its margin above the screen's bottom, and a tap at its centre opens a new task.
    func testPlusWithNoStrip() {
        open("/view/" + Self.today)
        checkPlus(over: nil)
    }

    /// The window's strip, for a link that does not read, lies under the "+", which stands its margin above it.
    func testPlusAboveTheRootStrip() {
        open("/view/" + Self.today)
        open("view/" + Self.today)
        checkPlus(over: Self.rootSentence)
    }

    /// The sidebar's strip, for a link to a list that is gone, lies under the "+", which stands its margin above it.
    func testPlusAboveTheSidebarStrip() {
        open("/view/" + Self.today)
        open(Self.goneList)
        checkPlus(over: Self.sidebarSentence)
    }

    /// The list's own strip, for a link to a group it is not grouped by, lies under the "+", which stands its margin
    /// above it.
    func testPlusAboveTheOwnStrip() {
        open("/view/" + Self.today + "/tag/" + Self.randomID)
        checkPlus(over: Self.ownSentence)
    }

    // MARK: - The columns

    /// The window's strip lies under Project's columns: Core's column, scrolled to its end, ends as far above it as
    /// it ended above the screen's bottom.
    func testColumnsEndAboveTheRootStrip() {
        checkColumns(over: Self.rootSentence, link: "view/" + Self.today)
    }

    /// The sidebar's strip lies under Project's columns, which end as far above it as above the screen's bottom.
    func testColumnsEndAboveTheSidebarStrip() {
        checkColumns(over: Self.sidebarSentence, link: Self.goneList)
    }

    /// Project's own strip lies under its columns, which end as far above it as above the screen's bottom: a link to a
    /// group of Project by a tag it does not group by.
    func testColumnsEndAboveTheOwnStrip() throws {
        checkColumns(over: Self.ownSentence, link: "/view/" + (try projectID) + "/tag/" + Self.randomID)
    }

    // MARK: - What a strip says

    /// A link to a task that is gone opens its list, which says so at its foot.
    func testLinkToAGoneTaskSaysSo() {
        open("/view/" + Self.today + "/task/" + Self.randomID)
        XCTAssertTrue(app.staticTexts["The task is gone."].waitForExistence(timeout: 3), "Today says the task is gone")
        XCTAssertTrue(topmost("Today").exists, "the link opened Today")
        XCTAssertTrue(app.buttons["Back"].exists, "Today is on top, with no task screen over it")
    }

    // MARK: - Helpers


    /// The seeded list Project's id, which no screen shows and a link to one of Project's groups names: `seed.sh`
    /// prints it and the script hands it over.
    private var projectID: String {
        get throws {
            try XCTUnwrap(ProcessInfo.processInfo.environment["WALK_PROJECT"], "the script handed over no Project id")
        }
    }

    /// A fresh id that names nothing in the store.
    private static var randomID: String { UUID().uuidString.lowercased() }

    /// A link to a list that is gone.
    private static var goneList: String { "/view/" + randomID }

    /// The top of the strip whose text is `sentence`, and nil when no such text shows.
    private func stripTop(_ sentence: String) -> CGFloat? {
        let text = app.staticTexts[sentence].firstMatch
        return text.waitForExistence(timeout: 3) ? text.frame.minY - Self.stripPadding : nil
    }

    /// The bottom of the app's window, the screen's.
    private var screenBottom: CGFloat { app.windows.firstMatch.frame.maxY }

    /// The floating "+" stands `plusMargin` above the top of the strip saying `sentence`, or above the screen's bottom
    /// with none, and a tap at its centre opens a new task's card: a strip laid over the "+" would take that tap.
    private func checkPlus(over sentence: String?) {
        let edge: CGFloat
        if let sentence {
            guard let top = stripTop(sentence) else { return XCTFail("no strip says \"\(sentence)\"") }
            edge = top
        } else {
            edge = screenBottom
        }
        let plus = app.buttons["New task"].firstMatch
        XCTAssertTrue(plus.exists, "the + shows")
        let frame = plus.frame
        XCTAssertEqual(frame.maxY, edge - Self.plusMargin, accuracy: 1,
                       "the + stands \(Self.plusMargin) above \(sentence == nil ? "the screen's bottom" : "the strip")")
        let fields = app.textFields.count
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        settle(1.2)
        XCTAssertGreaterThan(app.textFields.count, fields, "a tap at the +'s centre opens a new task's card")
    }

    /// Core's last card, Core 12.
    private var lastCore: XCUIElement { row("Core 12") }

    /// Core's column scrolled to its end: swipes up in it until its last card stops moving.
    private func scrollCoreToItsEnd() {
        var before = CGFloat.infinity
        for _ in 0..<8 {
            let x = lastCore.frame.midX
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: x, dy: 600))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: 300)))
            settle(0.8)
            if abs(lastCore.frame.maxY - before) < 0.5 { return }
            before = lastCore.frame.maxY
        }
    }

    /// Project as columns, Core brought into sight and scrolled to its end, with no strip and then after `link` with
    /// the strip saying `sentence`: Core's last card ends as far above the strip as it ended above the screen's bottom.
    private func checkColumns(over sentence: String, link: String) {
        openProject()
        setColumns()
        // The board snaps a column at a time: one swipe brings Core, the second column, into sight.
        row("Own one").swipeLeft()
        settle(1)
        scrollCoreToItsEnd()
        XCTAssertTrue(lastCore.exists, "Core 12 shows")
        let gap = screenBottom - lastCore.frame.maxY
        open(link)
        XCTAssertTrue(topmost("Project").exists, "Project is still open after the link")
        scrollCoreToItsEnd()
        guard let top = stripTop(sentence) else { return XCTFail("no strip says \"\(sentence)\"") }
        XCTAssertEqual(top - lastCore.frame.maxY, gap, accuracy: 1,
                       "Core's last card ends as far above the strip as it ended above the screen's bottom")
    }

}
