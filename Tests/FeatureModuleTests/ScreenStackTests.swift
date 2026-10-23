import Testing
import FeatureModule

/// What the stub factory throws for a head of 99, of either kind, the way a screen's `init` refuses to be made
/// on a task that is gone (spec section 2): it names the head it refused, so that a test reads what the opener
/// was told.
private struct Refusal: Error, Equatable {
    let head: Screen.Route.Head
}

/// The flow's base, with nothing of a sidebar in it: it declares a list by number, from the route it is made on,
/// a click on a view or a link, and takes the stack's notices as events of its own, the way a feature's base
/// takes them.
///
/// It answers every event by naming it, so that what a call on the stack returns says which of the base's
/// answers reached the owner, and its model carries what it declares and every event it has been sent, since
/// the stack keeps the base to itself and hands out nothing of it but its model.
private final class StubBase: Routable {
    struct Route: RouteValue {
        let head = NoHead()
        let list: StubList.Route?
    }

    struct Model: Equatable, Sendable {
        let pushed: StubList.Route?
        let received: [Event]
    }

    enum UserAction: Equatable, Sendable {
        case viewClicked(Int)
        case buttonTapped
    }

    enum Event: RoutedEvent {
        case action(UserAction)
        case created
        case route(Route)
        case answered(StubList.Output)
        case uncovered
        case notOpened(Refusal, stillOpen: StubList.Route?)
    }

    enum Output: Equatable, Sendable {
        case heard(Event)
    }

    var route: Route { Route(list: destination.pushed) }

    var model: Model { Model(pushed: destination.pushed, received: received) }

    private(set) var destination = Destination<StubList.Route>()

    private var received: [Event] = []

    init(route: Route) {
        declare(route.list)
    }

    func send(_ event: Event) -> Output? {
        received.append(event)
        switch event {
        case .action(.viewClicked(let view)): declare(StubList.Route(head: view, task: nil))
        case .route(let route): declare(route.list)
        case .uncovered: declare(nil)
        case .notOpened(_, let stillOpen): declare(stillOpen)
        case .action(.buttonTapped), .created, .answered: break
        }
        return .heard(event)
    }

    private func declare(_ list: StubList.Route?) {
        destination.declare(list.map { .pushed($0) })
    }
}

/// A screen the base opens, with nothing of a list in it: its head is the number of its view, and it declares
/// a task from the route it is made on, a tap on a row and what the stack hands it.
///
/// It takes the stack's notices as events of its own, so that its model carries, in order, every event it was
/// sent and every notice it took. It answers `.created` with its head, its first choice; it empties its
/// destination when its task asks to be closed, and passes every other answer of its task on to its own
/// opener, so that a test sees an answer go the whole way down.
///
/// Two of its gestures both answer and write its destination, so that a test sees the walk run after an answer
/// came down and the call return that answer before the one the walk draws: a double tap on a row declares the
/// row's task, as a tap does, and tells its opener the row was double-tapped; and a list on view 5 does not
/// take being uncovered, but writes the task it declared again and tells its opener it reopened it, as a screen
/// that tried to keep a destination the person closed would.
private final class StubList {
    struct Route: RouteValue {
        let head: Int
        let task: StubTask.Route?
    }

    struct Model: Equatable, Sendable {
        let route: Route
        let received: [Event]
    }

    enum Event: Equatable, Sendable {
        case rowTapped(Int)
        case rowDoubleTapped(Int)
        case created
        case declared(Route)
        case answered(StubTask.Output)
        case uncovered
        case notOpened(Refusal, stillOpen: StubTask.Route?)
    }

    enum Output: Equatable, Sendable {
        case opened(Int)
        case doubleTapped(Int)
        case reopened(Int)
        case passedOn(StubTask.Output)
    }

    var route: Route { Route(head: head, task: destination.pushed) }

    var model: Model { Model(route: route, received: received) }

    private(set) var destination = Destination<StubTask.Route>()

    private let head: Int

