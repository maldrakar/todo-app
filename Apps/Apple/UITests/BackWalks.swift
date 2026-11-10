import XCTest

/// Going back from the list screen, by the glass back, by the swipe from the screen's edge and by the task screen's
/// back, with and without a card open: a list the stack lets go closes what it has open by the rule of every close
/// (#195), and the way back leaves the screen under it whole.
final class BackWalks: Walk {
    /// How far the press on the task screen's back moves down the menu it opens before it lets go. The menu opens under
    /// the finger and a release picks the item under it: 100 points down passes the nearest screen, Core, and Project,
    /// and lands on the Lists screen (#195's walk, where it was read from `MENU_DY`).
    private static let menuDrop: CGFloat = 100

    /// The narrowest an iPhone stands upright whose window iOS makes regular in width turned sideways, which the app
    /// draws as the pane beside the sidebar: 414 points, the Plus and Max sizes and wider. The iPhone 17 is 402 across,
    /// its Pro Max 440.
    private static let narrowestPhoneWideSideways: CGFloat = 414

    // MARK: - The swipe from the edge with something open (#195)

    /// A title typed at the end of a card's title with no Return, then the swipe back: the title is written.
    func testSwipeBackWritesATypedTitle() {
        openProject()
        typeAtTheEnd(of: "Own one", "qrs")
        edgeSwipe(y: Self.aboveTheKeyboard)
        XCTAssertTrue(isRoot, "the swipe went back to the Lists screen")
        relaunch()
        openProject()
        XCTAssertTrue(row("Own oneqrs").exists, "the store kept the typed title")
    }

    /// Notes typed last in a card, no field left, then the swipe back: the notes are written.
    func testSwipeBackWritesTypedNotes() {
        openProject()
        row("Own two").tap()
        let notes = notesField
        XCTAssertTrue(notes.waitForExistence(timeout: 2), "Own two's card shows its notes")
        notes.tap()
        settle(1)
        app.typeText("Swiped note")
        settle()
        XCTAssertTrue(fieldValues.contains("Swiped note"),
                      "the notes read what was typed, the fields read \(fieldValues)")
        edgeSwipe(y: Self.aboveTheKeyboard)
        XCTAssertTrue(isRoot, "the swipe went back to the Lists screen")
        relaunch()
        openProject()
        row("Own two").tap()
        settle(1.2)
        XCTAssertTrue(fieldValues.contains("Swiped note"),
                      "the store kept the typed notes, the card reads \(fieldValues)")
    }

    /// The floating "+", nothing put in, then the swipe back: no empty task is left.
    func testSwipeBackDeletesAnEmptyNewTask() {
        openProject()
        app.buttons["New task"].firstMatch.tap()
        settle(1.2)
        XCTAssertGreaterThan(app.textFields.count, 0, "the + opened a new task's card")
        edgeSwipe(y: Self.aboveTheKeyboard)
        XCTAssertTrue(isRoot, "the swipe went back to the Lists screen")
        relaunch()
        openProject()
        XCTAssertEqual(emptyTaskRows, 0, "the store kept no task with no title")
    }

    /// "+ Add list", a name typed with no Return, then the swipe back: the list is named what was typed.
    func testSwipeBackWritesAListName() {
        openProject()
        addList(named: "Fresh")
        edgeSwipe(y: Self.aboveTheKeyboard)
        XCTAssertTrue(isRoot, "the swipe went back to the Lists screen")
        relaunch()
        openProject()
        toTheEnd()
        XCTAssertTrue(app.buttons["Fresh"].exists || app.staticTexts["Fresh"].exists, "the store kept the list's name")
    }

    /// A list over a list, Core opened from Project's block title, a title typed in Core's card, then the swipe back
    /// to Project: Core's block there reads what was typed.
    func testSwipeBackFromAListOverAListWritesItsTitle() {
        openProject()
        openCore()
        typeAtTheEnd(of: "Core 2", "nst")
        edgeSwipe(y: Self.aboveTheKeyboard)
        XCTAssertTrue(topmost("Project").exists, "the swipe went back to Project")
        XCTAssertTrue(row("Core 2nst").exists, "Project's Core block shows the typed title")
        relaunch()
        openProject()
        XCTAssertTrue(row("Core 2nst").exists, "the store kept the typed title")
    }

