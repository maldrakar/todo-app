// Sources/WasmSizeProbe/main.swift
import AppFeature
import FeatureModule
import TodoCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

/// What the wasm size job measures: the root module and the core a web client ships with it.
///
/// It is not part of the product, nothing imports it and no platform ships it. The budget is about the web client, and
/// the `todo` demo is the wrong stand-in for one: the demo carries an argument parser, a formatter and a usage text no
/// browser will ever load, so its size says as much about `TodoCLI` as about the core. This executable does what a web
/// entry point will: it builds the root module over a store in memory from a window's path, which is the web's address
/// bar, and drives every module of the window — a selection, a rename, a new list, a list made inside it, a fold, a new
/// area, Move to… into it, a drop back to the root and New task in the sidebar, a link applied as `.route` through the
/// window's stack, quick entry creating a task, a tap in the list sent to its element of the stack, which pushes the
/// task, the way back as the shorter path, the window narrowing, Cancel, and Open in New Window, whose path it writes
/// down — with the change each write produced, and a path the routes refuse, and it reads the layout the root cuts for
/// the window's width and the sidebar's rows, the tiles built for that width among them. Beside that it calls the
/// core's public API directly, and each group of calls has a client that ships it. The writes, the reads, a page and
/// search are what the modules M3 adds will call. The filter codec and the journal exchange are the web host's own,
/// which is where the spec leaves the gaps #23 found in them ("Goals and non-goals"). The snapshot is what a web page
/// persists, reopened under the platform clock a web entry point passes. A group dropped because no module makes its
/// calls would take out code the web client still ships. What a client calls is what the linker has to keep, so the
/// number the job prints is the root module and the core a web client cannot dead-strip its way out of shipping.
///
/// Every value it produces reaches a `print`. A result nobody reads is a call the optimizer may delete, and
/// a deleted call is a measurement of a binary nobody will ship.
private enum WasmSizeProbe {
    /// The clock the stores are opened with: a fixed one, because the probe asserts nothing about time and a
    /// platform clock is one more thing that differs between the host build and the wasm build (#53).
    /// `HybridClock` counts inside the millisecond, so stamps still order. The one store opened with
    /// `Store.systemNow` instead is the exception, and it is there because a web client opens its store that
    /// way and the platform clock has to be in the measurement.
    private static let fixedNow: Int64 = 1_760_000_000_000

