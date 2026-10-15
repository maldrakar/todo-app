import Testing
import FeatureModule

/// A child with nothing of a feature in it and no store behind it, so that the seat's rules are held without
/// a feature module or a dependency: the seat makes its child with whatever its parent handed it, and this
/// one needs nothing but its route.
///
/// It answers every event by naming it, so that what the seat returns says which event the child was sent,
/// and its model carries its own identity and every event it has been sent since it was made: the seat hands
/// out the child's model and route and never the child, and those two fields are what tell a child kept from
/// a child made again.
private final class Stub: Routable {
    struct Route: RouteValue {
        let head: Int
        let tail: String
    }

    struct Model: Equatable, Sendable {
        let instance: ObjectIdentifier
        let received: [Event]
    }

    enum UserAction: Equatable, Sendable {
        case buttonTapped
    }

    enum Event: RoutedEvent {
        case action(UserAction)
        case created
        case route(Route)
    }

    enum Output: Equatable, Sendable {
        case answered(Event)
    }

    var model: Model { Model(instance: ObjectIdentifier(self), received: received) }

    private(set) var route: Route

    private var received: [Event] = []

    init(route: Route) {
        self.route = route
    }

    func send(_ event: Event) -> Output? {
        received.append(event)
        if case .route(let route) = event { self.route = route }
        return .answered(event)
    }
}

/// What the stub's factory throws for a head the test names as one that cannot be made, the way a screen's
/// `init` refuses to be made on a task that is gone (spec section 3).
private struct Refusal: Error, Equatable {
    let head: Int
}

/// A seat over the stub whose factory refuses the heads given and makes a child for every other, built once,
/// the way a parent builds each seat it holds.
private func stubSeat(refusing refused: Set<Int> = []) -> Seat<Stub, Refusal> {
    Seat { route throws(Refusal) in
        guard !refused.contains(route.head) else { throw Refusal(head: route.head) }
        return Stub(route: route)
    }
}

@Test func anEmptySeatHasNoRouteAndNoModel() {
    let seat = stubSeat()
    #expect(seat.route == nil)
    #expect(seat.model == nil)
}

/// Being created is the child's first event, and its answer is the first choice the parent hears of, on the
/// line every later answer takes (ADR-0006, amendment of 2026-10-03).
@Test func applyingARouteToAnEmptySeatMakesTheChildAndAnswersItsCreatedAnswer() throws {
    var seat = stubSeat()
    let route = Stub.Route(head: 1, tail: "first")
    #expect(try seat.apply(route) == .answered(.created))
    #expect(seat.route == route)
    #expect(seat.model?.received == [.created], "told once that it was created, and nothing else")
}

/// The same head is the same screen, so the child that is open stays open, with whatever session state it
/// holds, and looks at the tail alone (spec section 3).
@Test func applyingTheSameHeadKeepsTheChildAndHandsItTheRoute() throws {
    var seat = stubSeat()
    _ = try seat.apply(Stub.Route(head: 1, tail: "first"))
    let made = try #require(seat.model)
    let next = Stub.Route(head: 1, tail: "second")
    #expect(try seat.apply(next) == .answered(.route(next)))
    #expect(seat.model?.instance == made.instance, "the child that was open, by identity")
    #expect(seat.model?.received == [.created, .route(next)], "created once, and handed the new tail")
    #expect(seat.route == next)
}

/// A different head is a different screen, which a live module never becomes: the seat makes a new child and
/// tells it it was created, as it would an empty seat (spec section 3).
@Test func applyingADifferentHeadReplacesTheChild() throws {
    var seat = stubSeat()
    _ = try seat.apply(Stub.Route(head: 1, tail: "first"))
    let replaced = try #require(seat.model)
    let route = Stub.Route(head: 2, tail: "first")
    #expect(try seat.apply(route) == .answered(.created))
    #expect(seat.model?.instance != replaced.instance, "a new child")
    #expect(seat.model?.received == [.created], "told it was created, and handed no route on top")
    #expect(seat.route == route)
}

@Test func applyingNilDropsTheChild() throws {
    var seat = stubSeat()
    _ = try seat.apply(Stub.Route(head: 1, tail: "first"))
    _ = try #require(seat.model, "the child is the setup; without it this proves nothing")
    #expect(try seat.apply(nil) == nil, "a child that is let go is asked nothing")
    #expect(seat.route == nil)
    #expect(seat.model == nil)
}

/// A screen that cannot be made leaves the one that was open, and the parent says so in its own model (spec
/// section 3): the seat throws what the factory threw, typed, so that the parent has something to say it
/// about, and keeps what it had.
@Test func aChildThatCannotBeMadeLeavesTheSeatAsItWas() throws {
    var seat = stubSeat(refusing: [2])
    _ = try seat.apply(Stub.Route(head: 1, tail: "first"))
    let open = try #require(seat.model, "the child is the setup; without it this proves nothing")
    let route = seat.route
    #expect(throws: Refusal(head: 2)) { try seat.apply(Stub.Route(head: 2, tail: "first")) }
    #expect(seat.model == open, "the same child, sent nothing since")
    #expect(seat.route == route)
}

/// The seat hands on any event the parent spells, and an empty seat has nobody to hand it to.
@Test func sendOnAnEmptySeatAnswersNothing() throws {
    let seat = stubSeat()
    #expect(seat.send(.action(.buttonTapped)) == nil)
    // The same event to a seat with a child in it, so that the nil above is the empty seat's and not the
    // event's.
    var full = stubSeat()
    _ = try full.apply(Stub.Route(head: 1, tail: "first"))
    #expect(full.send(.action(.buttonTapped)) == .answered(.action(.buttonTapped)))
    #expect(full.model?.received == [.created, .action(.buttonTapped)])
}

/// What a parent does with a child that asked to be closed (spec section 3): the child goes, and the next
/// route makes one anew rather than finding the old one behind the empty seat.
@Test func droppingEmptiesTheSeat() throws {
    var seat = stubSeat()
    _ = try seat.apply(Stub.Route(head: 1, tail: "first"))
    _ = try #require(seat.model, "the child is the setup; without it this proves nothing")
    seat.drop()
    #expect(seat.route == nil)
    #expect(seat.model == nil)
    #expect(try seat.apply(Stub.Route(head: 1, tail: "first")) == .answered(.created))
}

/// A child that cannot fail to be made, a screen that reads nothing, gives a seat that cannot throw: its
/// factory throws nothing, so the seat's failure is `Never` and `apply` is called without `try`, which is
/// what the call sites below are the evidence of. The factory is handed the route the parent applied, and
/// only when a child is made: a route that keeps the child never reaches it.
@Test func aSeatWhoseChildCannotFailIsAppliedWithoutTryAndMakesItFromTheRouteApplied() {
    var handed: [Stub.Route] = []
    var seat = Seat<Stub, Never> { route in
        handed.append(route)
        return Stub(route: route)
    }
    let first = Stub.Route(head: 1, tail: "first")
    #expect(seat.apply(first) == .answered(.created))
    #expect(handed == [first], "the route applied, and nothing else")
    let kept = Stub.Route(head: 1, tail: "second")
    #expect(seat.apply(kept) == .answered(.route(kept)))
    #expect(handed == [first], "the same head keeps the child, so the factory is not asked again")
    let other = Stub.Route(head: 2, tail: "first")
    #expect(seat.apply(other) == .answered(.created))
    #expect(handed == [first, other])
}