    private var received: [Event] = []

    init(route: Route) {
        head = route.head
        declare(route.task)
    }

    func send(_ event: Event) -> Output? {
        received.append(event)
        switch event {
        case .rowTapped(let task): declare(StubTask.Route(head: task, subtask: nil))
        case .rowDoubleTapped(let task):
            declare(StubTask.Route(head: task, subtask: nil))
            return .doubleTapped(task)
        case .created: return .opened(head)
        case .declared(let route): declare(route.task)
        case .uncovered where head == 5:
            declare(destination.pushed)
            return .reopened(head)
        case .answered(.closeRequested), .uncovered: declare(nil)
        case .answered(let output): return .passedOn(output)
        case .notOpened(_, let stillOpen): declare(stillOpen)
        }
        return nil
    }

    private func declare(_ task: StubTask.Route?) {
        destination.declare(task.map { .pushed($0) })
    }
}

/// A screen a list or a task opens, with nothing of a task in it: its head is the number of its task, and its
/// tail the head of the task it declares over it, which opens with nothing over it, so that a task can stand
/// over a task.
///
/// It records what it hears as the list does. It answers `.created` with its head, or, made on a task whose
/// subject is gone, with a request to be closed, the way a screen whose subject is gone asks (ADR-0006,
/// amendment of 2026-10-14); it asks to be closed when its close button is tapped, answers a tap on its other
/// button with its head, and empties its destination when the task over it asks to be closed.
private final class StubTask {
    struct Route: RouteValue {
        let head: Int
        let subtask: Int?
    }

    struct Model: Equatable, Sendable {
        let route: Route
        let received: [Event]
    }

    enum Event: Equatable, Sendable {
        case subtaskTapped(Int)
        case closeButtonTapped
        case buttonTapped
        case created
        case declared(Route)
        case answered(Output)
        case uncovered
        case notOpened(Refusal, stillOpen: Route?)
    }

    enum Output: Equatable, Sendable {
        case opened(Int)
        case tapped(Int)
        case closeRequested
    }

    var route: Route { Route(head: head, subtask: destination.pushed?.head) }

    var model: Model { Model(route: route, received: received) }

    private(set) var destination = Destination<Route>()

    private let head: Int

    private let gone: Bool

    private var received: [Event] = []

    init(route: Route, gone: Bool) {
        head = route.head
        self.gone = gone
        declare(route.subtask)
    }

    func send(_ event: Event) -> Output? {
        received.append(event)
        switch event {
        case .subtaskTapped(let subtask): declare(subtask)
        case .closeButtonTapped: return .closeRequested
        case .buttonTapped: return .tapped(head)
        case .created: return gone ? .closeRequested : .opened(head)
        case .declared(let route): declare(route.subtask)
        case .answered(.closeRequested), .uncovered: declare(nil)
        case .answered: break
        case .notOpened(_, let stillOpen): declare(stillOpen?.head)
        }
        return nil
    }

    private func declare(_ subtask: Int?) {
        destination.declare(subtask.map { .pushed(Route(head: $0, subtask: nil)) })
    }
}

/// The enum of the kinds of screen the stub flow's stack holds, with the mappings a stack needs: switches that
/// decide nothing, in which a pairing that cannot occur answers nothing, as a flow's own enum does (plan, Task
/// 2). A list stands only on the base and a task only on a list or a task, so neither is ever declared with the
/// other's route, and neither ever hears a list's answer.
///
/// Swift 6.4 infers neither `Base` nor `Failure` from the requirements that use them, so both are spelled; and
/// the route carries one accessor per case, since the payload of one case out of an optional route does not
/// typecheck inline in an argument (plan, Task 1, "Verified facts and traps").
private enum Screen: StackScreen {
    typealias Base = StubBase
    typealias Failure = Refusal

    case list(StubList)
    case task(StubTask)

    enum Route: RouteValue {
        case list(StubList.Route)
        case task(StubTask.Route)

