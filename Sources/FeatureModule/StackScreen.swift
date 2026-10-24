// Sources/FeatureModule/StackScreen.swift

/// The enum of the kinds of screen a flow's stack can hold, which the flow's owner declares: one case per kind,
/// holding the module, with the mappings a stack needs to reach the module in each case without knowing which
/// it holds (spec section 2, "The flow names the screens its stack can hold").
///
/// Screens of different types stand in one array, so the stack holds this enum and not the modules. Every
/// mapping is a `switch` over the cases that decides nothing, and a pairing of a screen and a notice that cannot
/// occur answers nothing. The owner learns from it which kinds of screen its window can hold and never which
/// opens which, which stays in the openers' destinations: a new kind is one case here, and a new transition
/// between kinds the enum has is nothing (ADR-0009, amendment of 2026-10-22, points 2 and 3). The lines a parent
/// wrote per child, its model, its actions and the forwarding of `.changed`, are this enum's, and an opener
/// keeps only its reaction to the `Output` of what it opened.
///
/// The flow's base is not a case. It is the owner's typed module, which the owner makes and hands to the stack,
/// and the stack reaches it through the three static requirements, so that the base's events, model and
/// answers keep their own types. Swift 6.4 infers neither `Base` nor `Failure` from the requirements that use
/// them, so a conforming enum spells `typealias Base` and `typealias Failure`.
public protocol StackScreen {
    /// The flow's base, the screen the stack stands on: for a window, the sidebar.
    associatedtype Base: Routable
    /// The route of a screen of the stack: an enum of the kinds' routes, whose head tells the kinds apart, so
    /// that the stack compares a declaration with what stands by head alone, the seat's rule.
    associatedtype Route: RouteValue
    /// What the owner hands its view for each element, by id.
    associatedtype Model: Equatable & Sendable
    /// What the owner hands an element through `ScreenStack.send(_:to:)`: an action its view sent, or an
    /// event of the world such as `.changed`.
    associatedtype Event
    /// What a screen of the stack answers, which goes to the screen right below it, its opener.
    associatedtype Output
    /// What making a screen can throw: `StoreError` for a screen that reads the store to be made.
    associatedtype Failure: Error

    /// The screen's own route, its head and what it declared, which the stack compares with its opener's
    /// declaration by head, and hands the opener as what stays open when a declaration cannot be met.
    var route: Route { get }

    /// The screen's model, which the owner carries into its own whole and decides nothing in.
    var model: Model { get }

    /// What the screen declared over it, its own destination lifted into this enum's route with
    /// `Destination.map`, which keeps the write mark the stack follows.
    var destination: Destination<Route> { get }

    /// Hands the screen an event the owner spells and returns its answer, which the stack hands its opener.
    func send(_ event: Event) -> Output?

    /// Hands the screen a notice of the stack, in the screen's own terms, and returns its answer, which the stack
    /// hands its opener.
    func take(_ notice: StackNotice<Self>) -> Output?

    /// The screen's route with what it declared replaced by the route of what stands over it, nil when nothing
    /// does, so that a declaration that has aged since it was written never reaches the text (spec section 3).
    func route(over above: Route?) -> Route

    /// The base's destination, lifted into this enum's route.
    static func destination(of base: Base) -> Destination<Route>

    /// Hands the base a notice and returns its answer, which goes to the owner. The stack never makes the base
    /// and never declares it, so the base is handed `.destinationAnswered`, `.uncovered` and `.notOpened`, and never
    /// `.created` or `.declared`.
    static func take(_ notice: StackNotice<Self>, base: Base) -> Base.Output?

    /// The base's route over what stands above it, nil when nothing does, which is the flow's route.
    static func route(of base: Base, over above: Route?) -> Base.Event.Route
}

/// What the stack tells a screen of its flow, beside the events the owner spells: what the walk did around the
/// screen. Each is an event of the world, which no view can send, named for what happened to the screen (ADR-0006,
/// amendment of 2026-10-22, point 3; ADR-0009, amendment of 2026-10-22, points 2 and 4).
public enum StackNotice<Screen: StackScreen> {
    /// The stack made the screen, and this is the first thing it hears. Its answer is its first choice, which
    /// reaches its opener on the line every later answer takes (ADR-0006, amendment of 2026-10-03).
    case created
    /// The screen's opener wrote its destination again with the head of this screen, so the stack kept the
    /// screen, with its session state, and hands it the route declared, once, which the screen reconciles its
    /// own destination to, as a seat hands a kept child its route (spec section 2).
    case declared(Screen.Route)
    /// The screen right over this one, which this one declared in its destination, answered this.
    case destinationAnswered(Screen.Output)
    /// The person went back to this screen: what was over it is gone already, so it empties its destination,
    /// which it cannot keep (spec section 3).
    case uncovered
    /// What the screen declared could not be made: why, and the route of what still stands over it, nil when
    /// nothing does, which the screen takes back as its destination, so that the declaration is tried once (spec
    /// section 2, and "Risks").
    case notOpened(Screen.Failure, stillOpen: Screen.Route?)
}
