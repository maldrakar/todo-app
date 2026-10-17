import Testing
import Observation
import FeatureModule
@testable import TodoAppleUI

@Test @MainActor func sendLiftsAnActionIntoAnEventAndCopiesTheModel() {
    let recorder = Recorder()
    let host = ModuleHost(recorder) { _ in }
    host.send(.counted)
    #expect(recorder.steps == [.began(.action(.counted)), .ended(.action(.counted))])
    #expect(host.model == Recorder.Model(count: 1))
}

/// The app's chain in miniature: the module's `send` reaches the world's entrance before it returns, the way a
/// write reaches `Store.onChange`. Sent through at once, the second event would begin and end inside the
/// first, and the module would see its own write in the middle of its own update (spec section 5).
@Test @MainActor func anEventDeliveredDuringASendWaitsForItToReturn() {
    let recorder = Recorder()
    let host = ModuleHost(recorder) { deliver in recorder.world = { deliver($0) } }
    host.send(.relayed)
    #expect(recorder.steps == [
        .began(.action(.relayed)), .ended(.action(.relayed)),
        .began(.fromWorld), .ended(.fromWorld),
    ])
    #expect(host.model == Recorder.Model(count: 1), "the event that waited moved the model, and the host copied it")
}

/// The rule at full stretch: two events arrive during one `send`, and the first of them, sent in its turn,
/// delivers a third. Each waits until the event in flight has returned, and they go in the order they arrived,
/// which a queue of one slot breaks by losing one, and so does a drain that lets the delivery made by a queued
/// event through at once. Each event also begins with the host holding the model the event before it left, so
/// the model is copied after every event and not once at the end.
@Test @MainActor func everyEventDeliveredInFlightWaitsItsTurnAndIsCopiedWhenItReturns() {
    let recorder = Recorder()
    let host = ModuleHost(recorder) { deliver in recorder.world = { deliver($0) } }
    recorder.hostModel = { [unowned host] in host.model }
    host.send(.relayedTwice)
    #expect(recorder.steps == [
        .began(.action(.relayedTwice)), .ended(.action(.relayedTwice)),
        .began(.fromWorldRelaying), .ended(.fromWorldRelaying),
        .began(.fromWorld), .ended(.fromWorld),
        .began(.fromWorld), .ended(.fromWorld),
    ])
    #expect(recorder.heldByTheHost == [0, 1, 2, 3].map(Recorder.Model.init(count:)))
    #expect(host.model == Recorder.Model(count: 4))
}

@Test @MainActor func theWorldEntranceReachesTheModuleAsAnEvent() throws {
    let recorder = Recorder()
    var entrance: (@MainActor (Recorder.Event) -> Void)?
    let host = ModuleHost(recorder) { entrance = $0 }
    // Two statements, because `try #require(entrance)(.fromWorld)` stops the type checker of Swift 6.3.3 and of
    // Xcode's 6.2.4 alike on an assertion (`recordArgumentList`, ConstraintSystem.cpp) instead of compiling.
    let deliver = try #require(entrance)
    deliver(.fromWorld)
    #expect(recorder.steps == [.began(.fromWorld), .ended(.fromWorld)])
    #expect(host.model == Recorder.Model(count: 1))
}

/// The host reads the module's model after every event, the many the module ignores included, so many events
/// leave the model equal, and a view told of each of them would redraw for nothing.
@Test @MainActor func anEventThatLeavesTheModelEqualNotifiesNoObserver() {
    let recorder = Recorder()
    let host = ModuleHost(recorder) { _ in }
    let notified = Notified()
    withObservationTracking { _ = host.model } onChange: { MainActor.assumeIsolated { notified.count += 1 } }
    host.send(.ignored)
    #expect(notified.count == 0)
    host.send(.counted)
    #expect(notified.count == 1, "the observer was listening: a model that moved reaches it")
}

/// The route is what a window writes down, so the host reads it after every event, an action and an event of the
/// world alike, and one that moved the route and left the model alone still reaches it (`docs/specs/navigation.md`,
/// section 5).
@Test @MainActor func theHostPublishesTheRouteAfterEachEvent() throws {
    let recorder = Recorder()
    var entrance: (@MainActor (Recorder.Event) -> Void)?
    let host = ModuleHost(recorder) { entrance = $0 }
    #expect(host.route == Recorder.Route(page: 0), "the route the module was made on")
    host.send(.pageTurned)
    #expect(host.route == Recorder.Route(page: 1), "after an action")
    let deliver = try #require(entrance)
    deliver(.route(Recorder.Route(page: 7)))
    #expect(host.route == Recorder.Route(page: 7), "after an event of the world")
    #expect(host.model == Recorder.Model(count: 1), "the route moved and the model did not")
}

