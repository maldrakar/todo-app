// Sources/TodoCLI/CLI.swift
import TodoCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Why a command did not run, in the words the person needs to type something else. It is the demo's own
/// error: what the core refuses arrives as a `StoreError` and is printed as it is, because a person running
/// the demo by hand is the one who can read it.
struct CLIError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}

/// The `todo` demo: the public API of `TodoCore` behind a command line, and the runnable deliverable of M1.
///
/// Only `main` is public. The executable is one line and calls it; the tests reach the rest with
/// `@testable`, so nothing else has a caller outside this module yet (`docs/style.md`, "No API without a
/// caller"). A second consumer is what widens one of them.
public enum CLI {
    static let usage = """
    usage: todo [--db PATH] <command>
      add TITLE [--when D] [--deadline D] [--parent ID] [--tag NAME]... [--notes TEXT]
      list [VIEW]
      views
      view add TITLE [--filter JSON] [--parent VIEW] [--sort FIELD[:desc]]... [--group KEY]
      show ID
      done ID | cancel ID | reopen ID
      edit ID [--title T] [--when D|none] [--deadline D|none] [--notes TEXT]
      move ID --parent PID|none [--after ID] | move ID --after ID
      tag ID NAME | untag ID NAME
      pin ID VIEW | unpin ID VIEW
      trash ID | restore ID | delete ID
      find QUERY
    D is YYYY-MM-DD. ID is a task id or any prefix of one that names a single task; VIEW is a view's title
    or a prefix of its id. FIELD is \(oneOf(SortField.allCases.map(\.rawValue))). KEY is \(oneOf(GroupBy.allCases.map(\.rawValue))).
    TODO_DB, TODO_TODAY and TODO_DEVICE override the database, the day the query is made and the device
    this copy of the database writes under.
    """

    /// The database a run opens when nothing names one: in the working directory, because a demo that writes
    /// into a home directory is a demo that is hard to throw away.
    private static let defaultDatabase = "todo.sqlite"

    /// Where the demo keeps the identity it writes under: beside the database and not in it, since a database
    /// carries its identity to every machine it is copied to and a copy is another device (ADR-0005).
    private static let deviceSuffix = ".device"

    /// The database that keeps nothing between runs. It has no file to put a device file next to.
    private static let inMemoryDatabase = ":memory:"

    /// What clears a field that has one: `--when none` and `--parent none` say in one word what an empty
    /// value cannot say on a command line.
    private static let none = "none"

    /// The options each command takes. A name that is not in this table is a typo, and a typo dropped in
    /// silence is a view created without the filter that was asked for.
    private static let accepted: [String: Set<String>] = [
        "add": ["when", "deadline", "parent", "tag", "notes"],
        "view": ["filter", "parent", "sort", "group"],
        "edit": ["title", "when", "deadline", "notes"],
        "move": ["parent", "after"],
    ]

    /// What a run reads off the command line and out of the environment before anything is opened.
    struct Invocation: Equatable {
        let path: String
        let today: Day
        let command: [String]
    }

    /// The entry point of the executable: one answer or one reason on standard output, and a code for the
    /// shell — 2 for a command the demo refused, 1 for everything else, which is the core saying no.
    public static func main(_ arguments: [String], environment: [String: String]) -> Int32 {
        do {
            let call = try invocation(arguments, environment)
            let identity = device(for: call.path, environment)
            let store = try Store.open(path: call.path, device: identity.id, now: Store.systemNow)
            // Kept after the database opened and before the command runs: a path that cannot be opened at all
            // is the core's to refuse, and an identity that cannot be kept is this one's, because the run
            // after it would be another device. The open has already recorded the minted id in `own_devices`,
            // so a run that fails here leaves a row behind and the next one mints another — the price of this
            // order, against an exit code that would otherwise blame the demo for a database it never opened.
            if !identity.kept { try keep(identity.id, for: call.path) }
            print(try run(call.command, store: store, today: call.today))
            return 0
        } catch let error as CLIError {
            print(error.description)
            return 2
        } catch {
            print("error: \(error)")
            return 1
        }
    }

