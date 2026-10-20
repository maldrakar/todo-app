// Apps/Apple/Sources/TodoAppleUI/ModuleHost.swift
import FeatureModule
import Observation

/// The one object in the app that SwiftUI observes: it holds a routable module and publishes its model and its route
/// (`docs/specs/navigation.md`, section 5). In the app the module is the root of a window, and each window has a host
/// of its own. The window's view holds it and the root view draws it, and every other view gets from the view above it
/// the part of the model it draws and a closure over its own actions (`docs/specs/feature-module-architecture.md`,
/// section 3), so no other view names the host.
///
/// It has two entrances and hands each to one caller. `send(_:)` is a view's, and with `model`, `route` and the handler
/// the window's view puts in `onOutput` it is all a view gets from the host: a closure over `UserAction` cannot spell
/// an event of the world. The world's entrance takes every event, and it is handed once, in `init`, to the composition
/// root, which hands it every change set the store reports, and every link the system opens in the host's window. The
/// window's view hands a link over through `TodoApp.Window.open`, a closure the composition root made over the
/// entrance, which delivers only what the codec reads from a URL, a `.route` or the root's `.unreadableLink`, and never
/// `.changed` or `.created`; the view never holds the entrance itself (the owner, 2026-10-20).
///
/// Both lead to one queue, because the module's own write comes back through the second entrance before the first has
/// returned: send to the root, send to the list, write to the store, `onChange`, deliver `.changed`. Whatever arrives
/// while an event is in flight waits, and is sent after that event returns, so a module never sees its own write in the
/// middle of its own update. A change set another window's write reports arrives through the same entrance, and a host
/// with nothing in flight takes it at once, inside that window's event: the store has committed before it reports, and
/// no module writes in answer to `.changed` (`docs/specs/navigation.md`, section 5). Everything runs on the main actor,
/// so the queue is an array and needs no lock.
///
/// What the module answers goes to `onOutput`, the handler for the window's view to install, since what the root asks
/// for, a window to open, only the platform can do (`docs/specs/navigation.md`, section 5).
@MainActor @Observable
final class ModuleHost<M: Routable> {
    /// The module's model as it stood when the last event returned.
    ///
    /// Assigned after every event, many of which leave it equal: a module computes its model from its state
    /// on every read, and the host reads it after every event the module gets, the ones it ignores included.
    /// It is a copy, where a module keeps none of its own (`docs/style.md`), because SwiftUI observes what
    /// this class stores and not what the module holds. The host does not compare the two itself, because the
    /// setter the `@Observable` macro writes already does: it skips notifying when an `Equatable` value is
    /// assigned an equal one (expanded and run under Swift 6.3.3 and Xcode's 6.2.4 on 2026-10-08). The
    /// comparison is in the setter and not in the macro's `_modify`, which notifies every time, so the model
    /// is assigned whole and never changed in place.
    private(set) var model: M.Model

    /// The module's route as it stood when the last event returned: the address of what the window shows,
    /// published beside the model for the window to write down and to be restored from
    /// (`docs/specs/navigation.md`, sections 5 and 7).
    ///
    /// Read from the module after every event and assigned whole, as `model` is and for the same reasons: a route is
    /// computed by its module on every read, and the setter tells no observer of an equal one.
    private(set) var route: M.Event.Route

    /// The handler of what the module answers, for the window's view to install, since the view is where the
    /// platform is within reach (`docs/specs/navigation.md`, section 5).
    ///
    /// It is handed each output after the host has published the model and the route the event left, so a
    /// handler that opens a window opens it on the state the output came from, and while it runs the event is
    /// still in flight, so an action it sends waits its turn. An output that arrives with no handler is
    /// dropped, and not kept for one installed later, which would act on a gesture made before anything could
    /// answer it. Left out of observation, because no view draws it, and an observer of it would be told of
    /// every installation for nothing.
    ///
    /// The host holds the handler, so a handler holds the host weakly or not at all: one that captured it would
    /// close a cycle, host to handler to host, and a closed window's host would never be released and would go
    /// on taking every change set (probed 2026-10-17 under Swift 6.4.0: a strong capture kept the host after its
    /// last holder let go, and a weak one did not).
    @ObservationIgnored var onOutput: ((M.Output) -> Void)?

    private let module: M

    /// The event in flight, first, and those that arrived while it ran, in the order they arrived. An empty
    /// array is the one sign that nothing is in flight. Left out of observation, which would otherwise send
    /// every append and removal through the registrar for an observer that cannot exist, since it is private.
    @ObservationIgnored private var pending: [M.Event] = []

    /// Hands the world's entrance to `world`, once, after every property is set. It sends the module no
    /// `.created`, which is how a parent takes the first choice of a child it made: the module a host holds has
    /// no parent, and the root answers its own `.created` with nothing, its `init` having told its children.
    ///
    /// The entrance holds the host weakly. The composition root keeps it for as long as the composition root
    /// lives, which in the app is the life of the process, so a strong one would keep the host as long: a
    /// closed window's host and its module would never be released, and would go on taking every change set
    /// the store reports (`docs/specs/navigation.md`, section 5).
    init(_ module: M, world: (@escaping @MainActor (M.Event) -> Void) -> Void) {
        self.module = module
        self.model = module.model
        self.route = module.route
        world { [weak self] event in self?.deliver(event) }
    }

    func send(_ action: M.Event.UserAction) {
        deliver(.action(action))
    }

    private func deliver(_ event: M.Event) {
        pending.append(event)
        guard pending.count == 1 else { return }
        while let next = pending.first {
            let output = module.send(next)
            model = module.model
            route = module.route
            // Handed on while the event is still first in the queue, so that whatever the handler sends waits
            // its turn, as everything that arrives in flight does.
            if let output { onOutput?(output) }
            pending.removeFirst()
        }
    }
}
