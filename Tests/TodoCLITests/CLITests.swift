// Tests/TodoCLITests/CLITests.swift
import Testing
import TodoCore
@testable import TodoCLI

/// The day every command below is run on, so that `Today` and `Upcoming` mean the same thing on every run
/// and on every platform. The demo takes it from `TODO_TODAY` for the same reason.
private let today = Day(year: 2026, month: 9, day: 11)

private func makeStore() throws -> Store {
    var millis: Int64 = 1_757_500_000_000
    return try Store.openInMemory(device: Store.newDeviceID(), now: { millis += 1; return millis })
}

/// One command line, split on spaces the way a shell splits an unquoted one. A value that holds a space
/// arrives as one argument, so those commands are written out as an array instead.
@discardableResult
private func run(_ store: Store, _ line: String) throws -> String {
    try CLI.run(line.split(separator: " ").map(String.init), store: store, today: today)
}

/// The id out of `added <id> <title>`, `added view <id> <title>` and the like.
private func id(_ output: String) -> String {
    let words = output.split(separator: " ")
    return String(words[words.count > 2 && words[1] == "view" ? 2 : 1])
}

/// What a person types instead of a whole id.
private func short(_ id: String) -> String { String(id.prefix(8)) }

/// Whether one line of a page comes before another, by the text that names each of them. The order is read
/// off the lines and not out of `range(of:)`, which is Foundation's and is not there on wasm32; a text that
/// is on no line at all reads as out of order, so a page that lost a task fails the test that wanted it.
private func order(_ output: String, _ first: String, _ second: String) -> Bool {
    let lines = output.split(separator: "\n")
    guard let a = lines.firstIndex(where: { $0.contains(first) }), let b = lines.firstIndex(where: { $0.contains(second) }) else {
        return false
    }
    return a < b
}

private func lines(_ output: String) -> [String] { output.split(separator: "\n").map(String.init) }

private func message(of body: () throws -> String) -> String {
    do { _ = try body(); return "" } catch let error as CLIError { return error.description } catch { return "\(error)" }
}

@Test func addsListsAndCompletesATask() throws {
    let store = try makeStore()
    let added = try run(store, "add Buy milk")
    #expect(added.hasPrefix("added "))
    let task = id(added)
    #expect(try run(store, "list").contains("Buy milk"))
    #expect(try run(store, "list Inbox").contains(short(task)))
    #expect(try run(store, "done \(short(task))") == "done \(task)")
    let inbox = try run(store, "list Inbox")
    #expect(!inbox.contains("Buy milk"))
    #expect(try run(store, "list Logbook").contains("[x] Buy milk"))
    #expect(try run(store, "reopen \(short(task))") == "reopened \(task)")
    #expect(try run(store, "list Inbox").contains("[ ] Buy milk"))
    #expect(try run(store, "cancel \(short(task))") == "canceled \(task)")
    #expect(try run(store, "list Logbook").contains("[-] Buy milk"))
}

@Test func carriesDatesTagsAndNotes() throws {
    let store = try makeStore()
    let task = id(try CLI.run(
        ["add", "Call mom", "--when", "2026-09-11", "--deadline", "2026-09-12", "--tag", "family", "--notes", "after 6"],
        store: store, today: today
    ))
    let page = try run(store, "list Today")
    #expect(page.contains("[ ] Call mom"))
    #expect(page.contains("when 2026-09-11") && page.contains("due 2026-09-12") && page.contains("#family"))
    #expect(try run(store, "show \(short(task))").hasSuffix("after 6"))
    #expect(try run(store, "find mom").contains("task  [ ] Call mom"))
    #expect(try run(store, "find after").contains("[after] 6"))
    #expect(try run(store, "find nothingatall") == "nothing found")
}

