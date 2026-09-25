import Testing
import TestSupport
import AppFeature
import TaskViewListFeature
import TodoCore

@Test func theDetailFollowsTheSelection() throws {
    let app = try AppModule(store: try makeStore())
    app.send(.action(.taskViewList(.rowSelected(BuiltInTaskViews.today))))
    #expect(app.model.detail?.title == "Today")
}

/// The rename is the list's, and the pane learns of it the way it learns of a peer's: from the change the
/// write produced, delivered after the `send` that wrote it has returned, which is the order the host keeps
/// (spec section 5).
@Test func theDetailFollowsARenameOfTheSelectedView() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    app.send(.action(.taskViewList(.rowSelected(BuiltInTaskViews.upcoming))))
    app.send(.action(.taskViewList(.renameMenuItemChosen(BuiltInTaskViews.upcoming))))
    app.send(.action(.taskViewList(.titleFieldChanged("Soon"))))
    let renamed = try changeSet(of: store) { app.send(.action(.taskViewList(.titleFieldSubmitted))) }
    app.send(.changed(renamed))
    #expect(app.model.detail?.title == "Soon")
}

@Test func theDetailIsDroppedWhenTheSelectedViewDisappears() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work"))
    let app = try AppModule(store: store)
    app.send(.action(.taskViewList(.rowSelected(work))))
    #expect(app.model.detail?.title == "Work", "the pane is open on the view before it goes")
    let deleted = try changeSet(of: store) { try store.delete(view: work) }
    app.send(.changed(deleted))
    #expect(app.model.detail == nil, "a pane on a view that is gone is a pane on nothing")
}

@Test func changedReachesTheTaskViewList() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    app.send(.changed(created))
    #expect(app.model.taskViewList.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash", "Docs"])
}

/// The root assembles its model out of the list's after every event, and the list inside it is private, so a
/// twin list over the same store, sent the same events, is what the root's copy is held against. The twin
/// can share only the events that write nothing: sent a Return of its own, it would write the name a second
/// time. The writes are checked by what they leave in the root's model instead, which is what a path that
/// assembled nothing would fail, since its model would still be the one from before it.
@Test func theRootModelIsRebuiltAfterEveryEvent() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    let twin = try TaskViewList(store: store)
    #expect(app.model.taskViewList == twin.model, "at launch")
    let reads: [TaskViewList.UserAction] = [
        .rowSelected(BuiltInTaskViews.today), .renameMenuItemChosen(BuiltInTaskViews.today),
        .titleFieldChanged("Tomorrow"), .titleFieldCancelled,
    ]
    for action in reads {
        app.send(.action(.taskViewList(action)))
        _ = twin.send(.action(action))
        #expect(app.model.taskViewList == twin.model, "after \(action)")
    }
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    app.send(.changed(created))
    _ = twin.send(.changed(created))
    #expect(app.model.taskViewList == twin.model, "after a view created elsewhere")

    let docs = try #require(app.model.taskViewList.rows.last { $0.title == "Docs" }?.id)
    let builtIn = ["Inbox", "Today", "Upcoming", "Logbook", "Trash"]
    for (end, title) in [(TaskViewList.UserAction.titleFieldSubmitted, "Notes"), (.titleFieldLostFocus, "Drafts")] {
        app.send(.action(.taskViewList(.renameMenuItemChosen(docs))))
        app.send(.action(.taskViewList(.titleFieldChanged(title))))
        let renamed = try changeSet(of: store) { app.send(.action(.taskViewList(end))) }
        // Left unassembled, the model would still hold the old title with the draft open over it.
        #expect(app.model.taskViewList.rows.map(\.title) == builtIn + [title], "after \(end)")
        #expect(app.model.taskViewList.rows.allSatisfy { $0.draft == nil }, "after \(end)")
        let written = app.model
        app.send(.changed(renamed))
        #expect(app.model == written, "the write's own change, arriving after it, finds nothing left to move")
    }
    let folder = try changeSet(of: store) { app.send(.action(.taskViewList(.createFolderButtonTapped))) }
    let row = try #require(app.model.taskViewList.rows.last)
    #expect(row.title == "New folder" && row.isSelected && row.draft == "New folder")
    #expect(app.model.detail?.title == "New folder", "the folder's answer opens the detail the way a click's does")
    let written = app.model
    app.send(.changed(folder))
    #expect(app.model == written, "the field stays open on the folder, and the pane on it")
}

/// Two modules name the Inbox as the first choice, the list for its highlight and the root for its detail,
/// and this is what holds the two together: a first choice moved in one of them and not the other fails
/// here, rather than opening a pane beside a highlight on another row.
@Test func theFirstDetailIsTheViewTheListHighlightsFirst() throws {
    let app = try AppModule(store: try makeStore())
    let highlighted = app.model.taskViewList.rows.first(where: \.isSelected)?.title
    #expect(highlighted == "Inbox")
    #expect(app.model.detail?.title == highlighted)
    // A person who deleted the Inbox has no first choice in either: no row is highlighted, and the read
    // answers nil, which is a view that is gone and not a read that failed, so the launch goes ahead.
    let store = try makeStore()
    try store.delete(view: BuiltInTaskViews.inbox)
    let bare = try AppModule(store: store)
    #expect(bare.model.taskViewList.rows.allSatisfy { !$0.isSelected })
    #expect(bare.model.detail == nil)
}