    /// `--db` outranks `TODO_DB`, and it is taken out of the arguments before the command is read, so it may
    /// stand anywhere. `TODO_TODAY` is what lets a run of the demo be repeated tomorrow with the same answer.
    static func invocation(_ arguments: [String], _ environment: [String: String]) throws -> Invocation {
        var args = Array(arguments.dropFirst())
        var path = set(environment["TODO_DB"]) ?? defaultDatabase
        if let flag = args.firstIndex(of: "--db") {
            guard flag + 1 < args.count else { throw CLIError("--db needs a path") }
            path = args[flag + 1]
            args.removeSubrange(flag...(flag + 1))
        }
        return Invocation(path: path, today: try day(set(environment["TODO_TODAY"])) ?? currentDay(), command: args)
    }

    /// The device this run writes under, and whether anything already holds it. `TODO_DEVICE` first, so that
    /// one machine can play two with two exports; then the file beside the database; then a new id, which is
    /// what the first run over a database mints — and what a copy of `todo.sqlite` taken without that file
    /// mints too, which is the point of keeping it outside (#51).
    ///
    /// A database that keeps nothing between runs has nowhere to keep an identity either, so `:memory:` reads
    /// as held: there is no next run of it to be the same device as.
    static func device(for database: String, _ environment: [String: String]) -> (id: String, kept: Bool) {
        if let given = set(environment["TODO_DEVICE"]) { return (given, true) }
        if database == inMemoryDatabase { return (Store.newDeviceID(), true) }
        let kept = try? String(contentsOfFile: database + deviceSuffix, encoding: .utf8)
        if let line = kept?.split(whereSeparator: \.isNewline).first { return (String(line), true) }
        return (Store.newDeviceID(), false)
    }

    /// Writes the minted identity beside the database. A failure stops the run: a demo that cannot keep the
    /// id is a demo that is a new device on every command, and silence about that is the shape of #51.
    ///
    /// The write is not the atomic one, which `FoundationEssentials` on WASI answers with "the requested
    /// operation is not supported" — measured, and the whole wasm32 suite passes without it. The demo is
    /// built and tested on both targets, and a torn write of these 36 bytes costs no data: what it leaves is
    /// a prefix, the next run reads that prefix back as the id and goes on under it, and a prefix of a UUID
    /// names no other device. What this run wrote is still pushed, because `own_devices` holds the id it
    /// wrote under whatever the file beside the database ends up saying.
    static func keep(_ device: String, for database: String) throws {
        let path = database + deviceSuffix
        do { try device.write(toFile: path, atomically: false, encoding: .utf8) }
        catch { throw CLIError("cannot keep the device id in \(path): \(error)") }
    }