        enum Head: Equatable, Sendable {
            case list(Int)
            case task(Int)
        }

        var head: Head {
            switch self {
            case .list(let route): .list(route.head)
            case .task(let route): .task(route.head)
            }
        }

        var list: StubList.Route? {
            guard case .list(let route) = self else { return nil }
            return route
        }

        var task: StubTask.Route? {
            guard case .task(let route) = self else { return nil }
            return route
        }
    }

    enum Model: Equatable, Sendable {
        case list(StubList.Model)
        case task(StubTask.Model)
    }

    enum Event {
        case list(StubList.Event)
        case task(StubTask.Event)
    }

    enum Output {
        case list(StubList.Output)
        case task(StubTask.Output)
    }

    var route: Route {
        switch self {
        case .list(let list): .list(list.route)
        case .task(let task): .task(task.route)
        }
    }

    var model: Model {
        switch self {
        case .list(let list): .list(list.model)
        case .task(let task): .task(task.model)
        }
    }

    var destination: Destination<Route> {
        switch self {
        case .list(let list): list.destination.map(Route.task)
        case .task(let task): task.destination.map(Route.task)
        }
    }

    func send(_ event: Event) -> Output? {
        switch (self, event) {
        case (.list(let list), .list(let event)): return list.send(event).map(Output.list)
        case (.task(let task), .task(let event)): return task.send(event).map(Output.task)
        case (.list, .task), (.task, .list): return nil
        }
    }

    func take(_ notice: StackNotice<Screen>) -> Output? {
        switch (self, notice) {
        case (.list, .created): return send(.list(.created))
        case (.list, .declared(.list(let route))): return send(.list(.declared(route)))
        case (.list, .answered(.task(let output))): return send(.list(.answered(output)))
        case (.list, .uncovered): return send(.list(.uncovered))
        case (.list, .notOpened(let refusal, let stillOpen)):
            return send(.list(.notOpened(refusal, stillOpen: stillOpen?.task)))
        case (.task, .created): return send(.task(.created))
        case (.task, .declared(.task(let route))): return send(.task(.declared(route)))
        case (.task, .answered(.task(let output))): return send(.task(.answered(output)))
        case (.task, .uncovered): return send(.task(.uncovered))
        case (.task, .notOpened(let refusal, let stillOpen)):
            return send(.task(.notOpened(refusal, stillOpen: stillOpen?.task)))
        case (.list, .declared(.task)), (.list, .answered(.list)):
            return nil
        case (.task, .declared(.list)), (.task, .answered(.list)):
            return nil
        }
    }

    func route(over above: Route?) -> Route {
        switch self {
        case .list(let list): .list(StubList.Route(head: list.route.head, task: above?.task))
        case .task(let task): .task(StubTask.Route(head: task.route.head, subtask: above?.task?.head))
        }
    }

    static func destination(of base: StubBase) -> Destination<Route> {
        base.destination.map(Route.list)
    }

    static func take(_ notice: StackNotice<Screen>, base: StubBase) -> StubBase.Output? {
        switch notice {
        case .answered(.list(let output)): return base.send(.answered(output))
        case .uncovered: return base.send(.uncovered)
        case .notOpened(let refusal, let stillOpen): return base.send(.notOpened(refusal, stillOpen: stillOpen?.list))
        case .created, .declared, .answered(.task): return nil
        }
    }

    static func route(of base: StubBase, over above: Route?) -> StubBase.Route {
        StubBase.Route(list: above?.list)
    }
}

/// A stack over a stub base made on `route`, built once, the way a flow's owner builds its stack: its factory
/// refuses a head of 99, of either kind, and makes every other screen, a task on a head in `gone` as one whose
/// subject is gone.
private func stubStack(on route: StubBase.Route, gone: Set<Int> = []) -> ScreenStack<Screen> {
    ScreenStack(base: StubBase(route: route)) { route throws(Refusal) in
        switch route {
        case .list(let list) where list.head != 99: return .list(StubList(route: list))
        case .task(let task) where task.head != 99:
            return .task(StubTask(route: task, gone: gone.contains(task.head)))
        case .list, .task: throw Refusal(head: route.head)
        }
    }
}