    // `private` would be the type's own scope and the top-level code below is outside it, so this is as
    // tight as the call site allows.
    fileprivate static func run() throws {
        let today = try Day("2026-09-20")
        let store = try Store.openInMemory(device: Store.newDeviceID(), now: { fixedNow })
        var notified = 0
        store.onChange = { _ in notified += 1 }

        // Writes: the tags, tasks and views a person builds, and every way of editing one.
        let work = try store.createTag(title: "work")
        let inside = try store.createTag(title: "inside", parent: work, at: .start)
        try store.update(tag: inside, [.title("deep work")])
        try store.move(tag: inside, to: nil, at: .end)
        try store.move(tag: inside, at: .after(work))
        let review = try store.createTask(NewTask(title: "Review the spec", notes: "the wasm size budget", when: today, tags: [work]))
        let ship = try store.createTask(NewTask(title: "Ship the web client", deadline: today.advanced(by: 7), parent: review), at: .start)
        try store.update(task: ship, [.title("Ship the web client"), .status(.done), .when(nil)])
        try store.move(task: ship, to: nil, at: .after(review))
        try store.move(task: ship, at: .start)
        try store.add(tag: inside, to: ship)
        try store.remove(tag: inside, from: ship)
        let gone = try store.createTag(title: "gone")
        try store.delete(tag: gone)
        let scratch = try store.createTask(NewTask(title: "Scratch"))
        try store.trash(task: scratch)
        try store.restore(task: scratch)
        try store.delete(task: scratch)

        // A view is a filter, a sort and a grouping, and a manual list on top of them.
        let filter = Filter.and([.status([.open, .done]), .not(.hasTag(inside)), .parent(nil), .trashed(false), .or([.when(.onOrBefore(0)), .deadline(.between(0, 7)), .listedIn(BuiltInTaskViews.inbox)])])
        let folder = try store.createView(NewTaskView(title: "Folder"))
        let view = try store.createView(NewTaskView(title: "Work", parent: folder, filter: filter, sort: [SortKey(.when), SortKey(.title, descending: true)], groupBy: .status), at: .start)
        try store.update(view: view, [.title("Work, open"), .sort([SortKey(.rank)]), .groupBy(.status), .filter(filter)])
        try store.move(view: view, to: nil, at: .after(folder))
        try store.pin(task: review, in: view, at: .start)
        try store.pin(task: ship, in: view)
        try store.unpin(task: ship, from: view)
        try store.delete(view: folder)

        // Reads: a page, the flat list behind a picker, the sidebar, and one task with its notes.
        let page = try store.page(of: view, today: today)
        let inbox = try store.page(of: BuiltInTaskViews.inbox, today: today)
        let listed = try store.tasks(in: view, today: today)
        let reread = try store.view(view)?.title ?? ""
        let sidebar = try store.children(ofView: nil)
        let roots = try store.children(of: nil, includeTrashed: true)
        let notes = try store.notes(of: review)
        let title = try store.task(review)?.title ?? ""
        let tagTitle = try store.tag(work)?.title ?? ""
        let pinned = try store.manualList(of: view)

        // Search: the two the search field needs, and the kinds they answer with.
        let quick = try store.quickFind("spec", limit: 10)
        let ranked = try store.searchNotes("wasm", limit: 10)

        // The filter codec, which is how a view built in the browser reaches a peer and comes back.
        let json = String(decoding: try JSONEncoder().encode(filter), as: UTF8.self)
        let decoded = try Filter(json: json)

        // Sync: the journal out, a peer taking it, and a round through a transport.
        let exported = try store.journal(after: 0, limit: 1_000)
        let replayed = try store.apply(exported)
        let peer = try Store.openInMemory(device: Store.newDeviceID(), now: { fixedNow })
        let received = try peer.receive(exported)
        let relay = InMemoryRelay()
        let pushed = try SyncEngine.sync(store, via: relay)

        // The snapshot a page persists, reopened under the clock a web entry point passes (`Store.systemNow`).
        let snapshot = try store.snapshot()
        let restored = try Store.openInMemory(snapshot: snapshot, device: Store.newDeviceID(), now: Store.systemNow)
        let restoredTasks = try restored.allTasks(includeTrashed: true)
        let clock = HybridClock(now: { fixedNow })
        if let seen = exported.last?.clock { clock.observe(seen) }
        let stamp = clock.next()

        // The root module, driven as a web client will drive it. The store is its own, because a host owns
        // its store's `onChange` and the first store's is already counting. A change a write produces is
        // queued and delivered after the `send` that wrote it has returned, which is the one rule the host
        // holds (spec section 5): delivered from inside `onChange`, it would reach the root in the middle
        // of the update that caused it.
        let appStore = try Store.openInMemory(device: Store.newDeviceID(), now: { fixedNow })
        var pending: [ChangeSet] = []
        appStore.onChange = { pending.append($0) }
        // Made wide, as a browser window opens, and narrowed further down, so that the layout the root cuts by the
        // width, and the sidebar's tiles, are in the measurement in both their shapes.
        let app = try AppModule(store: appStore, route: try AppModule.Route(path: "/"), width: .wide)
        @discardableResult
        func perform(_ event: AppModule.Event) -> AppModule.Output? {
            let output = app.send(event)
            while !pending.isEmpty { _ = app.send(.changed(pending.removeFirst())) }
            return output
        }
        perform(.action(.taskViewList(.rowSelected(BuiltInTaskViews.today))))
        perform(.action(.taskViewList(.renameMenuItemChosen(BuiltInTaskViews.today))))
        perform(.action(.taskViewList(.titleFieldChanged("Today, open"))))
        perform(.action(.taskViewList(.titleFieldSubmitted)))
        let renamed = highlightedTitle(in: app.model) ?? "none"
        // New list from "+", named as it opens; a list made inside it, which takes its colour and unfolds it; the
        // outer list folded by its chevron; an area from "+", left unnamed, which an area may be; and New task, which
        // the sidebar asks the root for and the root answers with quick entry, which the link below keeps up. The
        // sidebar is read before the window narrows and after, through one switch over a row's kinds.
        perform(.action(.taskViewList(.newListMenuItemChosen(in: nil))))
        let newList = app.model.taskViewList.rows.first { $0.draft != nil }
        perform(.action(.taskViewList(.titleFieldSubmitted)))
        if let newList {
            perform(.action(.taskViewList(.newListMenuItemChosen(in: newList.id))))
            perform(.action(.taskViewList(.titleFieldSubmitted)))
            perform(.action(.taskViewList(.disclosureTapped(newList.id))))
        }
        perform(.action(.taskViewList(.newAreaMenuItemChosen)))
        let newArea = app.model.taskViewList.rows.first { $0.draft != nil }
        perform(.action(.taskViewList(.titleFieldSubmitted)))
        // Move to… on the outer list, its picker read through one switch over its rows' kinds, as the picker's view
        // has, and a tap on the new area's line, which moves the list into the area; then the list let go after Today
        // at the root's depth, which the sidebar reads into a parent and a place.
        var picker = "no picker"
        var dropped = "nowhere"
        if let newList, let newArea {
            perform(.action(.taskViewList(.moveToMenuItemChosen(newList.id))))
            picker = pickerLine(of: app.model)
            perform(.action(.taskViewList(.movePickerRowTapped(newArea.id))))
            perform(.action(.taskViewList(.rowDropped(newList.id, after: BuiltInTaskViews.today, depth: 0))))
            dropped = app.model.taskViewList.rows.firstIndex { $0.id == newList.id }.map { "at row \($0)" } ?? "gone"
        }
        perform(.action(.taskViewList(.newTaskMenuItemChosen)))
        let askedForQuickEntry = app.model.quickEntry != nil
        let wideSidebar = sidebarLine(of: app.model)
        // A link, read from its path and followed through the window's stack, with quick entry up over the Inbox;
        // quick entry files a task, whose change reaches the list; a tap on the list's element, in the column,
        // pushes the task, and the way back, the detail's path one shorter, which is empty, pops it and leaves the
        // list; the window narrows, which moves the layout alone; quick entry opened again is cancelled; and a view
        // asks for a window of its own, whose route is written down. The layout is read for what stands over the
        // sidebar, each id and its screen's model, and printed through one switch over its shapes, as the root view
        // draws it.
        perform(.route(try AppModule.Route(path: "/view/\(BuiltInTaskViews.inbox)?quick-entry")))
        perform(.action(.quickEntry(.titleFieldChanged("Buy milk"))))
        perform(.action(.quickEntry(.addButtonTapped)))
        let list = idsOverTheSidebar(in: app.model.layout).first
        let filed = list.flatMap { firstRow(of: app.model.screens[$0]) }
        if let list, let filed { perform(.action(.screen(list, .list(.rowTapped(filed.id))))) }
        let taskRoute = app.route.path
        let opened = label(idsOverTheSidebar(in: app.model.layout).last.flatMap { app.model.screens[$0] })
        perform(.action(.wentBack(to: [])))
        perform(.widthChanged(.narrow))
        let narrowSidebar = sidebarLine(of: app.model)
        perform(.action(.quickEntryButtonTapped))
        let drafted = app.model.quickEntry?.draft ?? "none"
        perform(.action(.quickEntry(.cancelButtonTapped)))
        let window: String
        switch perform(.action(.taskViewList(.openInNewWindowMenuItemChosen(BuiltInTaskViews.today)))) {
        case .openWindow(let route)?: window = route.path
        case nil: window = "none"
        }
        let root = app.model
        let refusal: RouteError?
        do {
            _ = try AppModule.Route(path: "/view/inbox")
            refusal = nil
        } catch {
            refusal = error
        }

        print("tasks \(restoredTasks.count), tags \(try store.tags().count), views \(try store.views().count) of \(sidebar.count) at the root, roots \(roots.count)")
        print("page \(page.view.title): \(page.sections.count) sections, groups \(page.sections.flatMap(\.groups).map { label($0.key) }.joined(separator: "/")), listed \(listed.count), inbox \(inbox.sections.count)")
        print("task \(title) of \(reread) (\(tagTitle), notes \(notes.count) characters), pinned \(pinned.count), today \(today) to \(today.advanced(by: 7)) is \(today.advanced(by: 7) - today) days")
        print("quick find \(quick.count): \(quick.map(label).joined(separator: ", ")); notes search \(ranked.count), best \(ranked.first.map { "\($0.snippet) \($0.score < 0)" } ?? "none")")
        print("filter \(json.count) bytes, round-trips \(decoded == filter), sort \(SortField.allCases.count) fields, groups \(GroupBy.allCases.count)")
        print("journal \(exported.count) operations, first \(exported.first.map { "\($0.entity.rawValue).\($0.field) at \($0.clock.raw)" } ?? "none"), pair \(JournalOperation.pairID(view, review))")
        print("replay changed \(replayed.isEmpty ? 0 : replayed.tasks.count), peer took \(received.changes.tasks.count) tasks and refused \(received.refused), relay holds \(relay.log.count) after \(pushed.changes.isEmpty ? "no pull" : "a pull")")
        print("snapshot \(snapshot.count) bytes, schema \(try restored.schemaVersion()), device \(restored.deviceID.count) characters, clock \(stamp > (exported.last?.clock ?? stamp)), rank \(Rank.between(nil, Rank.initial)) valid \(Rank.isValid(Rank.initial))")
        print("root \(root.taskViewList.rows.count) rows, renamed \(renamed), new list \(newList?.draft ?? "none"), quick entry from the sidebar \(askedForQuickEntry), problem \(root.taskViewList.problem != nil)")
        print("sidebar wide \(wideSidebar); narrow \(narrowSidebar)")
        print("picker \(picker), then dropped \(dropped)")
        print("route \(app.route.path), filed \(filed?.title ?? "none") and pushed \(opened) at \(taskRoute), \(label(root.layout, screens: root.screens)), quick entry \(drafted.isEmpty ? "empty" : drafted) then \(root.quickEntry == nil ? "closed" : "open")")
        print("window \(window), refused \(refusal == .notAnID("inbox"))")
        print("notified \(notified) times, system clock \(Store.systemNow() > 0), statuses \(TaskStatus.allCases.count), kinds \(EntityKind.allCases.count)")
    }