    /// A variable a shell exported without a value names neither a database nor a day, and refusing every
    /// command over one — the day is parsed before the command is read — is not what an empty string means.
    private static func set(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// Today in the local time zone: the one place in the demo that asks the platform what day it is, which
    /// is why `TODO_TODAY` exists — a test says the day instead of asking.
    private static func currentDay() -> Day {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        return Day(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    static func run(_ args: [String], store: Store, today: Day) throws -> String {
        guard let command = args.first else { throw CLIError(usage) }
        let (positionals, options) = try parse(Array(args.dropFirst()), for: command)
        switch command {
        case "add":
            let title = positionals.joined(separator: " ")
            guard !title.isEmpty else { throw CLIError("add needs a title") }
            var tags: Set<TagID> = []
            for name in options["tag"] ?? [] { tags.insert(try tag(named: name, store, create: true)) }
            // `NewTask` is immutable (`docs/style.md`), so every option is resolved before the value is built.
            let id = try store.createTask(NewTask(
                title: title,
                notes: options["notes"]?.last ?? "",
                when: try day(options["when"]?.last),
                deadline: try day(options["deadline"]?.last),
                parent: try options["parent"]?.last.map { try changeable(resolve(task: $0, store)).id },
                tags: tags
            ))
            return "added \(id) \(title)"
        case "list":
            let name = positionals.joined(separator: " ")
            let view: TaskView
            if name.isEmpty {
                // By its fixed id and not by the title `Inbox`, which a person may rename, take for another
                // view, or have renamed on another device.
                guard let inbox = try store.view(BuiltInTaskViews.inbox) else { throw CLIError("the built-in Inbox is gone; name a view") }
                view = inbox
            } else {
                view = try resolve(view: name, store)
            }
            return Format.page(try store.page(of: view.id, today: today), tags: try tagIndex(store))
        case "views":
            return Format.views(try store.views())
        case "view":
            guard positionals.first == "add" else { throw CLIError("view supports: add") }
            let title = positionals.dropFirst().joined(separator: " ")
            guard !title.isEmpty else { throw CLIError("view add needs a title") }
            let id = try store.createView(NewTaskView(
                title: title,
                parent: try options["parent"]?.last.map { try resolve(view: $0, store).id },
                filter: try options["filter"]?.last.map(filter),
                sort: try (options["sort"] ?? []).map(sortKey),
                groupBy: try options["group"]?.last.map(groupBy)
            ))
            return "added view \(id) \(title)"
        case "show":
            // A trashed task is shown, because the line that names it says so and `list Trash` is where its
            // id was read; the commands that change a task name the trash instead of hiding the task.
            let task = try resolve(task: singleID(positionals, command), store)
            let line = Format.line(task, tags: try tagIndex(store))
            let notes = try store.notes(of: task.id)
            return notes.isEmpty ? line : line + "\n" + notes
        case "done", "cancel", "reopen":
            let task = try changeable(resolve(task: singleID(positionals, command), store))
            // Past tense, the way every other command answers: `canceled <id>` is what happened, where
            // `cancel <id>` reads as the command being repeated back.
            let (status, said): (TaskStatus, String) = switch command {
            case "done": (.done, "done")
            case "cancel": (.canceled, "canceled")
            default: (.open, "reopened")
            }
            try store.update(task: task.id, [.status(status)])
            return "\(said) \(task.id)"
        case "edit":
            let task = try changeable(resolve(task: singleID(positionals, command), store))
            var changes: [TaskChange] = []
            if let title = options["title"]?.last { changes.append(.title(title)) }
            if let when = options["when"]?.last { changes.append(.when(when == none ? nil : try day(when))) }
            if let deadline = options["deadline"]?.last { changes.append(.deadline(deadline == none ? nil : try day(deadline))) }
            if let notes = options["notes"]?.last { changes.append(.notes(notes)) }
            guard !changes.isEmpty else { throw CLIError("edit needs one of --title, --when, --deadline, --notes") }
            try store.update(task: task.id, changes)
            return "updated \(task.id)"
        case "move":
            let task = try changeable(resolve(task: singleID(positionals, command), store))
            let after = try options["after"]?.last.map { try changeable(resolve(task: $0, store)).id }
            if let target = options["parent"]?.last {
                let parent = target == none ? nil : try changeable(resolve(task: target, store)).id
                try store.move(task: task.id, to: parent, at: after.map(Placement.after) ?? .end)
            } else if let after {
                // A drag inside one list says nothing about the parent, so the rank is written alone and the
                // device does not re-assert a link a peer may have moved meanwhile (`Store.move(task:at:)`).
                try store.move(task: task.id, at: .after(after))
            } else {
                throw CLIError("move needs --parent PID, --parent none or --after ID")
            }
            return "moved \(task.id)"
        case "tag", "untag":
            guard positionals.count >= 2 else { throw CLIError("\(command) needs an ID and a tag name") }
            let task = try changeable(resolve(task: positionals[0], store))
            let name = positionals[1...].joined(separator: " ")
            if command == "tag" {
                try store.add(tag: try tag(named: name, store, create: true), to: task.id)
                return "tagged \(task.id) \(name)"
            }
            try store.remove(tag: try tag(named: name, store, create: false), from: task.id)
            return "untagged \(task.id) \(name)"
        case "pin", "unpin":
            guard positionals.count >= 2 else { throw CLIError("\(command) needs an ID and a view") }
            let task = try changeable(resolve(task: positionals[0], store))
            let view = try resolve(view: positionals[1...].joined(separator: " "), store)
            if command == "pin" {
                try store.pin(task: task.id, in: view.id)
                return "pinned \(task.id) in \(view.title)"
            }
            try store.unpin(task: task.id, from: view.id)
            return "unpinned \(task.id) in \(view.title)"
        case "trash", "restore", "delete":
            let task = try resolve(task: singleID(positionals, command), store)
            switch command {
            case "trash":
                try store.trash(task: task.id)
                return "trashed \(task.id)"
            case "restore":
                try store.restore(task: task.id)
                return "restored \(task.id)"
            default:
                try store.delete(task: task.id)
                return "deleted \(task.id)"
            }
        case "find":
            let query = positionals.joined(separator: " ")
            guard !query.isEmpty else { throw CLIError("find needs a query") }
            let tags = try tagIndex(store)
            // The same widening the sidebar prints, so that a view `find` names can be opened by what it
            // printed; the built-in ids are told apart only by their last character.
            let viewNames = Format.shorten(try store.views().map(\.id))
            var lines: [String] = []
            for hit in try store.quickFind(query) {
                switch hit {
                case .task(let task): lines.append("task  " + Format.line(task, tags: tags))
                case .tag(let tag): lines.append("tag   #\(Format.oneLine(tag.title))")
                case .view(let view): lines.append("view  \(Format.oneLine(view.title))  (\(viewNames[view.id] ?? Format.short(view.id)))")
                }
            }
            for hit in try store.searchNotes(query) {
                lines.append("notes \(Format.oneLine(hit.task.title)): \(Format.oneLine(hit.snippet))  (\(Format.short(hit.task.id)))")
            }
            return lines.isEmpty ? "nothing found" : lines.joined(separator: "\n")
        case "help", "--help", "-h":
            return usage
        default:
            throw CLIError("unknown command \(command)\n" + usage)
        }
    }

    // MARK: Parsing and resolution

    /// `--name value` pairs collect into options, the last of a repeated one winning except for `--tag` and
    /// `--sort`, which are lists; everything before the first option is positional.
    ///
    /// Everything it can refuse, it refuses by name. An option this command does not take is a typo, and a
    /// typo it dropped would create a view without the filter that was asked for. An option with no value,
    /// or with another option where its value should be, is what an unquoted value looks like after the
    /// shell has split it. A word after an option is the tail of such a value — `--notes before the review`
    /// takes `before` — and joining `the review` into the title is worse than saying that it was not taken.
    private static func parse(_ args: [String], for command: String) throws -> (positionals: [String], options: [String: [String]]) {
        let accepted = accepted[command] ?? []
        var positionals: [String] = []
        var options: [String: [String]] = [:]
        var index = 0
        while index < args.count {
            let arg = args[index]
            guard arg.hasPrefix("--") else {
                guard options.isEmpty else {
                    throw CLIError("\(command) does not take \"\(arg)\" after an option; what a command takes without an option comes first, and a value that holds a space is quoted")
                }
                positionals.append(arg)
                index += 1
                continue
            }
            let name = String(arg.dropFirst(2))
            guard accepted.contains(name) else {
                let takes = accepted.isEmpty ? "" : "; it takes \(oneOf(accepted.sorted().map { "--\($0)" }))"
                throw CLIError("\(command) does not take \(arg)\(takes)")
            }
            guard index + 1 < args.count, !args[index + 1].hasPrefix("--") else { throw CLIError("\(arg) needs a value") }
            options[name, default: []].append(args[index + 1])
            index += 2
        }
        return (positionals, options)
    }

    private static func oneOf(_ names: [String]) -> String { names.joined(separator: ", ") }

    /// A date a person typed. `Day` parses strictly and its refusal names what it got, so it is passed on.
    private static func day(_ text: String?) throws -> Day? {
        guard let text else { return nil }
        do { return try Day(text) } catch { throw CLIError(error.description) }
    }

    private static func filter(_ json: String) throws -> Filter {
        do { return try Filter(json: json) } catch { throw CLIError("--filter is not a filter this app reads: \(reason(error))") }
    }

    /// `FilterError` is not a message: a store reads a filter out of a row and reports the kind to a view,
    /// where the demo is reading one off a command line and has to say why it was not taken.
    private static func reason(_ error: FilterError) -> String {
        switch error {
        case .unsupported(let kind): "unsupported \(kind)"
        case .malformed(let what): what
        }
    }

    private static func sortKey(_ text: String) throws -> SortKey {
        // Without `omittingEmptySubsequences: false` a trailing colon vanishes and `--sort title:` sorts
        // ascending, which is not what the person who typed it was asking for.
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard let name = parts.first, let field = SortField(rawValue: String(name)) else {
            throw CLIError("unknown sort field \(text); it takes \(oneOf(SortField.allCases.map(\.rawValue)))")
        }
        guard parts.count == 1 || (parts.count == 2 && parts[1] == "desc") else {
            throw CLIError("a sort key is FIELD or FIELD:desc, not \(text)")
        }
        return SortKey(field, descending: parts.count == 2)
    }

    private static func groupBy(_ text: String) throws -> GroupBy {
        guard let key = GroupBy(rawValue: text) else {
            throw CLIError("unknown group key \(text); it takes \(oneOf(GroupBy.allCases.map(\.rawValue)))")
        }
        return key
    }

    /// The one id a command takes. A word after it is a value that lost its option — `--title New name` —
    /// and editing the task with `New` while dropping `name` in silence is worse than saying so.
    private static func singleID(_ positionals: [String], _ command: String) throws -> String {
        guard let id = positionals.first, !id.isEmpty else { throw CLIError("\(command) needs an ID") }
        guard positionals.count == 1 else { throw CLIError("\(command) takes one ID; quote a value that holds a space") }
        return id
    }

    /// A task by id or by any prefix of one, trashed or not. Every task is read, because a prefix is not
    /// something the store indexes and a demo database is small; a prefix that names two is refused with
    /// the count.
    private static func resolve(task prefix: String, _ store: Store) throws -> TodoTask {
        let matches = try store.allTasks(includeTrashed: true).filter { $0.id.rawValue.hasPrefix(prefix.lowercased()) }
        switch matches.count {
        case 1: return matches[0]
        case 0: throw CLIError("no task matches \"\(prefix)\"")
        default: throw CLIError("\"\(prefix)\" matches \(matches.count) tasks, add more characters")
        }
    }

    /// A task a command may change. One in the trash is named rather than hidden: `list Trash` printed its
    /// id and `show` prints it a line earlier, so "no task matches" would be a lie about a task that is
    /// there. `trash`, `restore` and `delete` are the commands the trash is for and do not ask.
    private static func changeable(_ task: TodoTask) throws -> TodoTask {
        guard !task.trashed else { throw CLIError("task \(task.id) is in the trash; restore it first") }
        return task
    }

    /// A view by title first, since that is what a person reads in `views`, and by id prefix after it.
    /// Nothing stops two views from sharing a title, and answering with whichever the read came back with
    /// first would send `pin` and `list` to different lists on two runs of the same command.
    private static func resolve(view text: String, _ store: Store) throws -> TaskView {
        let views = try store.views()
        let byTitle = views.filter { $0.title.lowercased() == text.lowercased() }
        if byTitle.count == 1 { return byTitle[0] }
        if byTitle.count > 1 { throw CLIError("\"\(text)\" is the title of \(byTitle.count) views, name one by its id") }
        let matches = views.filter { $0.id.rawValue.hasPrefix(text.lowercased()) }
        switch matches.count {
        case 1: return matches[0]
        case 0: throw CLIError("no view matches \"\(text)\"")
        default: throw CLIError("\"\(text)\" matches \(matches.count) views, add more characters")
        }
    }

    /// A tag by name, created on first use where the command is `tag` and refused where it is `untag`: a
    /// name that does not exist is a typo, and creating a tag in order to remove it says nothing back.
    private static func tag(named name: String, _ store: Store, create: Bool) throws -> TagID {
        if let existing = try store.tags().first(where: { $0.title.lowercased() == name.lowercased() }) { return existing.id }
        guard create else { throw CLIError("no tag named \"\(name)\"") }
        return try store.createTag(title: name)
    }

    /// The tags a page or a line prints, by id. Built with a loop rather than with `uniqueKeysWithValues`,
    /// which traps on a repeated key, and two tags of one store are two rows of a table keyed by id.
    private static func tagIndex(_ store: Store) throws -> [TagID: Tag] {
        var index: [TagID: Tag] = [:]
        for tag in try store.tags() { index[tag.id] = tag }
        return index
    }
}
