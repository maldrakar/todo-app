import Testing
import Observation
import FeatureModule
import TodoAppleUI

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

@Test @MainActor func theWorldEntranceReachesTheModuleAsAnEvent() throws {
    let recorder = Recorder()
    var entrance: (@MainActor (Recorder.Event) -> Void)?
    let host = ModuleHost(recorder) { entrance = $0 }
    // Two statements, because `try #require(entrance)(.fromWorld)` stops Swift 6.3.3's type checker on an
    // assertion (`recordArgumentList`, ConstraintSystem.cpp) instead of compiling.
    let deliver = try #require(entrance)
    deliver(.fromWorld)
    #expect(recorder.steps == [.began(.fromWorld), .ended(.fromWorld)])
    #expect(host.model == Recorder.Model(count: 1))
}

/// A module assembles its model again on every event, the many it ignores included, so most events leave the
/// model equal, and a view told of each of them would redraw for nothing.
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
final class Recorder: FeatureModule {
    struct Model: Equatable, Sendable {
        let count: Int
    }

    enum UserAction: Equatable, Sendable {
        /// Moves the model.
        case counted
        /// Assembles an equal model, the way a module answers an event it ignores.
        case ignored
        /// Calls the world's entrance from inside `send`, the way a write calls `Store.onChange`.
        case relayed
    }

    enum Event: FeatureEvent {
        case action(UserAction)
        /// Moves the model, the way a change from the store does.
        case fromWorld
    }

    typealias Output = Never

    enum Step: Equatable {
        case began(Event)
        case ended(Event)
    }

    private(set) var model = Model(count: 0)
    private(set) var steps: [Step] = []

    /// The world's entrance as the store holds it in the app: a plain closure property, assigned by `world`.
    var world: ((Event) -> Void)?

    func send(_ event: Event) -> Never? {
        steps.append(.began(event))
        defer { steps.append(.ended(event)) }
        switch event {
        case .action(.counted), .fromWorld: model = Model(count: model.count + 1)
        case .action(.ignored): model = Model(count: model.count)
        case .action(.relayed): world?(.fromWorld)
        }
        return nil
    }
}