/// The base's route that opens list `list`, with task `task` over it where one is given: the link
/// `/view/<list>/task/<task>`.
private func link(list: Int, task: Int? = nil) -> StubBase.Route {
    StubBase.Route(list: StubList.Route(head: list, task: task.map { StubTask.Route(head: $0, subtask: nil) }))
}

/// The owner's first call is the first walk, since the stack's `init` has nowhere to put the base's answers: the
/// base hears `.created` before any notice, and each screen the walk makes hears `.created` first and once
/// (ADR-0006, amendments of 2026-10-03 and 2026-10-22). What the list heard after it is its task's answer.
@Test func theStackMakesWhatTheBaseDeclaresAndTellsItItWasCreated() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    #expect(stack.path.isEmpty, "the stack's init does not walk")
    #expect(stack.baseModel.received.isEmpty)
    _ = stack.send(.created)
    let path = stack.path
    try #require(path.count == 2)
    let task = StubTask.Route(head: 7, subtask: nil)
    let list = StubList.Model(route: StubList.Route(head: 1, task: task), received: [.created, .answered(.opened(7))])
    #expect(stack.models[path[0]] == .list(list))
    #expect(stack.models[path[1]] == .task(StubTask.Model(route: task, received: [.created])))
    #expect(stack.baseModel.received == [.created, .answered(.opened(1)), .answered(.passedOn(.opened(7)))])
}

/// A screen's first choice is its answer to `.created`, and it reaches the screen's opener on the line every
/// later answer takes (ADR-0006, amendment of 2026-10-22, point 3): the list's reached the base at the first
/// walk, and the answer of a task the walk makes later reaches the list, which passes it on, so that it comes
/// back out of the call that made the task.
@Test func aMadeScreensAnswerToCreatedReachesItsOpener() throws {
    var stack = stubStack(on: link(list: 1))
    _ = stack.send(.created)
    let list = try #require(stack.path.first)
    #expect(stack.baseModel.received == [.created, .answered(.opened(1))])
    #expect(stack.send(.list(.rowTapped(8)), to: list) == .heard(.answered(.passedOn(.opened(8)))))
    let route = StubList.Route(head: 1, task: StubTask.Route(head: 8, subtask: nil))
    let received: [StubList.Event] = [.created, .rowTapped(8), .answered(.opened(8))]
    #expect(stack.models[list] == .list(StubList.Model(route: route, received: received)))
}

/// After a notice that drew an answer the walk starts again from the base, so a lower destination the answer
/// moved is followed before anything over it: the task the walk made answered `.created` by asking to be
/// closed, the list emptied its destination, and the task is gone by the time the call returns.
@Test func anAnswerThatEmptiesALowerDestinationDropsWhatStandsOverItInTheSameWalk() throws {
    var stack = stubStack(on: link(list: 1), gone: [8])
    _ = stack.send(.created)
    let list = try #require(stack.path.first)
    #expect(stack.send(.list(.rowTapped(8)), to: list) == nil, "the list acted on the answer and passed nothing on")
    #expect(stack.path == [list])
    let received: [StubList.Event] = [.created, .rowTapped(8), .answered(.closeRequested)]
    #expect(stack.models[list] == .list(StubList.Model(route: StubList.Route(head: 1, task: nil), received: received)))
}

