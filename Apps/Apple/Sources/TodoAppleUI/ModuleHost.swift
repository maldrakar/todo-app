// Apps/Apple/Sources/TodoAppleUI/ModuleHost.swift
import FeatureModule
import Observation

/// The one object in the app that SwiftUI observes: it holds the root module and publishes its model (spec
/// section 5). The root view holds it, and every other view gets from the view above it the part of the model
/// it draws and a closure over its own actions (spec section 3), so no other view names the host.
///
/// It has two entrances and hands each to one caller. `send(_:)` is a view's, and with `model` it is all a
/// view gets: a closure over `UserAction` cannot spell an event of the world. The world's entrance takes every
/// event, and it is handed once, in `init`, to the composition root, which gives it to the store.
///
/// Both lead to one queue, because the module's own write comes back through the second entrance before the
/// first has returned: send to the root, send to the list, write to the store, `onChange`, deliver
/// `.changed`. Whatever arrives while an event is in flight waits, and is sent after that event returns, so a
/// module never sees its own write in the middle of its own update. Everything runs on the main actor, so
/// the queue is an array and needs no lock.
///
/// A host has no parent to hand an output to, so a host over a module that asks something of its parent would
/// drop every request without a word. The `Output == Never` clause makes the compiler refuse it. In the app
/// the module is the root.
@MainActor @Observable
final class ModuleHost<M: FeatureModule> where M.Output == Never {
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

    private let module: M

    /// The event in flight, first, and those that arrived while it ran, in the order they arrived. An empty
    /// array is the one sign that nothing is in flight. Left out of observation, which would otherwise send
    /// every append and removal through the registrar for an observer that cannot exist, since it is private.
    @ObservationIgnored private var pending: [M.Event] = []

    /// Hands the world's entrance to `world`, once, after every property is set.
    ///
    /// The entrance holds the host weakly. The composition root gives it to the store as `onChange`, and the
    /// store is held by the module the host holds, so a strong one would close a cycle through the store:
    /// releasing the host would release nothing, and its database would stay open for the life of the
    /// process, beside whatever store is opened over the same file next (`Store`, ADR-0005).
    init(_ module: M, world: (@escaping @MainActor (M.Event) -> Void) -> Void) {
        self.module = module
        self.model = module.model
        world { [weak self] event in self?.deliver(event) }
    }

    func send(_ action: M.Event.UserAction) {
        deliver(.action(action))
    }

    private func deliver(_ event: M.Event) {
        pending.append(event)
        guard pending.count == 1 else { return }
        while let next = pending.first {
            // Always nil: the type admits only a module with nothing to ask of a parent, so there is no answer
            // to hand on.
            _ = module.send(next)
            model = module.model
            pending.removeFirst()
        }
    }
}
