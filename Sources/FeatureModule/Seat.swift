// Sources/FeatureModule/Seat.swift
import TodoCore

/// The place a parent holds one child in: empty, or holding the module a route made.
///
/// It does what does not depend on who the child is, so that no parent writes it again (spec section 4):
/// it makes the child from a route with the store and tells it it was created, keeps it, replaces it or
/// drops it as the next route asks, hands it the events the parent spells, and gives the parent the child's
/// route and model. What the child answers comes back from every call that reaches it, and what that answer
/// means is the parent's to decide, in a `switch` of its own (spec section 4).
///
/// A struct holding a class: a parent keeps it in a `var` of its own state, and a call that changes what the
/// seat holds is a mutation of that state, after which the parent assembles its model once, as it does after
/// every event (owner's review of #77). The child itself never leaves the seat: a parent reads its route and
/// its model, and learns its choices only from its answers (ADR-0006, amendment of 2026-10-03).
public struct Seat<Child: Addressed> {
    private var child: Child?

    /// An empty seat: nothing is open in it until a route is applied.
    public init() {}

    /// The route of the child in the seat, which is the tail its parent writes into its own route, and nil
    /// when the seat is empty.
    public var route: Child.Event.Route? { child?.route }

    /// The child's model, which its parent carries into its own whole and decides nothing in, and nil when
    /// the seat is empty.
    public var model: Child.Model? { child?.model }

    /// Applies a route to the seat, which is how a parent opens, moves and closes the child: a tap, a link, a
    /// relaunch and the way back each arrive here as a route (spec section 3).
    ///
    /// It reconciles by head and never rebuilds. No route drops the child. A route with the head of the child
    /// in the seat keeps it, with whatever session state it holds, and hands it `.route`, since the head of a
    /// live module never changes and such a module looks at the tail alone. Any other route, or a route into
    /// an empty seat, makes a new child, tells it it was created and returns its answer, its first choice.
    ///
    /// The new child is made before the old one is let go, so an `init` that throws leaves the seat holding
    /// what it held: a screen that could not be made leaves the one that was open, and the parent, which
    /// catches, says so in its own model (spec section 3).
    public mutating func apply(_ route: Child.Event.Route?, store: Store) throws(StoreError) -> Child.Output? {
        guard let route else {
            drop()
            return nil
        }
        if let child, child.route.head == route.head { return child.send(.route(route)) }
        let made = try Child(store: store, route: route)
        child = made
        return made.send(.created)
    }

    /// Hands an event the parent spells to the child, `seat.send(.changed(changes))` or an action its view
    /// sent, and returns the child's answer. The seat knows nothing of the events it carries, so an event of
    /// the world a child learns to take needs nothing here; an empty seat has nobody to hand it to and
    /// answers nothing.
    public func send(_ event: Child.Event) -> Child.Output? {
        child?.send(event)
    }

    /// Lets the child go, which is what a parent does when the child asks to be closed (spec section 3), and
    /// the path a route of nil takes too.
    public mutating func drop() {
        child = nil
    }
}
