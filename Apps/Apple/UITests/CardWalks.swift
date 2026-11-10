import XCTest

/// The card a tap opens in place: its title, its notes, its subtasks and the ways a new task is added.
final class CardWalks: Walk {
    /// Letters typed at the end of a card's title, then two subtasks each ended by Return, are what the card shows and
    /// what the store keeps.
    func testCardTitleAndSubtasks() {
        open("/view/" + Self.today)
        openCard("Delta today")
        titleField("Delta today").coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2), "a tap on the title brought no keyboard")
        app.typeText(" soon")
        app.buttons["Add subtask"].firstMatch.tap()
        settle(1)
        app.typeText("First sub\n")
        app.typeText("Second sub\n")
        XCTAssertEqual(titleField("Delta today").value as? String, "Delta today soon", "the title as typed")
        XCTAssertEqual(subtasks(["First sub", "Second sub"]), ["First sub", "Second sub"], "the subtasks as typed")
        relaunch()
        open("/view/" + Self.today)
        openCard("Delta today soon")
        XCTAssertEqual(titleField("Delta today").value as? String, "Delta today soon", "the title in the store")
        XCTAssertEqual(subtasks(["First sub", "Second sub"]), ["First sub", "Second sub"], "the subtasks in the store")
    }

    /// One Return writes one subtask and opens the next subtask's field with the keyboard still up; a tap on the
    /// screen's title closes the card, and the store keeps both subtasks in their order.
    func testSubtaskReturnOpensTheNext() {
        open("/view/" + Self.today)
        openCard("Charlie today")
        app.buttons["Add subtask"].firstMatch.tap()
        settle(1)
        app.typeText("Sub one\n")
        settle(1)
        XCTAssertGreaterThan(app.keyboards.count, 0, "the keyboard went down after a subtask's Return")
        app.typeText("Sub two\n")
        settle(1)
        topmost("Today").tap()
        settle()
        XCTAssertEqual(app.textFields.count, 0, "a tap on the screen's title left the card open")
        relaunch()
        open("/view/" + Self.today)
        openCard("Charlie today")
        XCTAssertEqual(subtasks(["Sub one", "Sub two"]), ["Sub one", "Sub two"], "the subtasks in the store")
    }

    /// The floating "+" writes a task first in the list's top block, a block's "+ Add task" one after its last row, and
    /// the last block's "+ Add task" one at the list's end, read back from the store.
    func testEveryAdderWritesATask() {
        open("/view/" + Self.today)
        app.buttons["New task"].firstMatch.tap()
        settle(1)
        app.typeText("From plus\n")
        XCTAssertTrue(titleField("From plus").waitForExistence(timeout: 2), "+ opened no card for the title typed")
        let add = app.buttons["Add task"].firstMatch
        scroll(to: add, "Add task")
        add.tap()
        settle(1)
        app.typeText("From add row\n")
        XCTAssertTrue(titleField("From add row").waitForExistence(timeout: 2), "+ Add task opened no card")
        open("/view/" + Self.upcoming)
        scroll(to: app.buttons["Add list"].firstMatch, "Add list")
        app.buttons.matching(identifier: "Add task").allElementsBoundByIndex.last?.tap()
        settle(1)
        app.typeText("At the list end\n")
        XCTAssertTrue(titleField("At the list end").waitForExistence(timeout: 2), "the last + Add task opened no card")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertEqual(order(["From plus", "Alpha today"]), ["From plus", "Alpha today"], "+ wrote no task first")
        scroll(to: row("Filler 14"), "Filler 14")
        XCTAssertEqual(
            order(["Filler 14", "From add row"]), ["Filler 14", "From add row"], "+ Add task wrote no task last"
        )
        open("/view/" + Self.upcoming)
        scroll(to: row("At the list end"), "the task the last + Add task wrote")
    }

    /// A task added at the list's end and given two lines of notes in its card: the row is there, and the notes read
    /// back from the store as typed.
    func testNotesOfATaskAddedAtTheEnd() {
        let lines = "Line one\nLine two"
        open("/view/" + Self.upcoming)
        scroll(to: app.buttons["Add list"].firstMatch, "Add list")
        app.buttons.matching(identifier: "Add task").allElementsBoundByIndex.last?.tap()
        settle(1.2)
        app.typeText("Added at the end")
        notesField.tap()
        settle(1)
        app.typeText(lines)
        XCTAssertEqual(notes(beginning: "Line one").value as? String, lines, "the notes as typed")
        // Leaving the notes for the title writes them: Return in the notes is a new line.
        titleField("Added at the end").tap()
        settle()
        relaunch()
        open("/view/" + Self.upcoming)
        scroll(to: row("Added at the end"), "the task added at the end in the store")
        openCard("Added at the end")
        XCTAssertEqual(notes(beginning: "Line one").value as? String, lines, "the notes in the store")
    }

    /// A done task opened from the Done strip shows its own title in the card.
    func testDoneTaskOpensFromTheStrip() {
        open("/view/" + Self.today)
        let strip = row("Done today")
        scroll(to: strip, "the Done strip")
        strip.tap()
        let done = row("Water the plants")
        XCTAssertTrue(done.waitForExistence(timeout: 2), "the strip does not hold Water the plants")
        done.tap()
        let title = titleField("Water")
        XCTAssertTrue(title.waitForExistence(timeout: 2), "the done task's card did not open")
        XCTAssertEqual(title.value as? String, "Water the plants", "the done card's title")
    }

    /// A new list's name field takes its text selected, so a name typed replaces "New list", in the store too.
    func testListNameReplacesNewList() {
        open("/view/" + Self.today)
        let add = app.buttons["Add list"].firstMatch
        scroll(to: add, "Add list")
        add.tap()
        settle(1)
        app.typeText("Named\n")
        settle(1)
        XCTAssertTrue(row("Named").exists, "the new list is not named Named")
        XCTAssertFalse(row("New listNamed").exists, "the name was typed after New list")
        relaunch()
        open("/view/" + Self.today)
        scroll(to: row("Named"), "the list named in the store")
    }

    /// Ten titles typed at test speed into new tasks, each ended by Return at once: every last letter is kept, on the
    /// screen and in the store.
    func testFastTitlesKeepTheirLastLetter() {
        open("/view/" + Self.today)
        let titles = (0..<10).map { "Quick \($0)x" }
        for title in titles {
            app.buttons["New task"].firstMatch.tap()
            settle(0.8)
            app.typeText(title + "\n")
            settle(0.8)
            topmost("Today").tap()
            settle(0.5)
        }
        XCTAssertEqual(titles.filter { !row($0).exists }, [], "titles that lost a letter")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertEqual(titles.filter { !row($0).exists }, [], "titles the store did not keep whole")
    }

    /// Twelve subtasks of one letter each, typed with their Return at once: every Return writes one, which the store
    /// keeps, and opens the next field empty.
    func testFastSubtasksKeepEveryReturn() {
        open("/view/" + Self.today)
        openCard("Charlie today")
        app.buttons["Add subtask"].firstMatch.tap()
        settle(1)
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Subtask")).firstMatch
        var left: [String] = []
        for _ in 0..<12 {
            app.typeText("q\n")
            settle(1)
            left.append(field.exists ? field.value as? String ?? "" : "no field")
        }
        // An empty field reads its placeholder as its value.
        XCTAssertEqual(left.filter { !$0.isEmpty && $0 != "Subtask" }, [], "what the next field held after a Return")
        XCTAssertEqual(app.buttons.matching(identifier: "Complete: q").count, 12, "subtasks written")
        relaunch()
        open("/view/" + Self.today)
        openCard("Charlie today")
        XCTAssertEqual(app.buttons.matching(identifier: "Complete: q").count, 12, "subtasks in the store")
    }

    /// Ten lists named at test speed through the Lists screen's "+", New List: every letter of each name is kept, on
    /// the screen and in the store. A name is read by its end, since the field adds it to "New list" (#192).
    func testFastListNamesKeepEveryLetter() {
        let names = (0..<10).map { "Quick \($0)x" }
        var lost: [String] = []
        for name in names {
            app.buttons["Add"].firstMatch.tap()
            let newList = app.buttons["New List"].firstMatch
            XCTAssertTrue(newList.waitForExistence(timeout: 2), "+ offers no New List")
            newList.tap()
            settle(0.8)
            app.typeText(name + "\n")
            if !listNamed(name).waitForExistence(timeout: 3) { lost.append(name) }
        }
        XCTAssertEqual(lost, [], "names that lost a letter")
        relaunch()
        for name in names {
            for _ in 0..<4 where !listNamed(name).exists {
                app.swipeUp()
                settle(0.5)
            }
            XCTAssertTrue(listNamed(name).exists, "the store did not keep \(name)")
        }
    }

    /// A new task's title ended by Return leaves the card open with the keyboard down, and the task is in the list and
    /// in the store.
    func testNewTaskReturn() {
        open("/view/" + Self.today)
        app.buttons["New task"].firstMatch.tap()
        settle(1)
        app.typeText("Buy milk\n")
        settle(1)
        XCTAssertTrue(titleField("Buy milk").exists, "Return closed the new task's card")
        XCTAssertEqual(app.keyboards.count, 0, "the keyboard stayed up after Return")
        topmost("Today").tap()
        settle()
        XCTAssertTrue(row("Buy milk").exists, "the new task has no row")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertTrue(row("Buy milk").waitForExistence(timeout: 2), "the store did not keep the new task")
    }

    /// A new task left empty is taken back by Return: its card closes and no untitled row is left, on the screen or in
    /// the store, read by its check, since the floating "+" reads "New task" too.
    func testEmptyNewTaskReturn() {
        open("/view/" + Self.today)
        app.buttons["New task"].firstMatch.tap()
        settle(1)
        app.typeText("\n")
        settle(1)
        XCTAssertEqual(app.textFields.count, 0, "the empty new task's card stayed open")
        XCTAssertFalse(app.buttons["Complete: New task"].exists, "an untitled row was left")
        relaunch()
        open("/view/" + Self.today)
        XCTAssertTrue(row("Alpha today").waitForExistence(timeout: 2), "Today did not open again")
        XCTAssertFalse(app.buttons["Complete: New task"].exists, "the store kept an untitled task")
    }

    /// A day's block in Upcoming folded by its chevron hides its rows, and unfolded shows them again.
    func testFoldAndUnfoldADay() {
        open("/view/" + Self.upcoming)
        XCTAssertTrue(row("Review the list screen spec").exists, "tomorrow's block does not show its task")
        app.buttons["Fold Tomorrow"].firstMatch.tap()
        settle()
        XCTAssertFalse(row("Review the list screen spec").exists, "the folded block still shows its task")
        app.buttons["Unfold Tomorrow"].firstMatch.tap()
        settle()
        XCTAssertTrue(row("Review the list screen spec").exists, "the unfolded block does not show its task")
    }

    /// With a new list's name field on screen, a card's title tapped and a letter typed: the letter goes to the end of
    /// the title, which the name field's selection does not reach, and the store keeps it after Return.
    func testTitleTypedBesideANameField() {
        open("/view/" + Self.today)
        let add = app.buttons["Add list"].firstMatch
        scroll(to: add, "Add list")
        add.tap()
        settle(1)
        scroll(to: row("Filler 14"), "Filler 14")
        openCard("Filler 14")
        titleField("Filler 14").coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        settle(1)
        app.typeText("X")
        XCTAssertEqual(titleField("Filler 14").value as? String, "Filler 14X", "the title after a letter")
        app.typeText("\n")
        relaunch()
        open("/view/" + Self.today)
        scroll(to: row("Filler 14X"), "the title with its letter in the store")
    }

    // MARK: - Helpers

    /// A task's card, opened by a tap on its row.
    private func openCard(_ title: String) {
        row(title).tap()
        XCTAssertTrue(titleField(title).waitForExistence(timeout: 2), "the card of \(title) did not open")
    }

    /// The subtasks given that the open card shows, from the top, by their checks.
    private func subtasks(_ titles: [String]) -> [String] {
        let check = { (title: String) in self.app.buttons["Complete: " + title].firstMatch }
        return titles.filter { check($0).exists }.sorted { check($0).frame.minY < check($1).frame.minY }
    }

    /// The list scrolled up until an element, called `name` in a failure, is in sight.
    private func scroll(to element: XCUIElement, _ name: String) {
        for _ in 0..<6 where !(element.exists && element.isHittable) {
            app.swipeUp()
            settle(0.5)
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(name) did not come into sight")
    }

    /// The open card's notes, by the start of what they hold: a field with text in it reads no placeholder, by which
    /// `notesField` finds an empty one.
    private func notes(beginning prefix: String) -> XCUIElement {
        app.textFields.matching(NSPredicate(format: "value BEGINSWITH %@", prefix)).firstMatch
    }

    /// A list's line on the Lists screen, by the end of its name.
    private func listNamed(_ name: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", name)).firstMatch
    }
}