@Test func namesEveryViewItPrints() throws {
    let store = try makeStore()
    // The five built-in ids agree on everything but the last character, so eight characters name all five
    // and none of them; a view a person made keeps the eight that do name it.
    let work = id(try run(store, "view add Work"))
    let views = try run(store, "views")
    #expect(views.contains("- Inbox  (\(BuiltInTaskViews.inbox))"))
    #expect(views.contains("- Trash  (\(BuiltInTaskViews.trash))"))
    #expect(views.contains("- Work (folder)  (\(short(work)))"))
    // Two views of one title are addressed by id, and the title alone is refused rather than guessed at.
    _ = try run(store, "view add Work")
    #expect(message(of: { try run(store, "list Work") }) == "\"Work\" is the title of 2 views, name one by its id")
    #expect(try run(store, "list \(short(work))").hasPrefix("Work (0 tasks)"))
    // A view a person named `Inbox` does not take the place of the built-in one that `list` opens.
    try run(store, "add solo")
    _ = try run(store, "view add Inbox")
    #expect(try run(store, "list").contains("solo"))
}

@Test func findNamesWhatTheNextCommandTakes() throws {
    let store = try makeStore()
    let task = id(try CLI.run(["add", "Call mom", "--tag", "family"], store: store, today: today))
    let view = try run(store, "find Inbox")
    #expect(view.contains("view  Inbox  (\(BuiltInTaskViews.inbox))"))
    #expect(try run(store, "list \(BuiltInTaskViews.inbox)").hasPrefix("Inbox ("))
    // A tag is named by its name wherever a command takes one, so the line carries no id to mistype.
    #expect(lines(try run(store, "find family")) == ["tag   #family"])
    #expect(try run(store, "find mom").contains("(\(short(task)))"))
}

@Test func keepsOneFactPerLine() throws {
    let store = try makeStore()
    let task = id(try CLI.run(
        ["add", "Report\nsecond line", "--notes", "first line\nsecond line about widgets"],
        store: store, today: today
    ))
    // A title and a note come from a person and from sync, and a newline in one of them would turn a line
    // of a page into two, with the id of the task on neither of them.
    #expect(lines(try run(store, "list Inbox")).count == 2)
    #expect(try run(store, "list Inbox").contains("Report second line"))
    #expect(lines(try run(store, "find widgets")).count == 1)
    // `show` is the one place the notes are printed as they were written.
    #expect(try run(store, "show \(short(task))").hasSuffix("first line\nsecond line about widgets"))
}

@Test func editsMovesAndRetags() throws {
    let store = try makeStore()
    let alpha = id(try run(store, "add alpha --when 2026-09-11"))
    let beta = id(try run(store, "add beta"))
    #expect(!(try run(store, "list Inbox")).contains("alpha"))
    #expect(try run(store, "edit \(short(alpha)) --when none") == "updated \(alpha)")
    #expect(try run(store, "list Inbox").contains("alpha"))
    _ = try CLI.run(["edit", short(beta), "--title", "beta prime", "--notes", "one note"], store: store, today: today)
    #expect(try run(store, "show \(short(beta))").hasPrefix("[ ] beta prime"))
    #expect(try run(store, "move \(short(beta)) --parent \(short(alpha))") == "moved \(beta)")
    let inbox = try run(store, "list Inbox")
    #expect(inbox.contains("alpha") && !inbox.contains("beta prime"))
    #expect(try run(store, "move \(short(beta)) --parent none") == "moved \(beta)")
    #expect(try run(store, "list Inbox").contains("beta prime"))
    #expect(try run(store, "tag \(short(beta)) work") == "tagged \(beta) work")
    #expect(try run(store, "show \(short(beta))").contains("#work"))
    #expect(try run(store, "untag \(short(beta)) work") == "untagged \(beta) work")
    #expect(!(try run(store, "show \(short(beta))")).contains("#work"))
    // A name that was never a tag is a typo: creating a tag in order to remove it would say nothing back.
    #expect(message(of: { try run(store, "untag \(short(beta)) nosuchtag") }) == "no tag named \"nosuchtag\"")
}

@Test func reordersInsideOneListWithoutTouchingTheParent() throws {
    let store = try makeStore()
    let alpha = id(try run(store, "add alpha"))
    try run(store, "add beta")
    let gamma = id(try run(store, "add gamma"))
    // A drag inside one list says nothing about the parent, so `--after` alone writes the rank alone.
    #expect(try run(store, "move \(short(alpha)) --after \(short(gamma))") == "moved \(alpha)")
    #expect(order(try run(store, "list Inbox"), "gamma", "alpha"))
    #expect(order(try run(store, "list Inbox"), "beta", "gamma"))
    #expect(message(of: { try run(store, "move \(short(alpha))") }) == "move needs --parent PID, --parent none or --after ID")
}

