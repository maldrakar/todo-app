// Sources/FeatureModule/Seat.swift

/// The place a parent holds one child in: empty, or holding the module a route made.
///
/// It does what does not depend on who the child is, so that no parent writes it again (spec section 4):
/// it makes the child from a route and tells it it was created, keeps it, replaces it or drops it as the
/// next route asks, hands it the events the parent spells, and gives the parent the child's route and model.
/// What the child answers comes back from every call that reaches it, and what that answer means is the
/// parent's to decide, in a `switch` of its own (spec section 4).
///
/// A struct holding a class: a parent keeps it in a `var` of its own state, and a call that changes what the
/// seat holds is a mutation of that state, after which the parent assembles its model once, as it does after
/// every event (owner's review of #77). The child itself never leaves the seat: a parent reads its route and
/// its model, and learns its choices only from its answers (ADR-0006, amendment of 2026-10-03).
///
/// `Failure` is what making the child can throw: `StoreError` for a screen that reads the store to be made,
/// and `Never` for one that cannot fail, whose seat is applied without `try`.
public struct Seat<Child: Routable, Failure: Error> {
    private let make: (Child.Event.Route) throws(Failure) -> Child

    private var child: Child?

    /// An empty seat, and the way to make its child from a route: the parent builds each seat once, with a
    /// closure that calls the child's own `init` with the route and what that child needs, so that the seat,
    /// and the contract it lives beside, name no dependency of any child (owner's review of #100).
    ///
    /// The closure captures the child's dependencies and never the parent. The parent holds the seat in its
    /// state, so a closure holding the parent would be a cycle, parent to state to seat to closure to parent,
    /// and neither would ever be released. A throwing closure names its error,
    /// `{ route throws(StoreError) in try TaskList(store: store, route: route) }`, and the parent's state
    /// declares the seat with that error, `Seat<TaskList, StoreError>`: a closure left to infer its error
    /// throws `any Error`, which a seat declared so refuses at compile time, where a seat whose type is left
    /// to inference would take it and become `Seat<TaskList, any Error>`.
    public init(make: @escaping (Child.Event.Route) throws(Failure) -> Child) {
        self.make = make
    }

    /// The route of the child in the seat, which is the tail its parent writes into its own route, and nil
    /// when the seat is empty.
    public var route: Child.Event.Route? { child?.route }

    /// The child's model, which its parent carries into its own whole and decides nothing in, and nil when
    /// the seat is empty.
    public var model: Child.Model? { child?.model }

    /// Applies a route to the seat, which is how a parent opens, moves and closes the child: a tap, a link, a
    /// relaunch and the way back each arrive here as a route (spec section 3).
    ///
    /// It reconciles by head and never rebuilds. A nil route drops the child. A route with the head of the child
    /// in the seat keeps it, with whatever session state it holds, and hands it `.route`, since the head of a
    /// live module never changes and such a module looks at the tail alone. Any other route, or a route into
    /// an empty seat, has the child made from it, tells the new child it was created and returns its answer,
    /// its first choice.
    ///
    /// The new child is made before the old one is let go, so a child that cannot be made leaves the seat
    /// holding what it held: a screen that could not be made leaves the one that was open, and the parent,
    /// which catches what the child's `init` threw, says so in its own model (spec section 3).
    public mutating func apply(_ route: Child.Event.Route?) throws(Failure) -> Child.Output? {
        guard let route else {
            drop()
            return nil
        }
        if let child, child.route.head == route.head { return child.send(.route(route)) }
        let made = try make(route)
        child = made
        return made.send(.created)
    }

    /// Hands an event the parent spells to the child, `seat.send(.changed(changes))` or an action its view
    /// sent, and returns the child's answer. The seat knows nothing of the events it carries, so an event of
    /// the world a child learns to take needs nothing here; an empty seat has nobody to hand it to and
    /// answers nothing. A route goes through `apply` instead, the one road that compares heads: a `.route`
    /// sent through here would skip the reconciliation and could hand a live module a new head, which spec
    /// section 3 rules out: the head of a live module never changes.
    public func send(_ event: Child.Event) -> Child.Output? {
        child?.send(event)
    }

    /// Lets the child go, which is what a parent does when the child asks to be closed (spec section 3), and
    /// the path a route of nil takes too.
    public mutating func drop() {
        child = nil
    }
}
