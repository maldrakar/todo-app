// Sources/FeatureModule/Routable.swift

/// The address of a screen: a plain value with a head and a tail (spec section 2).
///
/// The head is what makes this screen this screen, the id of a task or a view, or `NoHead` for a screen of
/// which there is one. The tail is the rest: what is chosen or open inside it, and the argument it opens with
/// where it defines one; a conforming type declares it as fields of its own. Only the head is required,
/// because the head is the one thing a parent reads without knowing which child it holds: its seat compares
/// heads to decide whether a route keeps the child or replaces it (spec section 3).
///
/// A route is not a model. A `Model` is what a view draws; a route is what a parent reads from a child to
/// write the window down and what it hands a child to open it, and the two are separate so that neither has
/// to serve the other's reader (spec section 2).
public protocol RouteValue: Equatable, Sendable {
    associatedtype Head: Equatable & Sendable
    var head: Head { get }
}

/// The event of a module that can be opened, which spells the two events a parent sends it beside what its
/// view sends: `.route`, a route applied to a live module, and `.created`, sent once right after the module
/// is made.
///
/// Both are events of the world and neither is a `UserAction`, so a view, whose closure spells user actions
/// alone, can send neither (ADR-0006, amendment of 2026-10-14). The static requirements are what let a seat
/// send them without knowing which module it holds, the way `action(_:)` lets a host lift what a view sent.
public protocol RoutedEvent: FeatureEvent {
    associatedtype Route: RouteValue
    static func route(_ route: Route) -> Self
    static var created: Self { get }
}

/// A module that can be opened: it says at any moment which route it is on, and takes `.route` and
/// `.created` from its parent, so that a parent can keep it, reconcile it and write it down without knowing
/// what it is (spec section 4, ADR-0009).
///
/// It is made by an `init` of its own, from its route and whatever else it needs to be made, and the
/// protocol requires none: what a screen needs is that screen's, the store for one and nothing for another,
/// and a contract that named it would hand every screen a dependency some have no use for (owner's review of
/// #100). That `init` is where a screen that cannot read what it shows refuses to be made, which is why it
/// may throw: its parent keeps whatever was open and says so in its own model (spec section 3). The parent
/// hands the way to make the child to the seat that holds it (`Seat`), and a flow's owner hands the way to make
/// each kind of screen to its stack (`ScreenStack`).
///
/// `route` is assembled from the module's state, its own head and what it holds open: what it declared over it
/// in its destination, or the routes of the children it holds in seats. It holds no session state: it is what
/// the next launch opens again, not a record of gestures (spec section 2). A flow's owner writes its route from
/// what stands in its stack instead, so that a declaration that has aged never reaches the text (navigation state
/// spec, section 3).
public protocol Routable: FeatureModule where Event: RoutedEvent {
    var route: Event.Route { get }
}

/// The head of a screen of which there is one, such as the sidebar of a window: every value is the same
/// value, so a seat holding such a screen keeps it on every route it is handed rather than making it again,
/// and what the route says reaches the live module as its tail (spec section 2).
public struct NoHead: Equatable, Sendable {
    public init() {}
}
