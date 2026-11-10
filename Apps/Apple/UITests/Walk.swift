import XCTest

/// A walk over the list screen: the real app, launched over a copy of the store `scripts/ui-walks.sh` seeds
/// (`seed.sh` beside this file), made afresh for each walk so that no walk sees another's edits, and opened on the
/// Lists screen. A walk asserts what can be read from outside the app: an order of rows by their frames, an element
/// and its label or value, a title that is still there when the app is launched again over the same store.
///
/// Without the seeded store, as when Xcode's Test action runs the target, every walk is skipped: it would otherwise
/// edit the store of the simulator it runs on.
@MainActor
class Walk: XCTestCase {
    /// Today's view, one of the five every store starts with.
    static let today = "00000000-0000-4000-8000-000000000002"
    /// Upcoming's view.
    static let upcoming = "00000000-0000-4000-8000-000000000003"

    private(set) var app = XCUIApplication()
    /// The seeded list Project's id, which no screen shows and a link to one of Project's groups names; `seed.sh`
    /// prints it and the script hands it over.
    private(set) var projectID = ""
    /// The store this walk's app opens, a copy of the seeded one.
    private var store: URL?

    override func setUp() async throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard let seeded = environment["WALK_STORE"], let project = environment["WALK_PROJECT"] else {
            throw XCTSkip("The walks run through scripts/ui-walks.sh, which seeds the store they walk over.")
        }
        projectID = project
        store = try copy(of: URL(filePath: seeded))
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .portrait
        launch()
        toRoot()
    }

    override func tearDown() async throws {
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
        XCUIDevice.shared.system.open(URL(string: "todo://" + route)!)
        settle(1)
    }

    /// Back to the Lists screen, by the Back buttons of the screens over it.
    private func toRoot() {
        for _ in 0..<5 {
            if app.staticTexts["Inbox"].exists && !app.buttons["Back"].exists { return }
            if app.buttons["Back"].exists {
                app.buttons["Back"].firstMatch.tap()
            } else if app.navigationBars.buttons.count > 0 {
                app.navigationBars.buttons.firstMatch.tap()
            }
            settle(0.8)
        }
        XCTAssertTrue(app.staticTexts["Inbox"].exists, "the Lists screen did not show")
    }

    /// The seeded list "Project", opened from the Lists screen.
    func openProject() {
        toRoot()
        app.staticTexts["Project"].firstMatch.tap()
        settle(1)
    }

    /// Show as › Columns from the screen's "…".
    func setColumns() {
        app.buttons["More"].firstMatch.tap()
        settle(0.5)
        app.buttons["Columns"].firstMatch.tap()
        settle(1)
    }

    /// Show as › List from the screen's "…".
    func setList() {
        app.buttons["More"].firstMatch.tap()
        settle(0.5)
        app.buttons["List"].firstMatch.tap()
        settle(1)
    }

    /// The system's swipe from the screen's left edge, at a height given as a fraction of the screen's.
    func edgeSwipe(y: CGFloat = 0.5) {
        screen(0.003, y).press(forDuration: 0.1, thenDragTo: screen(0.8, y), withVelocity: .slow, thenHoldForDuration: 0.1)
        settle(1.2)
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

    /// The titles given, of the rows that exist, from the top of the screen.
    func order(_ titles: [String]) -> [String] {
        titles.filter { row($0).exists }.sorted { row($0).frame.minY < row($1).frame.minY }
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

    /// The open card's notes, a text field or a text view by its placeholder.
    var notesField: XCUIElement {
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Notes")).firstMatch
        return field.exists ? field : app.textViews.matching(NSPredicate(format: "placeholderValue == %@", "Notes")).firstMatch
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
