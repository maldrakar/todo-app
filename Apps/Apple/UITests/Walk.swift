import XCTest

/// A walk over the list screen: the real app, launched over a copy of the store `scripts/ui-walks.sh` seeds
/// (`seed.sh` beside this file), made afresh for each walk so that no walk sees another's edits, and opened on the
/// Lists screen. A walk asserts what can be read from outside the app: an order of rows by their frames, an element
/// and its label or value, a title that is still there when the app is launched again over the same store.
///
/// Without the seeded store, as when Xcode's Test action runs the target, every walk is skipped and the simulator it
/// runs on is left alone: a walk would otherwise edit that simulator's store.
@MainActor
class Walk: XCTestCase {
    /// Today's view, one of the five every store starts with.
    static let today = "00000000-0000-4000-8000-000000000002"
    /// Upcoming's view.
    static let upcoming = "00000000-0000-4000-8000-000000000003"

    let app = XCUIApplication()
    /// The store this walk's app opens, a copy of the seeded one; nil when the walk was skipped.
    private var store: URL?

    /// Synchronous, as are the overrides of every walk class: an assertion that fails in an `async` setUp, with
    /// `continueAfterFailure` off, left its tearDown hanging until the run's time allowance ended it (2026-11-11).
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let seeded = ProcessInfo.processInfo.environment["WALK_STORE"] else {
            throw XCTSkip("The walks run through scripts/ui-walks.sh, which seeds the store they walk over.")
        }
        store = try copy(of: URL(filePath: seeded))
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .portrait
        launch()
        toRoot()
    }

    /// XCTest tears down a walk it skipped too, and a skipped walk touched nothing.
    override func tearDownWithError() throws {
        guard store != nil else { return }
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = .light
    }

    // MARK: - The app

    /// Launches the app over this walk's store.
    private func launch() {
        app.launchEnvironment["TODO_DB"] = store?.path(percentEncoded: false)
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "the app did not come to the front")
    }

    /// The app terminated and launched again over the same store, back on the Lists screen, which reads back what was
    /// written. Text still in a field is not written: the app is ended, not sent away, so a walk submits a field or
    /// leaves it first.
    func relaunch() {
        app.terminate()
        launch()
        toRoot()
    }

    /// The seeded store copied into a directory of its own beside it, named after the walk, with its write-ahead log
    /// if one was left; the copy stays after the run, for a walk that failed.
    private func copy(of seeded: URL) throws -> URL {
        let directory = seeded.deletingLastPathComponent()
            .appending(path: "walks", directoryHint: .isDirectory)
            .appending(path: "\(walkName)-\(UUID().uuidString.prefix(8))", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let copy = directory.appending(path: seeded.lastPathComponent)
        try FileManager.default.copyItem(at: seeded, to: copy)
        let log = URL(filePath: seeded.path(percentEncoded: false) + "-wal")
        if FileManager.default.fileExists(atPath: log.path(percentEncoded: false)) {
            try FileManager.default.copyItem(at: log, to: URL(filePath: copy.path(percentEncoded: false) + "-wal"))
        }
        return copy
    }

    /// `Class.testMethod`, from XCTest's `-[Class testMethod]`.
    private var walkName: String {
        name.trimmingCharacters(in: CharacterSet(charactersIn: "-[]")).replacingOccurrences(of: " ", with: ".")
    }

    // MARK: - Getting around

    /// Follows a link to a route of the app, `todo://` and the route: `/view/<id>`, `/view/<id>/task/<id>`. It goes
    /// through the system, as a link from another app does, which hands it to the window on screen: on the iOS 26.3
    /// simulator `XCUIApplication.open(_:)` gave every link a new window instead, so that a link that names a list that
    /// is gone opened Inbox, and the stack of the window before it, a typed title with it, was let go untold
    /// (2026-11-10).
    func open(_ route: String) {
        guard let link = URL(string: "todo://" + route) else { return XCTFail("todo://\(route) is not a link") }
        XCUIDevice.shared.system.open(link)
        settle(1)
    }

    /// Whether the Lists screen is on top: its "Inbox", and no glass back.
    var isRoot: Bool {
        app.staticTexts["Inbox"].exists && !app.buttons["Back"].exists
    }

    /// Back to the Lists screen, by the Back buttons of the screens over it.
    private func toRoot() {
        for _ in 0..<5 {
            if isRoot { return }
            if app.buttons["Back"].exists {
                app.buttons["Back"].firstMatch.tap()
            } else if app.navigationBars.buttons.count > 0 {
                app.navigationBars.buttons.firstMatch.tap()
            }
            settle(0.8)
        }
        XCTAssertTrue(isRoot, "the Lists screen did not show")
    }

    /// The seeded list "Project", opened from the Lists screen.
    func openProject() {
        toRoot()
        app.staticTexts["Project"].firstMatch.tap()
        settle(1)
    }

    /// Show as › Columns from the screen's "…" on Project, the list the walks show as columns, and the board asserted.
    func setColumns(file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["More"].firstMatch.tap()
        settle(0.5)
        app.buttons["Columns"].firstMatch.tap()
        settle(1)
        assertProjectShowsColumns(file: file, line: line)
    }

    /// Asserts that Project is drawn as a board: Core's and Design's titles stand side by side, as columns, and not one
    /// under the other, as blocks, where a card and a row read alike.
    func assertProjectShowsColumns(file: StaticString = #filePath, line: UInt = #line) {
        let core = header("Core")
        let design = header("Design")
        XCTAssertTrue(core.exists && design.exists, "Core's or Design's title is not drawn", file: file, line: line)
        XCTAssertGreaterThan(
            design.frame.minX - core.frame.minX, 100,
            "Project is not shown as columns: Core's and Design's titles stand at x \(core.frame.minX) and "
                + "\(design.frame.minX)",
            file: file, line: line
        )
    }

    /// A task's card, opened by a tap on its row.
    func openCard(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        row(title).tap()
        XCTAssertTrue(
            titleField(title).waitForExistence(timeout: 2), "the card of \(title) did not open", file: file, line: line
        )
    }

    /// A card opened on `title`, `letters` typed at the end of its title, with no Return.
    func typeAtTheEnd(of title: String, _ letters: String, file: StaticString = #filePath, line: UInt = #line) {
        openCard(title, file: file, line: line)
        titleField(title).coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        settle(1)
        app.typeText(letters)
        settle()
        XCTAssertTrue(
            titleField(title + letters).exists, "the title reads what was typed, the fields read \(fieldValues)",
            file: file, line: line
        )
    }

    /// "+ Add list" at the end of the list, and `name` typed in the new list's field, with no Return.
    func addList(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let add = app.buttons["Add list"].firstMatch
        scroll(to: add, "Add list", file: file, line: line)
        add.tap()
        settle(1.2)
        app.typeText(name)
        settle()
        XCTAssertTrue(
            fieldValues.contains(name), "the new list's field reads what was typed, the fields read \(fieldValues)",
            file: file, line: line
        )
    }

    /// The list scrolled up until an element, called `name` in a failure, is in sight.
    func scroll(to element: XCUIElement, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<6 where !(element.exists && element.isHittable) {
            app.swipeUp()
            settle(0.5)
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(name) did not come into sight", file: file, line: line)
    }

    /// The list scrolled to its end, by fast swipes up.
    func scrollToTheEnd() {
        for _ in 0..<4 {
            app.swipeUp(velocity: .fast)
        }
        settle(1)
    }

    /// A slow drag of the list from one height of the screen to another, given as fractions of the screen's, which
    /// ends still, so that the list does not coast.
    func scrollSlowly(from start: CGFloat, to end: CGFloat) {
        screen(0.5, start)
            .press(forDuration: 0.02, thenDragTo: screen(0.5, end), withVelocity: 60, thenHoldForDuration: 0.02)
        settle(0.8)
    }

    // MARK: - What is on the screen

    /// A block's header on a list, or a column's on a board, by its list's name.
    func header(_ list: String) -> XCUIElement {
        app.buttons[list].firstMatch
    }

    /// A task's row or a column's card, by the start of its title.
    func row(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    /// Every row of a task, one per block that draws it, from the top of the screen.
    func rows(_ title: String) -> [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).allElementsBoundByIndex
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    /// The titles given, of the rows that exist, from the top of the screen.
    func order(_ titles: [String]) -> [String] {
        titles.filter { row($0).exists }.sorted { row($0).frame.minY < row($1).frame.minY }
    }

    /// The rows of tasks with no title, which read "New task", their placeholder, and stand as wide as the list: the
    /// floating "+", which reads so too, is 48 points across. #195's walks were red on this count before its fix.
    var untitledRows: Int {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task")).allElementsBoundByIndex
            .filter { $0.frame.width > 200 }.count
    }

    /// The Done strip's capsule, "Done today · N", at the end of the list, scrolled into sight.
    func doneStrip(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let strip = row("Done today")
        scroll(to: strip, "the Done strip", file: file, line: line)
        return strip
    }

    /// A row's swipe's Delete.
    func delete(of title: String) -> XCUIElement {
        app.buttons["Delete " + title].firstMatch
    }

    /// The topmost text of that label, the screen's title: a lazy stack can list an open card's "Today" pill before it
    /// (#196).
    func topmost(_ label: String) -> XCUIElement {
        app.staticTexts.matching(identifier: label).allElementsBoundByIndex.min { $0.frame.minY < $1.frame.minY }
            ?? app.staticTexts[label].firstMatch
    }

    /// The open card's title field, by the start of its value.
    func titleField(_ prefix: String) -> XCUIElement {
        app.textFields.matching(NSPredicate(format: "value BEGINSWITH %@", prefix)).firstMatch
    }

    /// The open card's notes while they are empty, a text field or a text view by its placeholder: a field with text
    /// in it reads no placeholder, and `fieldValues` reads it then.
    var notesField: XCUIElement {
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Notes")).firstMatch
        return field.exists ? field : app.textViews.matching(NSPredicate(format: "placeholderValue == %@", "Notes")).firstMatch
    }

    /// The values of the text fields and text views on the screen.
    var fieldValues: [String] {
        (app.textFields.allElementsBoundByIndex + app.textViews.allElementsBoundByIndex)
            .map { $0.value as? String ?? "" }
    }

    // MARK: - Gestures

    /// The centre of an element, moved down by `dy` points.
    func at(_ element: XCUIElement, dy: CGFloat = 0) -> XCUICoordinate {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: dy))
    }

    /// A point of the screen, as fractions of its width and height.
    func screen(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    /// A press and a move, as a finger lifts a row and carries it, held there a moment before the release.
    func drag(_ from: XCUICoordinate, to: XCUICoordinate, hold: TimeInterval = 0.4) {
        from.press(forDuration: 0.6, thenDragTo: to, withVelocity: 400, thenHoldForDuration: hold)
        settle(0.8)
    }

    /// A pause for an animation XCUITest does not wait for: a drop settling, a card growing, a screen pushed.
    func settle(_ seconds: TimeInterval = 0.6) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