    /// A group key as a list header would read it. The core keys a group by the field it grouped on and
    /// leaves the wording to the client, which is the one thing about a page a client cannot skip writing.
    private static func label(_ key: GroupKey?) -> String {
        switch key {
        case .day(let day): day.map(\.description) ?? "someday"
        case .tag(let tag): tag.map(\.rawValue) ?? "untagged"
        case .parent(let parent): parent.map(\.rawValue) ?? "root"
        case .status(let status): "status \(status.rawValue)"
        case nil: "everything"
        }
    }

    /// What a screen of the window's stack shows, whichever kind it is: one switch over the kinds, as the root
    /// view's, and one line here.
    private static func label(_ screen: AppModule.ScreenModel?) -> String {
        switch screen {
        case .list(let list)?: "a list of \(list.rows.count) rows"
        case .task(let task)?: "the task \(task.title)"
        case nil: "nothing"
        }
    }

    /// The window's layout as a line, its shape and what stands in it: one switch over the shapes, as the root
    /// view's, and one line here.
    private static func label(_ layout: AppModule.Layout, screens: [StackElementID: AppModule.ScreenModel]) -> String {
        switch layout {
        case .narrow(let path):
            "narrow, \(path.map { label(screens[$0]) }.joined(separator: " under ")) over the sidebar"
        case .wide(let column, let path):
            "wide, \(label(column.flatMap { screens[$0] })) in the column and \(path.count) over it"
        }
    }