    /// One pop of several screens: the "+" in Core over Project, Open full screen on the new task, then the task
    /// screen's back menu to the Lists screen. Core goes with the task screen, and its empty new task with it.
    func testBackMenuPastAListDeletesItsEmptyNewTask() {
        openProject()
        openCore()
        app.buttons["New task"].firstMatch.tap()
        settle(1.2)
        let full = app.buttons["Open full screen"].firstMatch
        XCTAssertTrue(full.waitForExistence(timeout: 2), "the new task's card shows Open full screen")
        full.tap()
        settle(1.5)
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.exists, "the task screen shows its back")
        let from = at(back)
        from.press(forDuration: 1.2, thenDragTo: from.withOffset(CGVector(dx: 30, dy: Self.menuDrop)),
                   withVelocity: .slow, thenHoldForDuration: 0.6)
        settle(1.5)
        XCTAssertTrue(isRoot, "the menu's item \(Self.menuDrop) points down took the stack to the Lists screen")
        relaunch()
        openProject()
        openCore()
        XCTAssertEqual(emptyTaskRows, 0, "the store kept no task with no title in Core")
    }

    /// A link while Core over Project has a card with a title typed: the link's list replaces Project and Core in the
    /// stack, and Core's typed title is written.
    func testLinkReplacingAListWritesItsTypedTitle() {
        openProject()
        openCore()
        typeAtTheEnd(of: "Core 2", "lnk")
        open("/view/" + Self.upcoming)
        XCTAssertTrue(topmost("Upcoming").waitForExistence(timeout: 2), "the link opened Upcoming")
        XCTAssertEqual(app.textFields.count, 0, "no field is left open")
        relaunch()
        openProject()
        XCTAssertTrue(row("Core 2lnk").exists, "the store kept the typed title")
    }

    // MARK: - The glass back

    /// The glass back with a card open closes it as every close does: a title typed with no Return is written, and a
    /// new task nothing was put in is deleted.
    func testGlassBackWithACardOpen() {
        openProject()
        typeAtTheEnd(of: "Own two", "xyz")
        app.buttons["Back"].firstMatch.tap()
        settle(1.2)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
        openProject()
        app.buttons["New task"].firstMatch.tap()
        settle(1.2)
        XCTAssertGreaterThan(app.textFields.count, 0, "the + opened a new task's card")
        app.buttons["Back"].firstMatch.tap()
        settle(1.2)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
        relaunch()
        openProject()
        XCTAssertTrue(row("Own twoxyz").exists, "the store kept the typed title")
        XCTAssertEqual(emptyTaskRows, 0, "the store kept no task with no title")
    }

    /// "+ Add list", a name typed with no Return, then the glass back: the list is named what was typed.
    func testGlassBackWritesAListName() {
        openProject()
        addList(named: "Fresh")
        app.buttons["Back"].firstMatch.tap()
        settle(1.2)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
        relaunch()
        openProject()
        toTheEnd()
        XCTAssertTrue(app.buttons["Fresh"].exists || app.staticTexts["Fresh"].exists, "the store kept the list's name")
        XCTAssertFalse(app.buttons["New list"].exists || app.staticTexts["New list"].exists, "no list is left unnamed")
    }

    /// A list opened from the Lists screen and left by the glass back, Project's and then Today's: the Lists screen
    /// comes back with no row and no button left selected.
    func testGlassBackLeavesNothingSelected() {
        app.staticTexts["Project"].firstMatch.tap()
        settle(1.2)
        app.buttons["Back"].firstMatch.tap()
        settle(1.8)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
        XCTAssertEqual(selectedLabels, [], "nothing is left selected after Project")
        topmost("Today").tap()
        settle(1.2)
        app.buttons["Back"].firstMatch.tap()
        settle(1.8)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
        XCTAssertEqual(selectedLabels, [], "nothing is left selected after Today")
    }

    /// The glass back, then a swipe from the edge on the Lists screen, three times: the swipe on the stack's root does
    /// nothing, and a row opens its list after it.
    func testGlassBackThenASwipeOnTheRoot() {
        for round in 1...3 {
            topmost("Today").tap()
            XCTAssertTrue(isListOpen, "round \(round): Today opened")
            app.buttons["Back"].firstMatch.tap()
            settle(1)
            XCTAssertTrue(isRoot, "round \(round): the glass back went to the Lists screen")
            edgeSwipe()
            XCTAssertTrue(isRoot, "round \(round): the swipe on the Lists screen left it there")
        }
        topmost("Today").tap()
        XCTAssertTrue(isListOpen, "Today opened after the last swipe")
    }

    /// A card closed by a tap on the header's title and by one on the room under the rows, then opened again, its
    /// title's field tapped, and Open full screen, whose back finds the card open; then the glass back, which closes
    /// it, and the swipe from the edge, each from Today to the Lists screen. Today is narrowed by its tag bar to its
    /// one task tagged work, so that room stands under its rows.
    func testCardClosesThenTheWaysBack() {
        open("/view/" + Self.today)
        app.buttons["work"].firstMatch.tap()
        settle()
        row("Bravo today").tap()
        settle(0.5)
        XCTAssertGreaterThan(app.textFields.count, 0, "Bravo's card is open")
        topmost("Today").tap()
        settle(0.5)
        XCTAssertEqual(app.textFields.count, 0, "a tap on the header's title closed the card")
        row("Bravo today").tap()
        settle(0.5)
        XCTAssertGreaterThan(app.textFields.count, 0, "Bravo's card is open again")
        screen(0.7, 0.95).tap()
        settle(0.5)
        XCTAssertEqual(app.textFields.count, 0, "a tap on the room under the rows closed the card")
        row("Bravo today").tap()
        settle(0.5)
        app.textFields.firstMatch.tap()
        settle(0.5)
        app.buttons["Open full screen"].firstMatch.tap()
        settle(1)
        XCTAssertEqual(app.navigationBars.count, 1, "the task screen shows its bar")
        app.navigationBars.buttons.firstMatch.tap()
        settle(1)
        XCTAssertGreaterThan(app.textFields.count, 0,
                             "back from the task screen, the card Open full screen left is open")
        app.buttons["Back"].firstMatch.tap()
        settle(1)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
        XCTAssertEqual(app.textFields.count, 0, "the glass back closed the card")
        open("/view/" + Self.today)
        edgeSwipe()
        XCTAssertTrue(isRoot, "the swipe from the edge went back to the Lists screen")
    }

    // MARK: - The swipe from the edge

    /// A swipe from the edge let go short, over the task screen: the task screen stays, its back goes to the list, the
    /// glass back to the Lists screen, where a swipe does nothing, and the rows open their lists after it. #177's walk
    /// opened the task screen by a link, with the list never shown; the task's id is on no screen, so this one opens it
    /// from the task's card.
    func testCancelledSwipeOverTheTaskScreen() {
        open("/view/" + Self.upcoming)
        row("Review the list screen spec").tap()
        settle(0.8)
        app.buttons["Open full screen"].firstMatch.tap()
        settle(1)
        XCTAssertEqual(app.navigationBars.count, 1, "the task screen shows its bar")
        screen(0.003, 0.5).press(forDuration: 0.1, thenDragTo: screen(0.2, 0.5), withVelocity: .slow,
                                 thenHoldForDuration: 0.3)
        settle(1.2)
        XCTAssertEqual(app.navigationBars.count, 1, "the swipe let go short left the task screen on top")
        XCTAssertFalse(app.buttons["Back"].exists, "the list is not on top")
        app.navigationBars.buttons.firstMatch.tap()
        settle(1)
        XCTAssertTrue(isListOpen, "the task screen's back went to the list")
        app.buttons["Back"].firstMatch.tap()
        settle(1)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
        edgeSwipe()
        XCTAssertTrue(isRoot, "the swipe on the Lists screen left it there")
        topmost("Today").tap()
        XCTAssertTrue(isListOpen, "a row of the Lists screen opens its list")
        app.buttons["Back"].firstMatch.tap()
        settle(1)
        edgeSwipe()
        app.staticTexts["Upcoming"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Tomorrow"].waitForExistence(timeout: 2), "Upcoming opened, its first day shown")
        XCTAssertTrue(isListOpen, "Upcoming stands over the Lists screen")
    }

    /// The task screen opened from a card, left by the swipe from the edge to its list, and the list left by another
    /// to the Lists screen.
    func testSwipeBackFromTheTaskScreenAndTheList() {
        open("/view/" + Self.today)
        row("Charlie today").tap()
        settle(0.5)
        app.buttons["Open full screen"].firstMatch.tap()
        settle(1)
        XCTAssertEqual(app.navigationBars.count, 1, "the task screen shows its bar")
        edgeSwipe()
        XCTAssertTrue(topmost("Today").exists, "the swipe went back to Today")
        XCTAssertFalse(app.staticTexts["Inbox"].exists, "the swipe went back one screen")
        topmost("Today").tap()
        settle(0.5)
        edgeSwipe()
        XCTAssertTrue(isRoot, "the second swipe went back to the Lists screen")
    }

    /// A group's screen over its list, the day after tomorrow's over Upcoming: the swipe goes back one screen at a
    /// time, does nothing on the Lists screen, and a row opens its list after it.
    func testSwipeBackOneScreenAtATime() throws {
        let day = try weekday(daysFromToday: 2)
        open("/view/" + Self.upcoming)
        row(day).tap()
        settle(1)
        XCTAssertTrue(topmost(day).exists, "\(day)'s screen shows")
        XCTAssertFalse(app.staticTexts["Upcoming"].exists, "the group's screen stands over Upcoming")
        edgeSwipe()
        XCTAssertTrue(app.staticTexts["Tomorrow"].exists, "one back: Upcoming, its first day shown")
        XCTAssertFalse(app.staticTexts["Inbox"].exists, "one back: not the Lists screen")
        edgeSwipe()
        XCTAssertTrue(isRoot, "two back: the Lists screen")
        XCTAssertFalse(app.staticTexts["Tomorrow"].exists, "two back: Upcoming is gone")
        edgeSwipe()
        XCTAssertTrue(isRoot, "the swipe on the Lists screen left it there")
        topmost("Today").tap()
        XCTAssertTrue(isListOpen, "a row of the Lists screen opens its list")
        app.buttons["Back"].firstMatch.tap()
        settle(1)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
    }

    /// The system's swipe from the edge beside the row's swipe and the board's scroll: over a row swiped open in a
    /// list over a list it goes back, at most a second swipe after the first closed the row; on a board scrolled or at
    /// its start it goes back; and a short sideways move from inside the board, which the back swipe does not take,
    /// scrolls the board.
    func testSwipeBackBesideTheGestures() {
        openProject()
        openCore()
        row("Core 2").swipeLeft()
        settle()
        XCTAssertTrue(delete(of: "Core 2").exists, "Core 2 stands swiped open")
        edgeSwipe(y: row("Core 2").frame.midY / app.frame.height)
        if !topmost("Project").exists {
            edgeSwipe()
        }
        XCTAssertTrue(topmost("Project").exists, "back on Project, the list under Core")
        setColumns()
        let start = row("Design one").frame.minX
        app.swipeLeft()
        settle(0.8)
        XCTAssertLessThan(row("Design one").frame.minX, start, "a swipe in the board's middle scrolls it")
        edgeSwipe()
        XCTAssertTrue(isRoot, "the swipe from the edge on a scrolled board goes back")
        openProject()
        edgeSwipe()
        XCTAssertTrue(isRoot, "the swipe from the edge on a board at its start goes back")
        openProject()
        let before = row("Design one").frame.minX
        screen(0.6, 0.6).press(forDuration: 0.02, thenDragTo: screen(0.1, 0.6), withVelocity: 800,
                               thenHoldForDuration: 0.02)
        settle(1)
        XCTAssertTrue(topmost("Project").exists, "a sideways move from inside the board stays on Project")
        XCTAssertLessThan(row("Design one").frame.minX, before, "a sideways move from inside the board scrolls it")
    }

    /// The system's swipe from the edge at the tag bar's height, whose chips scroll sideways too: it goes back.
    func testSwipeBackOverTheTagBar() {
        openProject()
        let chip = app.buttons["core"].firstMatch
        XCTAssertTrue(chip.exists, "Project's tag bar shows core")
        edgeSwipe(y: chip.frame.midY / app.frame.height)
        XCTAssertTrue(isRoot, "the swipe over the tag bar went back to the Lists screen")
    }

    /// A screen laid over the list and gone, the task screen opened from a card and left by its back: the row's swipe
    /// and the drag work on the list after it, its frames written as they were.
    func testGesturesAfterAScreenOverTheList() {
        open("/view/" + Self.today)
        row("Echo today").tap()
        settle()
        app.buttons["Open full screen"].firstMatch.tap()
        settle(1)
        app.navigationBars.buttons.firstMatch.tap()
        settle(1)
        topmost("Today").tap()
        settle()
        row("Alpha today").swipeLeft()
        settle()
        XCTAssertTrue(delete(of: "Alpha today").exists, "the swipe after the task screen opens Alpha's Delete")
        topmost("Today").tap()
        settle()
        let titles = ["Alpha today", "Bravo today", "Charlie today"]
        drag(at(row("Alpha today")), to: at(row("Charlie today"), dy: 12))
        XCTAssertEqual(order(titles), ["Bravo today", "Charlie today", "Alpha today"], "the drag after the task screen")
    }

    // MARK: - Turned sideways

    /// An iPhone wide enough sideways for the pane, a Pro Max, turned with a card open: wide, Today is the pane, with
    /// no glass back and the card still open, and the split view folds the sidebar away; upright again, Today still
    /// stands over the Lists screen and a card opens. Skipped on an iPhone that stays narrow sideways;
    /// `scripts/ui-walks.sh --device "iPhone 17 Pro Max" BackWalks/testTurnedWideAndBack` runs it.
    func testTurnedWideAndBack() throws {
        let window = app.windows.firstMatch.frame
        guard min(window.width, window.height) >= Self.narrowestPhoneWideSideways else {
            throw XCTSkip("This iPhone is \(Int(min(window.width, window.height))) points across upright, too narrow "
                + "for the pane sideways; run the walk on an iPhone 17 Pro Max.")
        }
        open("/view/" + Self.today)
        row("Alpha today").tap()
        settle(0.8)
        XCTAssertGreaterThan(app.textFields.count, 0, "Alpha's card is open")
        XCUIDevice.shared.orientation = .landscapeLeft
        settle(2)
        XCTAssertTrue(topmost("Today").exists, "wide, Today is the pane")
        XCTAssertFalse(app.buttons["Back"].exists, "wide, the pane has no glass back")
        XCTAssertGreaterThan(app.textFields.count, 0, "wide, Alpha's card is still open")
        XCUIDevice.shared.orientation = .portrait
        settle(2)
        XCTAssertTrue(app.buttons["Back"].exists, "upright again, Today still stands over the Lists screen")
        topmost("Today").tap()
        settle(0.5)
        row("Bravo today").tap()
        settle(0.8)
        XCTAssertGreaterThan(app.textFields.count, 0, "upright again, a card opens")
        topmost("Today").tap()
        settle(0.5)
        app.buttons["Back"].firstMatch.tap()
        settle(1)
        XCTAssertTrue(isRoot, "the glass back went to the Lists screen")
    }

    // MARK: - Helpers

    /// A height for the swipe from the edge above the keyboard a card's field puts up, as a fraction of the screen's.
    private static let aboveTheKeyboard: CGFloat = 0.35


    /// Whether the Lists screen is on top: its "Inbox", and no glass back.
    private var isRoot: Bool {
        app.staticTexts["Inbox"].exists && !app.buttons["Back"].exists
    }

    /// Whether a list stands over the Lists screen: its glass back, which no other screen has, waited for.
    private var isListOpen: Bool {
        app.buttons["Back"].waitForExistence(timeout: 2)
    }

    /// The values of the text fields and text views on the screen.
    private var fieldValues: [String] {
        (app.textFields.allElementsBoundByIndex + app.textViews.allElementsBoundByIndex)
            .map { $0.value as? String ?? "" }
    }

    /// The rows of tasks with no title, which read "New task", their placeholder, and stand as wide as the list: the
    /// floating "+", which reads so too, is 48 points across.
    private var emptyTaskRows: Int {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task")).allElementsBoundByIndex
            .filter { $0.frame.width > 200 }.count
    }

    /// The labels of the rows and buttons left selected.
    private var selectedLabels: [String] {
        (app.cells.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex).filter(\.isSelected).map(\.label)
    }

    /// Core, opened over Project from its block's title.
    private func openCore() {
        let core = app.buttons["Core"].firstMatch
        XCTAssertTrue(core.exists, "Project shows Core's block title")
        core.tap()
        settle(1.2)
    }

    /// A card opened on `title`, `letters` typed at the end of its title, with no Return.
    private func typeAtTheEnd(of title: String, _ letters: String) {
        row(title).tap()
        let field = titleField(title)
        XCTAssertTrue(field.waitForExistence(timeout: 2), "\(title)'s card shows its title field")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        settle(1)
        app.typeText(letters)
        settle()
        XCTAssertTrue(titleField(title + letters).exists,
                      "the title reads what was typed, the fields read \(fieldValues)")
    }

    /// The list scrolled to its end, by fast swipes up.
    private func toTheEnd() {
        for _ in 0..<4 {
            app.swipeUp(velocity: .fast)
        }
        settle(1)
    }

    /// "+ Add list" at the end of the list, and `name` typed in the new list's field, with no Return.
    private func addList(named name: String) {
        toTheEnd()
        let add = app.buttons["Add list"].firstMatch
        XCTAssertTrue(add.exists, "the list ends with Add list")
        add.tap()
        settle(1.2)
        app.typeText(name)
        settle()
        XCTAssertTrue(fieldValues.contains(name),
                      "the new list's field reads what was typed, the fields read \(fieldValues)")
    }

    /// The full name of the weekday `days` after today, as a day's block in Upcoming is titled past tomorrow.
    private func weekday(daysFromToday days: Int) throws -> String {
        let calendar = Calendar.current
        let day = try XCTUnwrap(calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date())))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }
}
