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

/// How many times an observer was told. On the main actor, because that is where the host assigns its model,
/// and an observer is told inside the assignment.
@MainActor private final class Notified {
    var count = 0
}

/// A module that writes down when each event began and ended, so that one event inside another shows.
private final class Recorder: FeatureModule {
    struct Model: Equatable, Sendable {
        let count: Int
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
    }

    enum Event: FeatureEvent {
        case action(UserAction)
        /// Moves the model, the way a change from the store does.
        case fromWorld
        /// Moves the model and calls the world's entrance from inside `send`, so that an event which waited
        /// its turn delivers one of its own.
        case fromWorldRelaying
    }

    typealias Output = Never

    enum Step: Equatable {
        case began(Event)
        case ended(Event)
    }

    var model: Model { Model(count: count) }
    private(set) var steps: [Step] = []

    private var count = 0

    /// What the host held as each event began, read through `hostModel` when a test sets it.
    private(set) var heldByTheHost: [Model] = []
    var hostModel: (() -> Model)?

    /// The world's entrance as the store holds it in the app: a plain closure property, assigned by `world`.
    var world: ((Event) -> Void)?

    func send(_ event: Event) -> Never? {
        steps.append(.began(event))
        if let hostModel { heldByTheHost.append(hostModel()) }
        defer { steps.append(.ended(event)) }
        switch event {
        case .action(.counted), .fromWorld: count += 1
        case .action(.ignored): break
        case .action(.relayed): world?(.fromWorld)
        case .action(.relayedTwice):
            count += 1
            world?(.fromWorldRelaying)
            world?(.fromWorld)
        case .fromWorldRelaying:
            count += 1
            world?(.fromWorld)
        }
        return nil
    }
}
