// Sources/Features/TaskList/TaskList.swift
import FeatureModule
import TaskScreenFeature
import TodoCore

/// The screen of one list: its tasks as the store's page of the view lays them out, the list's own tasks first in their
/// groups and then one block per list inside it, with the tag bar, the folds and the layout the device keeps, and what
/// it declared over itself (list screen spec, sections 1, 2, 5, 7 and 9).
///
/// It is declared by the sidebar, by a choice there, and stands in its window's stack over the sidebar, drawn in the
/// pane beside it on the Mac. A tap on a row declares the task screen over it, and a tap on a block's title the list
/// inside that the block is, or the list's own group the block is, opened as a screen of its own, which is this module
/// on another route; the window's stack makes, keeps and drops what the list declared (ADR-0009, amendments of
/// 2026-10-22, 2026-11-01 and 2026-11-02): the list holds no screen and draws none, and hears what a screen over it
/// asks for as `.destinationAnswered`. Neither the sidebar nor the root learns what a list opens, and their code does
/// not grow when it learns to open something (navigation state spec, section 2).
///
/// A group's screen is the list it belongs to read for one of its own groups: the module reads the list's page and
/// draws that group's block of it, so the two always agree, and nothing stores the group or writes when it opens
/// (ADR-0004, amendment of 2026-11-02). It has no lists inside, no columns, no folds and no layout of its own.
///
/// It is a routable module (spec section 4): its head is the view it lists and, on a group's screen, the group, and its
/// tail is what it declared over itself, so that a link to a task or to a list inside declares it over the list, and
/// the route a window writes down names the whole chain.
public final class TaskList: Routable {
    /// What a view may send, each case named for the control and the gesture and never for the operation it triggers
    /// (ADR-0006). The way back from a screen over the list is not one: SwiftUI reports it only as the shorter path it
    /// wrote, which the root view sends the window whole, and the stack tells the list `.uncovered` (navigation state
    /// spec, section 3).
    public enum UserAction: Equatable, Sendable {
        /// A row of a block, or its check until #176 gives the check its own action, tapped or clicked.
        case rowTapped(TaskID)
        /// A block's title, in its header or its column's.
        case blockTitleTapped(Model.BlockID)
        /// A block's chevron, which folds and unfolds it.
        case blockChevronTapped(Model.BlockID)
        /// A chip of the tag bar.
        case tagChipTapped(TagID)
        /// An item of Show as, List or Columns.
        case showAsChosen(Model.Layout.Kind)
    }

    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)

        /// The window's stack has just made this list: sent once, right after `init`. The list was made from a route
        /// its opener declared and already knows, what stands over it included, so it has nothing to report and
        /// answers nothing.
        case created

        /// A route handed to the live list, which its opener declared again with this list's head, by a link or by a
        /// click on the list's view: an event of the world that no view can send (ADR-0006, amendment of 2026-10-14),
        /// which the stack hands the list once, as `.declared` (navigation state spec, section 2). The head of a live
        /// list never changes, so it is the tail alone that the list reads.
        case route(Route)

        /// What the screen declared over this list answered, the task screen or a list, which the stack hands the list,
        /// its opener (ADR-0009, amendment of 2026-10-22, point 2).
        case destinationAnswered(Route.Tail.Answer)

        /// The person went back to this list, and the screen over it is gone already (navigation state spec, section
        /// 3).
        case uncovered

        /// What the list declared could not be made, the task screen or a list: why, and the route of what still stands
        /// over the list, nil when nothing does, which the list takes back as its destination (navigation state spec,
        /// section 2).
        case notOpened(StoreError, stillOpen: Route.Tail?)

        /// The device's day, which the root hands every screen of its window when the window's view reports a new one,
        /// at midnight, in a new time zone or on waking on another day: an event of the world that no view can send
        /// (spec section 8; ADR-0006, amendment of 2026-11-01). Which tasks a list selects, which day each of its
        /// blocks is and which group a group's screen shows depend on the day, so a new one rereads the page; the day
        /// the list already has reads nothing. Neither is a gesture on the list, so the sentence on screen and the
        /// destination stay.
        case dayChanged(DeviceDay)
    }

    public enum Output: Equatable, Sendable {
        /// The view is gone, or the group of a group's screen names nothing any more, so the list asks its opener to
        /// close it (spec section 3; the controller's ruling on #175, 2026-11-04); the stack drops what stands over it
        /// with it.
        case closeRequested
    }

    /// What a view draws, computed from the state on every read and never kept beside it, so that what the list holds
    /// is in one place and the model cannot disagree with it (owner's review of #101).
    public var model: Model { state.model }

    /// The route the list is on, assembled and never kept beside its state (spec section 4): its own head, and as
    /// the tail what it declared. The window's stack writes the window down from what stands instead, so a
    /// declaration that has aged never reaches the text (navigation state spec, section 3).
    public var route: Route { Route(head: state.head, tail: state.destination.pushed) }

    /// What the list declared over it, the task screen, a list or nothing, which the window's stack reads after every
    /// event and follows (ADR-0009, amendment of 2026-10-22, point 2).
    public var destination: Destination<Route.Tail> { state.destination }

    private let store: Store

    private var state: State

    /// Made from its route, the one way a list is made (spec section 3): the page of the view the head names, read by
    /// the device's day, with the tags and the parents its groups name; the folds and the layout the device keeps for
    /// the list, which a group's screen keeps none of; and what the tail names declared over it, which the stack makes
    /// in the walk after the list is made.
    ///
    /// The day is the device's, which the window's stack hands the list when it makes it, the day its root has then, so
    /// that a list made after midnight starts on the new day (spec section 8). It has no default, as the root's has
    /// none: the day is the platform's to say (`docs/style.md`, "A lower layer holds no policy of its client").
    ///
    /// Throws when the page cannot be read, a view that is gone among it, which is refused with `.notFound` and the
    /// view's id: a list that came up empty would look like a view with nothing in it, and the stack keeps what was
    /// open while the list's opener says so (navigation state spec, section 2). A group that reads but names nothing,
    /// a word that is not the list's grouping or a tag or a parent that is gone, is refused the same way, with
    /// `.invalid` or `.notFound`, and the list it was declared over stays open and says why (ADR-0009, amendment of
    /// 2026-11-02). What the tail names that cannot be made does not stop the list: a link to a task that is gone opens
    /// the view it names, and the stack tells the list, which says why with nothing open over it, which is what still
    /// exists (spec section 3, the fourth flow).
    public init(store: Store, route: Route, day: DeviceDay) throws(StoreError) {
        let snapshot = try TaskList.read(store, head: route.head, today: day.day)
        if let group = route.head.group, let refusal = TaskList.refusal(of: group, in: snapshot) { throw refusal }
        let isGroup = route.head.group != nil
        self.store = store
        self.state = State(
            head: route.head, title: snapshot.page.view.title, snapshot: snapshot, day: day,
            folded: isGroup ? [] : try TaskList.keptFolds(in: store, of: route.head.view),
            layout: isGroup ? .list : try TaskList.keptLayout(in: store, of: route.head.view), picks: [],
            destination: Destination(), problem: nil
        )
        setDestination(route.tail)
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .action(.rowTapped(let id)):
            // A row the list does not draw opens nothing and moves nothing, the sentence included, the way the
            // sidebar's menu items do nothing on a row it does not hold: the tap is on something no longer on screen,
            // folded away or filtered out, and what it would open is a task this list does not show.
            guard TaskList.blocks(in: model.layout).contains(where: { $0.rows.contains { $0.id == id } }) else {
                return nil
            }
            // The sentence goes with a tap that declares, a gesture on the list itself, and it goes before the screen
            // is declared, so that one that cannot be made writes a fresh one when the stack says so: it answers this
            // tap, and the one it replaces answered something earlier.
            state.problem = nil
            setDestination(.task(TaskScreen.Route(head: id)))
            return nil
        case .action(.blockTitleTapped(let id)):
            // A title the model does not draw opens nothing, a group's screen's one block among them, whose header is
            // its screen's (spec section 2). A list inside opens as itself; one of the list's own groups as the list
            // on its group's address, by the distance from today for a day; and the own block of a list that groups by
            // nothing has no group to open. Nothing is written: the group is read from the list's page when its
            // screen is made (ADR-0004, amendment of 2026-11-02).
            guard TaskList.blocks(in: model.layout).contains(where: { block in
                [block.header?.titleTapped, block.column?.header.titleTapped].contains(.blockTitleTapped(id))
            }) else { return nil }
            let declared: Route
            switch id {
            case .list(let view):
                declared = Route(head: .init(view: view))
            case .own(let key?):
                let group = TaskList.address(of: key, by: state.snapshot.page.view.groupBy, today: state.day.day)
                declared = Route(head: .init(view: state.head.view, group: group))
            case .own(nil):
                return nil
            }
            state.problem = nil
            setDestination(.list(declared))
            return nil
        case .action(.blockChevronTapped(let id)):
            // Only a block the model draws with a chevron folds, which no column has. The fold is the one thing that
            // moves: it is the device's state and no answer to anything a person was told, so the sentence stays.
            let blocks = TaskList.blocks(in: model.layout)
            guard blocks.contains(where: { $0.header?.fold?.chevron.action == .blockChevronTapped(id) }),
                  let key = TaskList.foldKey(of: id)
            else { return nil }
            let drawn = Set(blocks.compactMap { TaskList.foldKey(of: $0.id) })
            setFolded(state.folded.intersection(drawn).symmetricDifference([key]))
            return nil
        case .action(.tagChipTapped(let tag)):
            // A chip the bar does not show picks nothing. A pick is session state, which a relaunch loses (ADR-0009,
            // amendment of 2026-11-01), and no answer to anything a person was told, so the sentence stays.
            guard model.tagBar?.chips.contains(where: { $0.action == .tagChipTapped(tag) }) == true else { return nil }
            state.picks.formSymmetricDifference([tag])
            return nil
        case .action(.showAsChosen(let layout)):
            // An item is checked against the model: Columns disabled moves nothing (spec section 5). The choice is the
            // device's, kept per list (ADR-0010), and a group's screen keeps none, its one layout being the list's. The
            // sentence stays, as for a fold.
            guard model.showAs.menu.sections.flatMap(\.items).contains(where: {
                $0.action == .showAsChosen(layout) && !$0.isDisabled
            }), layout != state.layout else { return nil }
            // A write that fails is not said, as a fold's is not: the layout stays on screen until the next list made
            // on the view reads what was kept.
            try? store.setDeviceState(TaskList.layoutKey(of: state.head.view), layout)
            state.layout = layout
            return nil
        case .created:
            // Being created answers no gesture, so it moves nothing, the sentence included.
            return nil
        case .route(let route):
            // The route's own head is not read: the stack hands a live list only a route with its head, and the head
            // of a live module never changes (spec section 3). The sentence goes at the start, as it does for a tap:
            // a route is what a link or a click in the sidebar asks of this list, and the sentence on screen
            // answered something earlier (owner, 2026-10-16). What the route names that cannot be made writes a
            // fresh one, on `.notOpened`.
            state.problem = nil
            setDestination(route.tail)
            return nil
        case .destinationAnswered(.task(.closeRequested)), .destinationAnswered(.list(.closeRequested)), .uncovered:
            // The screen over the list asked to be closed, its task or its view gone (spec section 3), or the person
            // went back to the list and the screen is gone already, and a list cannot keep a destination the person
            // closed (navigation state spec, section 3). Either way the list declares nothing over it, the stack drops
            // the screen with whatever stands over it, and the route names nothing over the list. None is a gesture on
            // the list, so the sentence stays: one written while the screen was up, by a link to a task that is gone
            // or a reread that failed, is one the person first sees now that the list is uncovered. The stack tells
            // only a list with a screen over it, so the platform's write after a pop the model drove reaches nobody.
            // The arms name each screen's one answer, so that an answer either learns to give stops this file
            // compiling until the list has decided what it means (spec section 4).
            setDestination(nil)
            return nil
        case .notOpened(let error, let stillOpen):
            // What still stands is taken back, so that the declaration is tried once and the screen that was open
            // stays (navigation state spec, section 2), and the list says why under its rows, naming what it declared,
            // which is read before what stays takes its place.
            let problem = TaskList.problem(error, declared: state.destination.pushed)
            setDestination(stillOpen)
            state.problem = problem.sentence
            return nil
        case .changed(let changes):
            do {
                // Only a change naming this view can have deleted it or renamed it, and the view's read tells. A view
                // that is gone is answered at once: the opener closes this list, and the stack drops it with what
                // stands over it (spec section 3), so a page read here would be work for nothing. A view that is
                // there gives the header its title, which stands even when the page's read below fails, since the
                // read that answered it succeeded; the rest of the view, its rule among it, is the page's, read whole
                // or not at all. A read that fails is a reread that failed, and the catch says so.
                if changes.views.contains(state.head.view) {
                    guard let view = try store.view(state.head.view) else { return .closeRequested }
                    state.title = view.title
                }
                // Every change rereads the page. It reads tasks, the tags they carry, this view's rule and the lists
                // inside it, to any depth for a folder inside, and a change names the entity it touched and not what
                // moved because of it: a list made inside this one, or under a folder inside it, names itself alone,
                // and a tag deleted empties a list filtered by it and names only the tag (`ChangeSet`). Which of them
                // moved this page is the page's to say.
                let snapshot = try TaskList.read(store, head: state.head, today: state.day.day)
                // A group's screen whose group names nothing any more, its tag or its parent gone or its list grouped
                // another way, asks to be closed, as a list whose view is gone does (the controller's ruling on #175,
                // 2026-11-04).
                if let group = state.head.group, TaskList.refusal(of: group, in: snapshot) != nil { return .closeRequested }
                try take(snapshot)
            } catch {
                // Neither the blocks on screen nor the title is cleared, since each is assigned only after its own read
                // succeeded, and a list emptied by a failed read would take with it the only thing left to act on.
                // The sentence is written only when none is on screen, as in the sidebar: a change answers for
                // nobody, so it neither clears a sentence nor replaces one, and "may be out of date" would take the
                // place of what the person was told about something they did or a link asked for.
                if state.problem == nil { state.problem = Problem.couldNotReadTasks.sentence }
            }
            // The destination stays: a screen over the list reads the change itself, handed it by the window, and asks
            // to be closed when its subject is gone. Nothing is written in answer (ADR-0009).
            return nil
        case .dayChanged(let day):
            // The day is kept whether or not the read below holds, since it is what the world says and every later
            // read of the page is by it. A read that fails leaves the blocks and says so only when nothing is on
            // screen, as a change's reread does: the day answers for nobody. A group's screen moves onto the new day's
            // group, its key being a distance (spec section 2).
            guard day != state.day else { return nil }
            state.day = day
            do {
                try take(try TaskList.read(store, head: state.head, today: day.day))
            } catch {
                if state.problem == nil { state.problem = Problem.couldNotReadTasks.sentence }
            }
            return nil
        }
    }

    /// Takes a read of the store as the page on screen, its view's title the header's, with the folds the device keeps
    /// read again beside it, so that a fold another window of this device made since is drawn here and kept by the next
    /// fold made here, as the sidebar reads its folds with its rows (ADR-0010); a group's screen keeps none. The layout
    /// is not read again: it is one value, the last one chosen wins, and a window would change its layout on a change
    /// to anything. It drops the picks whose chips are no longer on the bar, which stop filtering and come back unlit
    /// (the controller's ruling on #175, 2026-11-04). The folds are read before anything is assigned, so a read that
    /// fails leaves what is on screen.
    private func take(_ snapshot: PageSnapshot) throws(StoreError) {
        let folded = state.head.group == nil ? try TaskList.keptFolds(in: store, of: state.head.view) : []
        let blocks = TaskList.blocks(of: snapshot, head: state.head, today: state.day.day)
        let chips = TaskList.chips(in: blocks, tags: snapshot.tags)
        state.snapshot = snapshot
        state.title = snapshot.page.view.title
        state.folded = folded
        state.picks.formIntersection(chips.map(\.id))
    }

    /// Declares the task screen or a list over the list, or nothing: a tap, a route, the way back and the stack's
    /// notices each arrive here, so what a tap opens and what a link opens cannot drift apart (spec section 3). Every
    /// call is a new write, which the window's stack follows at the walk after the event.
    private func setDestination(_ tail: Route.Tail?) {
        state.destination.declare(tail.map { .pushed($0) })
    }

    /// Folds and unfolds the blocks to the set, written to the device's state first and kept after (ADR-0010), as the
    /// sidebar's folds are: only the keys of the blocks drawn now are written, so that a day's key goes once the day
    /// has no block.
    private func setFolded(_ folded: Set<String>) {
        // A write that fails is not said: the fold stays on screen until the next list made on the view reads what was
        // kept, and this module's sentences stay for the data a person edits, which a fold is not. Sorted, so that the
        // same folds are the same text in the file.
        try? store.setDeviceState(TaskList.foldedKey(of: state.head.view), folded.sorted())
        state.folded = folded
    }

    /// The blocks a layout draws, a list's or the board's columns.
    private static func blocks(in layout: Model.Layout) -> [Model.Block] {
        switch layout {
        case .list(let blocks): blocks
        case .columns(let board): board.columns
        }
    }

    /// The folded blocks of the view as the device's state keeps them, by their keys (`foldKey(of:)`). What was kept
    /// is the device's and may be stale: a key no block has now draws nothing, and the next fold writes the set back
    /// without it. A value that does not decode as a list of texts reads as nothing folded, which the store decides.
    private static func keptFolds(in store: Store, of view: ViewID) throws(StoreError) -> Set<String> {
        Set(try store.deviceState(foldedKey(of: view), as: [String].self) ?? [])
    }

    /// The layout the device keeps for the view, and the list when it keeps none.
    private static func keptLayout(in store: Store, of view: ViewID) throws(StoreError) -> Model.Layout.Kind {
        try store.deviceState(layoutKey(of: view), as: Model.Layout.Kind.self) ?? .list
    }

    /// The keys the folds and the layout of a list are kept under in the device's own state, one each per list: the
    /// module's name, what it keeps and the view's id. A write of either reports no change set, which the store's
    /// writes of a device's state never do: they are one screen's own, and another window of the same device reads
    /// them when it next makes a list on the view (spec section 9; ADR-0010).
    private static func foldedKey(of view: ViewID) -> String { "taskList.folded.\(view.rawValue)" }
    private static func layoutKey(of view: ViewID) -> String { "taskList.layout.\(view.rawValue)" }

    /// The sentence what the list declared over itself reads as when it could not be made, by what it declared.
    /// `.notFound` is what was declared being gone, which is what a link written before a delete, or a tap on a row a
    /// peer's delete has not yet reached, looks like from here: the task, the list inside, or a group's tag or parent.
    /// A group refused as `.invalid` names a grouping its list does not have, a link that outlived the grouping it
    /// names (ADR-0009, amendment of 2026-11-02). Anything else is the store failing to read what may well be there,
    /// and calling that "gone" would put on screen something that is not true (the controller's ruling on #175,
    /// 2026-11-04).
    private static func problem(_ error: StoreError, declared: Route.Tail?) -> Problem {
        switch (declared, error) {
        case (.list(let route)?, .notFound): route.head.group == nil ? .listIsGone : .groupIsGone
        case (.list(let route)?, .invalid): route.head.group == nil ? .couldNotOpenList : .notGroupedThatWay
        case (.list(let route)?, _): route.head.group == nil ? .couldNotOpenList : .couldNotOpenGroup
        case (.task?, .notFound), (nil, .notFound): .taskIsGone
        case (.task?, _), (nil, _): .couldNotReadTask
        }
    }

    /// Everything the list holds between two events: its head; its view's title, which a change naming the view gives
    /// it even when the page's read fails; the snapshot of the store the blocks, the tile and the rule are read from,
    /// and the device's day it was taken by; the folds and the layout the device keeps, and the picked tags this
    /// session keeps; what it declared over itself; and the sentence a person was last told. One value, moved field by
    /// field, and the one place any of it is kept: the model is assembled from it on every read, in `model` and
    /// nowhere else (owner's reviews of #77, #101 and #188).
    ///
    /// The destination is a field of the state, because what a screen declared over it is the navigation state, which
    /// the window's stack follows (ADR-0009, amendment of 2026-10-22, point 2).
    private struct State {
        let head: Route.Head
        var title: String
        var snapshot: PageSnapshot
        var day: DeviceDay
        var folded: Set<String>
        var layout: Model.Layout.Kind
        var picks: Set<TagID>
        var destination: Destination<Route.Tail>
        var problem: String?

        /// The model a view draws, assembled here and nowhere else: the blocks of the page, the chips of their open
        /// tasks and the rows the picked ones leave, the layout the list is shown as where Show as offers Columns and
        /// the list otherwise, a block's fold where it has a header to fold by, and the header, Show as, the empty
        /// state and the sentence.
        ///
        /// Columns are offered where the list groups or has more than one block, and never on a group's screen, which
        /// has one block and no grouping (spec section 5; the controller's ruling on #175, 2026-11-04). The empty state
        /// stands when no block has a row after the filter and the page has no lists inside (canvas, the empty state;
        /// the controller's ruling on #175, 2026-11-04).
        var model: Model {
            let view = snapshot.page.view
            let today = day.day
            let blocks = TaskList.blocks(of: snapshot, head: head, today: today)
            let chips = TaskList.chips(in: blocks, tags: snapshot.tags)
            let picked = picks.intersection(chips.map(\.id))
            let shown = blocks.map { block in
                picked.isEmpty ? block : PageBlock(
                    id: block.id, tasks: block.tasks.filter { !$0.tags.isDisjoint(with: picked) },
                    heading: block.heading, color: block.color
                )
            }
            let canBoard = head.group == nil && (view.groupBy != nil || blocks.count > 1)
            let metrics = Metrics.of(canBoard ? layout : .list)
            let color = TaskList.tileColor(view.color)
            let icon = TaskList.tileIcon(view.icon)
            let tags = TagNames(snapshot.tags)
            let hasListsInside = blocks.contains { if case .list = $0.id { true } else { false } }
            let heading = TaskList.screenHeading(
                head: head, title: title, rule: view.filter, snapshot: snapshot, today: today
            )
            let empty = shown.allSatisfy(\.tasks.isEmpty) && !hasListsInside
                ? TaskList.empty(
                    TaskList.emptyWords(head: head, view: view, tags: tags), color: color, icon: icon, metrics.empty
                )
                : nil
            return Model(
                header: TaskList.header(heading, color: color, icon: icon, metrics.header),
                tagBar: TaskList.tagBar(chips, picked: picked, colors: color.check, metrics.tagBar),
                layout: TaskList.layout(shown, title: title, folded: folded, today: today, tags: tags, metrics.blocks),
                showAs: TaskList.showAs(canBoard: canBoard),
                empty: empty,
                problem: problem
            )
        }
    }

    /// What can go wrong in this module, with the sentence each one reads as. The store's own error stays here:
    /// it names SQLite codes and journal rows, which is what a bug report is made of and not what a person can
    /// do anything about.
    private enum Problem {
        case taskIsGone
        case couldNotReadTask
        case couldNotReadTasks
        case listIsGone
        case couldNotOpenList
        case notGroupedThatWay
        case groupIsGone
        case couldNotOpenGroup

        var sentence: String {
            switch self {
            case .taskIsGone: "The task is gone."
            case .couldNotReadTask: "The task could not be read."
            case .couldNotReadTasks: "The tasks could not be read, so this list may be out of date."
            case .listIsGone: "The list is gone."
            case .couldNotOpenList: "The list could not be opened."
            case .notGroupedThatWay: "This list is not grouped that way, so the group could not be opened."
            case .groupIsGone: "The group is gone."
            case .couldNotOpenGroup: "The group could not be opened."
            }
        }
    }
}