@Test func trashesRestoresAndDeletes() throws {
    let store = try makeStore()
    let task = id(try run(store, "add lost"))
    #expect(try run(store, "trash \(short(task))") == "trashed \(task)")
    #expect(!(try run(store, "list Inbox")).contains("lost"))
    #expect(try run(store, "list Trash").contains("[ ] lost"))
    #expect(try run(store, "show \(short(task))").contains("(trashed)"))
    // `show` printed it one line earlier, so "no task matches" would be a lie: say where the task is.
    #expect(message(of: { try run(store, "done \(short(task))") }) == "task \(task) is in the trash; restore it first")
    #expect(try run(store, "restore \(short(task))") == "restored \(task)")
    #expect(try run(store, "list Inbox").contains("lost"))
    #expect(try run(store, "delete \(short(task))") == "deleted \(task)")
    #expect(try run(store, "find lost") == "nothing found")
    #expect(message(of: { try run(store, "show \(short(task))") }) == "no task matches \"\(short(task))\"")
}

@Test func readsTheDatabaseAndTodayFromTheEnvironment() throws {
    let fromEnvironment = try CLI.invocation(["todo", "list", "Today"], ["TODO_DB": "/tmp/env.sqlite", "TODO_TODAY": "2026-09-11"])
    #expect(fromEnvironment == CLI.Invocation(path: "/tmp/env.sqlite", today: today, command: ["list", "Today"]))
    // The flag outranks the environment, and it is taken out of the command before the command is read.
    let fromFlag = try CLI.invocation(["todo", "--db", "/tmp/flag.sqlite", "list"], ["TODO_DB": "/tmp/env.sqlite", "TODO_TODAY": "2026-09-11"])
    #expect(fromFlag == CLI.Invocation(path: "/tmp/flag.sqlite", today: today, command: ["list"]))
    #expect(try CLI.invocation(["todo"], [:]).path == "todo.sqlite")
    // An exported but empty variable is what a shell profile leaves behind, and it names neither a database
    // nor a day: it reads as unset rather than stopping every command.
    #expect(try CLI.invocation(["todo", "views"], ["TODO_DB": "", "TODO_TODAY": ""]).path == "todo.sqlite")
    #expect(message(of: { try CLI.invocation(["todo", "list"], ["TODO_TODAY": "yesterday"]).path }) == "not a date: yesterday, expected YYYY-MM-DD")
    #expect(message(of: { try CLI.invocation(["todo", "--db"], [:]).path }) == "--db needs a path")
}

@Test func mainSaysWhatHappenedWithACode() {
    // The exit codes the README and the changelog promise: 0 for an answer, 2 for what the demo refused,
    // 1 for what the core did. `:memory:` is a database that touches no file on any platform.
    #expect(CLI.main(["todo", "--db", ":memory:", "views"], environment: [:]) == 0)
    #expect(CLI.main(["todo", "--db", ":memory:", "frobnicate"], environment: [:]) == 2)
    #expect(CLI.main(["todo", "--db", "/no/such/directory/todo.sqlite", "views"], environment: [:]) == 1)
}