/// A click on the view already highlighted writes the very value the base's destination holds, and is a new
/// declaration all the same: the list stays, by id and with everything it heard, and is handed the route once,
/// which closes the task open in it (owner, 2026-10-16; spec section 2, "A slot written again is a new
/// declaration").
@Test func aNewWriteWithTheSameHeadKeepsTheScreenAndHandsItTheDeclarationOnce() throws {
    var stack = stubStack(on: link(list: 1))
    _ = stack.send(.created)
    let list = try #require(stack.path.first)
    _ = stack.send(.list(.rowTapped(7)), to: list)
    try #require(stack.path.count == 2)
    _ = stack.send(.action(.viewClicked(1)))
    #expect(stack.path == [list])
    let declared = StubList.Route(head: 1, task: nil)
    let received: [StubList.Event] = [.created, .rowTapped(7), .answered(.opened(7)), .declared(declared)]
    #expect(stack.models[list] == .list(StubList.Model(route: declared, received: received)))
}

/// Between two writes the screen over an opener owns its own destination (spec section 2): the base's
/// declaration, a list with no task, was followed once, and an event on the base that writes nothing hands it
/// to nobody, where handing it again would close the task the list has opened since.
@Test func aDeclarationAlreadyFollowedIsNeverHandedAgain() throws {
    var stack = stubStack(on: link(list: 1))
    _ = stack.send(.created)
    let list = try #require(stack.path.first)
    _ = stack.send(.list(.rowTapped(7)), to: list)
    let path = stack.path
    try #require(path.count == 2)
    let models = stack.models
    #expect(stack.send(.action(.buttonTapped)) == .heard(.action(.buttonTapped)))
    #expect(stack.path == path)
    #expect(stack.models == models, "neither the list nor its task was handed anything")
}

/// Another head is another screen: it is made, told it was created, and replaces the list and the task over
/// it, with an id never handed out before (spec section 2).
@Test func anotherHeadReplacesEverythingAbove() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    let replaced = stack.path
    try #require(replaced.count == 2)
    _ = stack.send(.action(.viewClicked(2)))
    let list = try #require(stack.path.first)
    #expect(stack.path == [list])
    #expect(!replaced.contains(list))
    let route = StubList.Route(head: 2, task: nil)
    #expect(stack.models[list] == .list(StubList.Model(route: route, received: [.created])))
}

@Test func anEmptyDeclarationDropsEverythingAbove() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    try #require(stack.path.count == 2)
    _ = stack.send(.route(StubBase.Route(list: nil)))
    #expect(stack.path.isEmpty)
    #expect(stack.models.isEmpty)
}

/// The new screen is made before anything is let go, so one that cannot be made leaves what stands, and its
/// opener is told why and what still stands over it, which it takes back as its destination. The stack records
/// that write as followed, so the declaration is tried once and the screen over the opener is handed nothing
/// (spec section 2, and "Risks"). It holds for a list over the base and for a task over a list alike.
@Test func aScreenThatCannotBeMadeLeavesWhatStandsAndItsOpenerTakesItBackOnce() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    let path = stack.path
    try #require(path.count == 2)
    let models = stack.models
    let task = StubTask.Route(head: 7, subtask: nil)
    let open = StubList.Route(head: 1, task: task)
    _ = stack.send(.action(.viewClicked(99)))
    #expect(stack.path == path)
    #expect(stack.models == models, "what stood stands, and was handed nothing")
    #expect(stack.baseModel.pushed == open, "the base took back the list that stays open")
    _ = stack.send(.action(.buttonTapped))
    #expect(stack.models == models, "the destination taken back is not handed to the list")
    let heard: [StubBase.Event] = [
        .created, .answered(.opened(1)), .answered(.passedOn(.opened(7))),
        .action(.viewClicked(99)), .notOpened(Refusal(head: .list(99)), stillOpen: open),
        .action(.buttonTapped),
    ]
    #expect(stack.baseModel.received == heard, "told once")

    _ = stack.send(.list(.rowTapped(99)), to: path[0])
    #expect(stack.path == path)
    let received: [StubList.Event] = [
        .created, .answered(.opened(7)), .rowTapped(99), .notOpened(Refusal(head: .task(99)), stillOpen: task),
    ]
    #expect(stack.models[path[0]] == .list(StubList.Model(route: open, received: received)))
    #expect(stack.models[path[1]] == models[path[1]], "the task that stood stands")
}