    /// The ids of the screens standing over the sidebar, bottom up, whichever the shape of the layout: the column,
    /// when a screen stands there, before the path.
    private static func idsOverTheSidebar(in layout: AppModule.Layout) -> [StackElementID] {
        switch layout {
        case .narrow(let path): path
        case .wide(let column?, let path): [column] + path
        case .wide(nil, let path): path
        }
    }

    /// The title of the sidebar's highlighted row, and nil when none is: one switch over a row's kinds, as the
    /// sidebar's view has, an area's line never highlighted.
    private static func highlightedTitle(in model: AppModule.Model) -> String? {
        for row in model.taskViewList.rows {
            switch row.kind {
            case .list(let list) where list.isSelected: return list.title
            case .list, .area: continue
            }
        }
        return nil
    }

    /// The sidebar as a line: how many lists it draws and how many of them are folded, its areas by their labels, and
    /// the first list's tile, count and title: one switch over a row's kinds, as the sidebar's view has.
    private static func sidebarLine(of model: AppModule.Model) -> String {
        var lists = 0
        var folded = 0
        var areas: [String] = []
        var first = "no list"
        for row in model.taskViewList.rows {
            switch row.kind {
            case .area(let label):
                areas.append(label ?? "unnamed")
            case .list(let list):
                if lists == 0 {
                    let count = list.countText.isEmpty ? "uncounted" : list.countText
                    let emphasis = list.titleFont.weight == .regular ? "plain" : "emphasized"
                    let tile = "\(list.tile.side) pt \(list.tile.color.rawValue) \(list.tile.glyph.icon.rawValue) tile"
                    first = "\(list.title) \(count) on a \(tile), \(emphasis), at \(row.depth)"
                }
                lists += 1
                if list.isCollapsed { folded += 1 }
            }
        }
        return "\(lists) lists, \(folded) folded, areas \(areas.joined(separator: " and ")), first \(first)"
    }

