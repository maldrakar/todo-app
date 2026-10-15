// Sources/FeatureModule/Addressed.swift
import TodoCore

/// The address of a screen: a plain value with a head and a tail (spec section 2).
///
/// The head is what makes this screen this screen, the id of a task or a view, or `NoHead` for a screen of
/// which there is one. The tail is the rest, the routes of what is open inside it, and a conforming type
/// declares it as fields of its own. Only the head is required, because the head is the one thing a parent
/// reads without knowing which child it holds: its seat compares heads to decide whether a route keeps the
/// child or replaces it (spec section 3).
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

/// A module that can be opened: it is made from its route with the store, and says at any moment which
/// route it is on, so that a parent can make it, keep it and write it down without knowing what it is (spec
/// section 4, ADR-0009).
///
/// `init` throws, because a screen that cannot read what it shows is not made: its parent keeps whatever
/// was open and says so in its own model (spec section 3). `route` is assembled from the module's state,
/// its own head and its children's routes, and holds no session state: it is what the next launch opens
/// again, not a record of gestures (spec section 2).
public protocol Addressed: FeatureModule where Event: RoutedEvent {
    init(store: Store, route: Event.Route) throws(StoreError)
    var route: Event.Route { get }
}

/// The head of a screen of which there is one, such as the sidebar of a window: every value is the same
/// value, so a seat holding such a screen keeps it on every route it is handed rather than making it again,
/// and what the route says reaches the live module as its tail (spec section 2).
public struct NoHead: Hashable, Sendable {
    public init() {}
}
