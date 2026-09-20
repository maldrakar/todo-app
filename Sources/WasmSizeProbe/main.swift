// Sources/WasmSizeProbe/main.swift
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

/// What the wasm size job measures: a client of `TodoCore` and nothing else.
///
/// It is not part of the product, nothing imports it and no platform ships it. The budget is about the web
/// client, and the `todo` demo is the wrong stand-in for one: the demo carries an argument parser, a
/// formatter and a usage text no browser will ever load, so its size says as much about `TodoCLI` as about
/// the core. This executable calls the public API the way a web entry point will — open a store in memory,
/// write through it, read a page, search, round-trip a filter, exchange a journal, take a snapshot — and
/// what a client calls is what the linker has to keep. The number the job prints is therefore the core a
/// web client cannot dead-strip its way out of shipping.
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

        print("tasks \(restoredTasks.count), tags \(try store.tags().count), views \(try store.views().count) of \(sidebar.count) at the root, roots \(roots.count)")
        print("page \(page.view.title): \(page.sections.count) sections, groups \(page.sections.flatMap(\.groups).map { label($0.key) }.joined(separator: "/")), listed \(listed.count), inbox \(inbox.sections.count)")
        print("task \(title) of \(reread) (\(tagTitle), notes \(notes.count) characters), pinned \(pinned.count), today \(today) to \(today.advanced(by: 7)) is \(today.advanced(by: 7) - today) days")
        print("quick find \(quick.count): \(quick.map(label).joined(separator: ", ")); notes search \(ranked.count), best \(ranked.first.map { "\($0.snippet) \($0.score < 0)" } ?? "none")")
        print("filter \(json.count) bytes, round-trips \(decoded == filter), sort \(SortField.allCases.count) fields, groups \(GroupBy.allCases.count)")
        print("journal \(exported.count) operations, first \(exported.first.map { "\($0.entity.rawValue).\($0.field) at \($0.clock.raw)" } ?? "none"), pair \(JournalOperation.pairID(view, review))")
        print("replay changed \(replayed.isEmpty ? 0 : replayed.tasks.count), peer took \(received.changes.tasks.count) tasks and refused \(received.refused), relay holds \(relay.log.count) after \(pushed.changes.isEmpty ? "no pull" : "a pull")")
        print("snapshot \(snapshot.count) bytes, schema \(try restored.schemaVersion()), device \(restored.deviceID.count) characters, clock \(stamp > (exported.last?.clock ?? stamp)), rank \(Rank.between(nil, Rank.initial)) valid \(Rank.isValid(Rank.initial))")
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
