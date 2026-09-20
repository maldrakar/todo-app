// Sources/TodoCLI/Format.swift
import TodoCore

/// One fact per line, so that a person reads an answer and a script cuts it with `awk`. Every line that
/// names a task or a view ends with an id the next command takes; a tag is named by its name everywhere a
/// command takes one, so its line carries no id at all.
enum Format {
    /// The first eight characters of a task id: short enough to type and, in a database one person fills by
    /// hand, long enough to name one task. A prefix that names two is refused with the count (`CLI.resolve`).
    static func short(_ id: EntityID) -> String { String(id.rawValue.prefix(8)) }

    /// The shortest prefix of at least eight characters that names one id among these, per id, or the whole
    /// id where nothing shorter does. The five built-in views hold fixed ids that agree on everything but
    /// the last character, so they print whole while a view a person made still prints eight. Quadratic in
    /// the number of ids, which is a sidebar: the tasks of a page are named by `short` instead.
    static func shorten(_ ids: [EntityID]) -> [EntityID: String] {
        let raw = ids.map(\.rawValue)
        var names: [EntityID: String] = [:]
        for id in ids {
            let width = (8...36).first { width in
                let candidate = String(id.rawValue.prefix(width))
                return raw.filter { $0.hasPrefix(candidate) }.count == 1
            }
            names[id] = String(id.rawValue.prefix(width ?? 36))
        }
        return names
    }

    /// A title, a tag name or a snippet on one line. All three are typed by a person and arrive from sync,
    /// and a newline inside one would split the line that names a task, leaving its id on a line of its own
    /// and a script reading half a fact (`docs/style.md`, "Data from outside").
    static func oneLine(_ text: String) -> String {
        String(text.map { $0 == "\n" || $0 == "\r" || $0 == "\t" ? " " : $0 })
    }

    static func line(_ task: TodoTask, tags: [TagID: Tag]) -> String {
        let box: String = switch task.status {
        case .open: "[ ]"
        case .done: "[x]"
        case .canceled: "[-]"
        }
        var parts = ["\(box) \(oneLine(task.title))"]
        if let when = task.when { parts.append("when \(when)") }
        if let deadline = task.deadline { parts.append("due \(deadline)") }
        // By name and not by id: a person reads the names, and two runs of the same command print one order.
        for name in task.tags.map({ name(of: $0, in: tags) }).sorted() { parts.append("#\(name)") }
        if task.trashed { parts.append("(trashed)") }
        parts.append("(\(short(task.id)))")
        return parts.joined(separator: "  ")
    }

    /// A tag the store no longer holds prints as its id rather than disappearing: the line says what the
    /// task carries, and a tag and the tasks tagged with it are two reads that a write can fall between.
    static func name(of tag: TagID, in tags: [TagID: Tag]) -> String { oneLine(tags[tag]?.title ?? tag.rawValue) }

    /// A page: the view, its sections — one per child view, then whatever the view itself selected — and the
    /// groups inside them. A section a newer app wrote draws empty and names what it needs, the way the core
    /// hands it over, because its siblings are lists that have nothing to do with it.
    static func page(_ page: TaskViewPage, tags: [TagID: Tag]) -> String {
        let count = page.sections.flatMap(\.groups).flatMap(\.tasks).count
        var lines = ["\(oneLine(page.view.title)) (\(count == 1 ? "1 task" : "\(count) tasks"))"]
        for section in page.sections {
            if let view = section.view { lines.append("## \(oneLine(view.title))\(needsNewerApp(view))") }
            for group in section.groups {
                if let key = group.key { lines.append("# \(label(key, tags: tags))") }
                for task in group.tasks { lines.append("  " + line(task, tags: tags)) }
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func label(_ key: GroupKey, tags: [TagID: Tag]) -> String {
        switch key {
        case .day(let day): day.map { "\($0)" } ?? "no date"
        case .tag(let tag): tag.map { "#" + name(of: $0, in: tags) } ?? "no tag"
        case .parent(let parent): parent.map { "in \(short($0))" } ?? "at the root"
        case .status(let status): "\(status)"
        }
    }

    /// The sidebar. `views()` gives parents before children, so one pass carries the depth of every view.
    static func views(_ views: [TaskView]) -> String {
        let names = shorten(views.map(\.id))
        var depth: [ViewID: Int] = [:]
        return views.map { view in
            let level = view.parent.flatMap { depth[$0] }.map { $0 + 1 } ?? 0
            depth[view.id] = level
            let kind = view.needsNewerApp == nil && view.filter == nil ? " (folder)" : needsNewerApp(view)
            return String(repeating: "  ", count: level) + "- \(oneLine(view.title))\(kind)  (\(names[view.id] ?? short(view.id)))"
        }.joined(separator: "\n")
    }

    /// A view this version cannot read carries no filter either, so what it needs is said before anything
    /// calls it a folder.
    private static func needsNewerApp(_ view: TaskView) -> String {
        view.needsNewerApp.map { " (needs a newer app: \($0))" } ?? ""
    }
}