@Test func refusesWhatItCannotDo() throws {
    let store = try makeStore()
    #expect(message(of: { try run(store, "done zzz") }) == "no task matches \"zzz\"")
    #expect(message(of: { try run(store, "frobnicate") }).hasPrefix("unknown command frobnicate"))
    #expect(message(of: { try run(store, "list Nowhere") }) == "no view matches \"Nowhere\"")
    #expect(message(of: { try run(store, "add") }) == "add needs a title")
    #expect(message(of: { try run(store, "done") }) == "done needs an ID")
    #expect(message(of: { try run(store, "done zzz yyy") }).hasPrefix("done takes one ID"))
    #expect(message(of: { try CLI.run(["view", "add", "Bad", "--sort", "nonsense"], store: store, today: today) }).hasPrefix("unknown sort field nonsense"))
    // The fields it would have taken, since a person who typed the wrong one is guessing at the list.
    #expect(message(of: { try CLI.run(["view", "add", "Bad", "--sort", "nonsense"], store: store, today: today) }).contains("deadline"))
    #expect(message(of: { try CLI.run(["view", "add", "Bad", "--sort", "title:"], store: store, today: today) }).hasPrefix("a sort key is FIELD or FIELD:desc"))
    #expect(message(of: { try CLI.run(["view", "add", "Bad", "--group", "nonsense"], store: store, today: today) }).hasPrefix("unknown group key nonsense"))
    #expect(message(of: { try CLI.run(["view", "add", "Bad", "--filter", "{"], store: store, today: today) }).hasPrefix("--filter is not a filter"))
    #expect(message(of: { try run(store, "view list") }) == "view supports: add")
    #expect(message(of: { try run(store, "find") }) == "find needs a query")
    #expect(try run(store, "help") == CLI.usage)
    #expect(CLI.usage.contains("todo [--db PATH] <command>"))
    // Twenty ids over sixteen possible first characters: whatever the random ids are, two of them share one.
    let ids = try (1...20).map { id(try run(store, "add task\($0)")) }
    let ambiguous = ids.map { String($0.prefix(1)) }.first { prefix in ids.filter { $0.hasPrefix(prefix) }.count > 1 }
    #expect(message(of: { try run(store, "done \(ambiguous ?? "")") }).hasSuffix("tasks, add more characters"))
}

@Test func refusesOptionsItCannotRead() throws {
    let store = try makeStore()
    // `--notes before the review` takes `before` and would leave `the review` to join the title in silence.
    #expect(message(of: { try run(store, "add Buy milk --notes before the review") }).contains("a value that holds a space is quoted"))
    // A misspelled option asked for a filtered view and would have created a folder.
    #expect(message(of: { try run(store, "view add Open --filtr {}") }).hasPrefix("view does not take --filtr"))
    #expect(message(of: { try run(store, "list --all") }).hasPrefix("list does not take --all"))
    #expect(message(of: { try run(store, "add Buy milk --tag") }) == "--tag needs a value")
    // The next option is not a value: this created a tag named `--notes` and lost the note.
    #expect(message(of: { try run(store, "add Groceries --tag --notes urgent") }) == "--tag needs a value")
    #expect(try run(store, "add Buy milk --when 2026-09-11").hasPrefix("added "))
    #expect(try run(store, "list Today").contains("Buy milk"))
}

@Test func theDemoKeepsOneIdentityPerDatabase() throws {
    // The identity belongs to the installation and not to the bytes (ADR-0005), so the demo keeps it in a
    // file next to the database: a `todo.sqlite` copied without that file is another device, which is what
    // #51 asks of whoever copies one.
    let path = ".build/todo-cli-test-\(EntityID().rawValue).sqlite"
    let first = CLI.device(for: path, [:])
    #expect(!first.kept, "nothing holds it yet")
    try CLI.keep(first.id, for: path)

    let second = CLI.device(for: path, [:])
    #expect(second.id == first.id, "a second run over the same database is the same device")
    #expect(second.kept)
    #expect(CLI.device(for: path + ".copy", [:]).id != first.id, "a copy without the file beside it is another device")

    let given = CLI.device(for: path, ["TODO_DEVICE": "given"])
    #expect(given.id == "given", "the environment outranks the file, the way TODO_DB outranks the default")
    #expect(given.kept)
    #expect(CLI.device(for: ":memory:", [:]).kept, "a database that keeps nothing keeps no identity either")
}

@Test func aRunThatMintsAnIdentityKeepsIt() throws {
    // `CLI.main` is what wires the two together, and the wiring is one line: without it every command is a
    // new device, which is what the demo's own database would then show as a row per run in `own_devices`.
    let path = ".build/todo-cli-main-\(EntityID().rawValue).sqlite"
    #expect(CLI.main(["todo", "--db", path, "add", "kept"], environment: [:]) == 0)
    let after = CLI.device(for: path, [:])
    #expect(after.kept, "the run that minted the id wrote it beside the database")
    #expect(CLI.main(["todo", "--db", path, "add", "again"], environment: [:]) == 0)
    #expect(CLI.device(for: path, [:]).id == after.id, "the second run is the same device as the first")
}