/// An answer goes down: the task's to the list that opened it, the list's to the base, and the base's out of
/// the call, to the flow's owner (spec section 2, "Answers go to the opener"). When one call draws more than one
/// answer from the base, the owner gets the first drawn, the base's answer to the event itself before any the
/// walk draws, and for an event handed to an element the answer that came down from it: the walk runs after
/// that answer all the same.
@Test func anAnswerGoesToTheOpenerAndTheBasesAnswerToTheOwner() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    #expect(stack.send(.created) == .heard(.created), "the base's answer to the event, before the two the walk drew")
    let path = stack.path
    try #require(path.count == 2)
    #expect(stack.send(.task(.buttonTapped), to: path[1]) == .heard(.answered(.passedOn(.tapped(7)))))
    let route = StubList.Route(head: 1, task: StubTask.Route(head: 7, subtask: nil))
    let received: [StubList.Event] = [.created, .answered(.opened(7)), .answered(.tapped(7))]
    #expect(stack.models[path[0]] == .list(StubList.Model(route: route, received: received)))

    // A double tap on a row answers and declares the row's task, whose answer to `.created` the walk draws.
    var tapped = stubStack(on: link(list: 1))
    _ = tapped.send(.created)
    let list = try #require(tapped.path.first)
    let answer = tapped.send(.list(.rowDoubleTapped(8)), to: list)
    #expect(answer == .heard(.answered(.doubleTapped(8))), "the answer that came down, before the one the walk drew")
    #expect(tapped.baseModel.received.last == .answered(.passedOn(.opened(8))), "the one the walk drew")
    #expect(tapped.path.count == 2, "the walk ran after the answer came down, and made the task")
}

/// A screen that asks to be closed, as one whose subject is gone does, is dropped through its opener: the
/// opener empties its destination, and the walk after the event drops the screen (spec section 2, "Answers go
/// to the opener").
@Test func aScreenAskingToCloseIsDroppedThroughItsOpener() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    let path = stack.path
    try #require(path.count == 2)
    let base = stack.baseModel
    #expect(stack.send(.task(.closeButtonTapped), to: path[1]) == nil)
    #expect(stack.path == [path[0]])
    let route = StubList.Route(head: 1, task: nil)
    let received: [StubList.Event] = [.created, .answered(.opened(7)), .answered(.closeRequested)]
    #expect(stack.models[path[0]] == .list(StubList.Model(route: route, received: received)))
    #expect(stack.baseModel == base, "the list acted on the answer and passed nothing on")
}

/// The way back drops what was over the screen the person went back to before that screen hears of it, so it
/// cannot keep a destination the person closed; the screen now on top is the base when the path is empty
/// (spec section 3). A list on view 5, which writes its task again when uncovered, gets a new task and not the
/// one the person went back from, since that one is gone already; the walk runs after the answer that came
/// down, which the call returns before the one the walk draws.
@Test func wentBackDropsWhatWasAboveAndTellsTheScreenNowOnTop() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    let path = stack.path
    try #require(path.count == 2)
    #expect(stack.wentBack(to: [path[0]]) == nil, "the list answers nothing to being uncovered")
    #expect(stack.path == [path[0]])
    let route = StubList.Route(head: 1, task: nil)
    let received: [StubList.Event] = [.created, .answered(.opened(7)), .uncovered]
    #expect(stack.models[path[0]] == .list(StubList.Model(route: route, received: received)))
    #expect(stack.wentBack(to: []) == .heard(.uncovered))
    #expect(stack.path.isEmpty)
    #expect(stack.baseModel.pushed == nil, "the base emptied its destination, and its highlight with it")

    var keeping = stubStack(on: link(list: 5, task: 7))
    _ = keeping.send(.created)
    let closed = keeping.path
    try #require(closed.count == 2)
    #expect(keeping.wentBack(to: [closed[0]]) == .heard(.answered(.reopened(5))), "the answer that came down")
    #expect(keeping.baseModel.received.last == .answered(.passedOn(.opened(7))), "the one the walk drew")
    let reopened = keeping.path
    try #require(reopened.count == 2, "the walk ran after the answer came down, and followed the list's write")
    #expect(reopened[0] == closed[0])
    #expect(reopened[1] != closed[1], "a new task, since the one the person went back from was dropped first")
    let task = StubTask.Model(route: StubTask.Route(head: 7, subtask: nil), received: [.created])
    #expect(keeping.models[reopened[1]] == .task(task))
}