    /// The move picker as a line: its title, how many rows it offers and how many of them are greyed out, and the
    /// present parent, by its label or title, or "Top level": one switch over a row's kinds, as the picker's view has.
    private static func pickerLine(of model: AppModule.Model) -> String {
        guard let picker = model.taskViewList.movePicker else { return "no picker" }
        var current = picker.isTopLevelCurrent ? "Top level" : "nothing"
        for pickerRow in picker.rows where pickerRow.isCurrent {
            switch pickerRow.row.kind {
            case .area(let label): current = label ?? "an unnamed area"
            case .list(let list): current = list.title
            }
        }
        let greyed = picker.rows.filter(\.isDisabled).count
        return "\(picker.title) of \(picker.rows.count) rows, \(greyed) greyed out, in \(current)"
    }

    /// The first row of a list standing in the window's stack, which the probe taps, and nil for any other screen.
    private static func firstRow(of screen: AppModule.ScreenModel?) -> (id: TaskID, title: String)? {
        switch screen {
        case .list(let list)?: list.rows.first.map { ($0.id, $0.title) }
        case .task?, nil: nil
        }
    }

    /// The title of a quick-find hit, whichever of the three kinds it is: one list on screen, one line here.
    private static func label(_ hit: QuickFindHit) -> String {
        switch hit {
        case .task(let task): task.title
        case .tag(let tag): tag.title
        case .view(let view): view.title
        }
    }
}

do {
    try WasmSizeProbe.run()
} catch {
    // The probe has no input and no environment, so nothing here is a person's mistake: a failure is the
    // core refusing something a client is entitled to do, and a binary measured in that state is a binary
    // whose calls the linker dropped. It exits non-zero so that a run which measured nothing says so.
    print("probe failed: \(error)")
    exit(1)
}