/// A handler that opens a window opens it on what the window shows when the output arrives, so the host hands the
/// output on only after it has published the model and the route the event left (`docs/specs/navigation.md`,
/// section 5).
@Test @MainActor func anOutputReachesTheHandlerAfterTheModel() {
    let recorder = Recorder()
    let host = ModuleHost(recorder) { _ in }
    var handed: [Handed] = []
    host.onOutput = { [unowned host] output in
        handed.append(Handed(output: output, model: host.model, route: host.route))
    }
    host.send(.pageTurned)
    #expect(handed == [Handed(output: .turned(to: 1), model: Recorder.Model(count: 1), route: Recorder.Route(page: 1))])
}

/// An output with no handler goes nowhere and is not kept: a handler installed later is handed the outputs of
/// the events after it, and never one that answered a gesture made before anything could act on it. The event
/// that answered still moves the model and the route.
@Test @MainActor func anOutputWithNoHandlerIsDropped() {
    let recorder = Recorder()
    let host = ModuleHost(recorder) { _ in }
    host.send(.pageTurned)
    #expect(host.model == Recorder.Model(count: 1))
    #expect(host.route == Recorder.Route(page: 1))
    var handed: [Recorder.Output] = []
    host.onOutput = { handed.append($0) }
    host.send(.counted)
    #expect(handed.isEmpty, "the output that arrived with no handler was not kept for this one")
    host.send(.pageTurned)
    #expect(handed == [.turned(to: 2)], "the handler was listening: an output after it reaches it")
}

/// How many times an observer was told. On the main actor, because that is where the host assigns its model,
/// and an observer is told inside the assignment.
@MainActor private final class Notified {
    var count = 0
}

/// What a handler was handed, and what the host held as it was.
private struct Handed: Equatable {
    let output: Recorder.Output
    let model: Recorder.Model
    let route: Recorder.Route
}

/// A routable module that writes down when each event began and ended, so that one event inside another shows.
private final class Recorder: Routable {
    struct Model: Equatable, Sendable {
        let count: Int
    }

    /// No head, as a window's root has none, and a page for its tail, which moves apart from the model.
    struct Route: RouteValue {
        var head: NoHead { NoHead() }
        let page: Int
    }

    enum UserAction: Equatable, Sendable {
        /// Moves the model.
        case counted
        /// Moves nothing, the way a module answers an event it ignores.
        case ignored
        /// Calls the world's entrance from inside `send`, the way a write calls `Store.onChange`.
        case relayed
        /// Moves the model and calls the world's entrance twice from inside `send`, first with an event that
        /// calls it once more.
        case relayedTwice
        /// Moves the model and the route, and answers with the page it turned to, the way the root answers a
        /// menu item with a window to open.
        case pageTurned
    }

    enum Event: RoutedEvent {
        case action(UserAction)
        /// Moves the model, the way a change from the store does.
        case fromWorld
        /// Moves the model and calls the world's entrance from inside `send`, so that an event which waited
        /// its turn delivers one of its own.
        case fromWorldRelaying
        /// What `RoutedEvent` spells; the host sends no `.created`, so `steps` would show one it sent.
        case created
        /// Moves the route to the one given and leaves the model, the way a link moves a window.
        case route(Route)
    }

    enum Output: Equatable, Sendable {
        case turned(to: Int)
    }

    enum Step: Equatable {
        case began(Event)
        case ended(Event)
    }

    var model: Model { Model(count: count) }
    var route: Route { Route(page: page) }
    private(set) var steps: [Step] = []

    private var count = 0
    private var page = 0

    /// What the host held as each event began, read through `hostModel` when a test sets it.
    private(set) var heldByTheHost: [Model] = []
    var hostModel: (() -> Model)?

    /// The world's entrance, held the way the store holds its `onChange` in the app: a plain closure property,
    /// assigned by `world`.
    var world: ((Event) -> Void)?

    func send(_ event: Event) -> Output? {
        steps.append(.began(event))
        if let hostModel { heldByTheHost.append(hostModel()) }
        defer { steps.append(.ended(event)) }
        switch event {
        case .action(.counted), .fromWorld: count += 1
        case .action(.ignored), .created: break
        case .action(.relayed): world?(.fromWorld)
        case .action(.relayedTwice):
            count += 1
            world?(.fromWorldRelaying)
            world?(.fromWorld)
        case .action(.pageTurned):
            count += 1
            page += 1
            return .turned(to: page)
        case .fromWorldRelaying:
            count += 1
            world?(.fromWorld)
        case .route(let route): page = route.page
        }
        return nil
    }
}