/// The way back moves only a strict prefix of the path the stack holds, so a write SwiftUI makes after a pop
/// the model drove, and any id the stack never gave, move nothing (spec section 3, "A pop the model drove").
@Test func wentBackToAPathTheStackDoesNotHoldMovesNothing() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    let path = stack.path
    try #require(path.count == 2)
    // A stack that has made three screens holds an id this one, which has made two, never gave.
    var other = stubStack(on: link(list: 1, task: 7))
    _ = other.send(.created)
    try #require(other.path.count == 2)
    _ = other.send(.task(.subtaskTapped(8)), to: other.path[1])
    try #require(other.path.count == 3)
    let foreign = other.path[2]
    let models = stack.models
    let base = stack.baseModel
    let writes: [(written: [StackElementID], what: String)] = [
        ([foreign], "an id the stack never gave"), ([path[1]], "not a prefix"),
        (path, "the same path"), (path + [foreign], "a longer one"),
    ]
    for (written, what) in writes {
        #expect(stack.wentBack(to: written) == nil, "\(what)")
        #expect(stack.path == path, "\(what)")
        #expect(stack.models == models, "\(what)")
        #expect(stack.baseModel == base, "\(what)")
    }
}

/// Ids are handed out in order and never reused within a stack, so a task stands over a task as two elements
/// with two models (spec section 2, "Each element of the stack has an id").
@Test func theSameKindOfScreenCanStandTwice() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    try #require(stack.path.count == 2)
    _ = stack.send(.task(.subtaskTapped(8)), to: stack.path[1])
    let path = stack.path
    try #require(path.count == 3)
    #expect(path[1] != path[2])
    let lower = StubTask.Model(
        route: StubTask.Route(head: 7, subtask: 8),
        received: [.created, .subtaskTapped(8), .answered(.opened(8))]
    )
    let upper = StubTask.Model(route: StubTask.Route(head: 8, subtask: nil), received: [.created])
    #expect(stack.models[path[1]] == .task(lower))
    #expect(stack.models[path[2]] == .task(upper))
}

/// The route is written from the top down, each element's route over what actually stands above it, so a
/// declaration that has aged never reaches the text (spec section 3): the base still declares the task its
/// link opened after the task has closed, and the route names the list alone.
@Test func theRouteIsWrittenFromWhatStands() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    let path = stack.path
    try #require(path.count == 2)
    _ = stack.send(.task(.subtaskTapped(8)), to: path[1])
    let three = StubBase.Route(list: StubList.Route(head: 1, task: StubTask.Route(head: 7, subtask: 8)))
    #expect(stack.route == three)
    _ = stack.send(.task(.closeButtonTapped), to: path[1])
    #expect(stack.baseModel.pushed == link(list: 1, task: 7).list, "the base's declaration has aged")
    #expect(stack.route == link(list: 1))
}

@Test func anEventForAnIDTheStackDoesNotHoldMovesNothing() throws {
    var stack = stubStack(on: link(list: 1, task: 7))
    _ = stack.send(.created)
    let path = stack.path
    try #require(path.count == 2)
    _ = stack.send(.task(.closeButtonTapped), to: path[1])
    try #require(stack.path == [path[0]], "the task is gone, and its id with it")
    let models = stack.models
    let base = stack.baseModel
    #expect(stack.send(.task(.buttonTapped), to: path[1]) == nil)
    #expect(stack.models == models)
    #expect(stack.baseModel == base)
}
