// Sources/FeatureModule/Destination.swift

/// Where a screen declares what is open over it: nothing, or the route of the screen pushed over it, whole, as
/// the screen declared it, with its head, what it opens with and what it is to have open over it in turn (spec
/// section 1, which calls it the slot; the owner named it on 2026-10-23, because "slot" does not say what it
/// holds).
///
/// It is the screen's own state, and nobody but the screen writes it: a tap fills it, the way back empties it,
/// and a link writes it by `.route`. The flow's `ScreenStack` reads it after every event and follows it, so the
/// screen decides what is open over it without holding what it opened, and no module makes, keeps or drops a
/// screen of its flow but the stack (ADR-0009, amendment of 2026-10-22, points 1, 2 and 4). It is part of the
/// screen's route, read as a parent reads a route and never as a model (ADR-0006, amendment of 2026-10-03).
///
/// A destination holds a push or nothing. A modal is the other case the spec gives it, `presented`, and joins
/// `Declared` as a second generic parameter with the first screen that declares one, since nothing is added
/// before its caller (spec section 5, "Built in this epic"; `docs/style.md`).
public struct Destination<Pushed: RouteValue> {
    /// What a screen declares over it, which a destination holds or does not: a screen pushed over this one.
    public enum Declared: Equatable, Sendable {
        case pushed(Pushed)
    }

    /// What the screen declared last, nil when it declared nothing. The stack alone reads it whole, since what a
    /// screen and its readers need of it is the route it pushes, `pushed`.
    private(set) var declared: Declared?

    /// The write mark, moved by every `declare`, the same value written again included. It is how the
    /// destination tells a new write from an old one, which the spec left to the plan (spec section 2, "A slot
    /// written again is a new declaration"): the stack records, per opener, the mark it followed last, and never
    /// follows a mark twice. So a click on the view already highlighted, which writes the value the destination
    /// holds, is a new declaration all the same, and between two writes the screen over the opener owns its own
    /// destination. Only the stack reads it.
    private(set) var mark = 0

    /// A destination that declares nothing and has never been written.
    public init() {}

    private init(declared: Declared?, mark: Int) {
        self.declared = declared
        self.mark = mark
    }

    /// The route of the screen declared pushed over this one, nil when nothing is: the one read a screen and its
    /// readers make of it, the screen's `route` and the sidebar's highlight among them.
    public var pushed: Pushed? {
        guard case .pushed(let route)? = declared else { return nil }
        return route
    }

    /// Declares what is to be open over the screen, nil for nothing. Every call is a new write that the stack
    /// follows at the walk after the event, whatever the destination held before.
    public mutating func declare(_ declared: Declared?) {
        self.declared = declared
        mark += 1
    }

    /// The same declaration over another type of route, with the same write mark: what a flow's enum of screens
    /// gives the stack, each screen's destination over its own route lifted into the enum's route, so that the
    /// stack follows a write exactly once whichever type it is read through.
    public func map<Mapped: RouteValue>(_ transform: (Pushed) -> Mapped) -> Destination<Mapped> {
        let mapped: Destination<Mapped>.Declared? = switch declared {
        case .pushed(let route)?: .pushed(transform(route))
        case nil: nil
        }
        return Destination<Mapped>(declared: mapped, mark: mark)
    }
}
