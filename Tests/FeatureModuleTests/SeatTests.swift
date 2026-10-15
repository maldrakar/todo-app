import Testing
import TestSupport
import FeatureModule
import TodoCore

/// A child with nothing of a feature in it, so that the seat's rules are held without a feature module. Its
/// head is a task's id, as the task screen's will be, and it cannot be made for an id the store has no task
/// for, which is the one way a child's `init` fails that the seat has to survive (spec section 3).
///
/// It answers every event by naming it, so that what the seat returns says which event the child was sent,
/// and its model carries its own identity and every event it has been sent since it was made: the seat hands
/// out the child's model and route and never the child, and those two fields are what tell a child kept from
/// a child made again.
private final class Stub: Addressed {
    struct Route: RouteValue {
        let head: TaskID
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

    init(store: Store, route: Route) throws(StoreError) {
        guard try store.task(route.head) != nil else { throw .notFound(route.head) }
        self.route = route
    }

    func send(_ event: Event) -> Output? {
        received.append(event)
        if case .route(let route) = event { self.route = route }
        return .answered(event)
    }
}

@Test func anEmptySeatHasNoRouteAndNoModel() {
    let seat = Seat<Stub>()
    #expect(seat.route == nil)
    #expect(seat.model == nil)
}

/// Being created is the child's first event, and its answer is the first choice the parent hears of, on the
/// line every later answer takes (ADR-0006, amendment of 2026-10-03).
@Test func applyingARouteToAnEmptySeatMakesTheChildAndAnswersItsCreatedAnswer() throws {
    let store = try makeStore()
    let task = try store.createTask(NewTask(title: "Write it down"))
    var seat = Seat<Stub>()
    let route = Stub.Route(head: task, tail: "first")
    #expect(try seat.apply(route, store: store) == .answered(.created))
    #expect(seat.route == route)
    #expect(seat.model?.received == [.created], "told once that it was created, and nothing else")
}

/// The same head is the same screen, so the child that is open stays open, with whatever session state it
/// holds, and looks at the tail alone (spec section 3).
@Test func applyingTheSameHeadKeepsTheChildAndHandsItTheRoute() throws {
    let store = try makeStore()
    let task = try store.createTask(NewTask(title: "Write it down"))
    var seat = Seat<Stub>()
    _ = try seat.apply(Stub.Route(head: task, tail: "first"), store: store)
    let made = try #require(seat.model)
    let next = Stub.Route(head: task, tail: "second")
    #expect(try seat.apply(next, store: store) == .answered(.route(next)))
    #expect(seat.model?.instance == made.instance, "the child that was open, by identity")
    #expect(seat.model?.received == [.created, .route(next)], "created once, and handed the new tail")
    #expect(seat.route == next)
}

/// A different head is a different screen, which a live module never becomes: the seat makes a new child and
/// tells it it was created, as it would an empty seat (spec section 3).
@Test func applyingADifferentHeadReplacesTheChild() throws {
    let store = try makeStore()
    let first = try store.createTask(NewTask(title: "First"))
    let second = try store.createTask(NewTask(title: "Second"))
    var seat = Seat<Stub>()
    _ = try seat.apply(Stub.Route(head: first, tail: "first"), store: store)
    let replaced = try #require(seat.model)
    let route = Stub.Route(head: second, tail: "first")
    #expect(try seat.apply(route, store: store) == .answered(.created))
    #expect(seat.model?.instance != replaced.instance, "a new child")
    #expect(seat.model?.received == [.created], "told it was created, and handed no route on top")
    #expect(seat.route == route)
}

@Test func applyingNilDropsTheChild() throws {
    let store = try makeStore()
    let task = try store.createTask(NewTask(title: "Write it down"))
    var seat = Seat<Stub>()
    _ = try seat.apply(Stub.Route(head: task, tail: "first"), store: store)
    _ = try #require(seat.model, "the child is the setup; without it this proves nothing")
    #expect(try seat.apply(nil, store: store) == nil, "a child that is let go is asked nothing")
    #expect(seat.route == nil)
    #expect(seat.model == nil)
}

/// A screen that cannot be made leaves the one that was open, and the parent says so in its own model (spec
/// section 3): the seat throws, so that the parent has something to say it about, and keeps what it had.
@Test func aChildThatCannotBeMadeLeavesTheSeatAsItWas() throws {
    let store = try makeStore()
    let task = try store.createTask(NewTask(title: "Write it down"))
    var seat = Seat<Stub>()
    _ = try seat.apply(Stub.Route(head: task, tail: "first"), store: store)
    let open = try #require(seat.model, "the child is the setup; without it this proves nothing")
    let route = seat.route
    let gone = TaskID()
    #expect(throws: StoreError.notFound(gone)) { try seat.apply(Stub.Route(head: gone, tail: "first"), store: store) }
    #expect(seat.model == open, "the same child, sent nothing since")
    #expect(seat.route == route)
}

/// The seat hands on any event the parent spells, and an empty seat has nobody to hand it to.
@Test func sendOnAnEmptySeatAnswersNothing() throws {
    let seat = Seat<Stub>()
    #expect(seat.send(.action(.buttonTapped)) == nil)
    // The same event to a seat with a child in it, so that the nil above is the empty seat's and not the
    // event's.
    let store = try makeStore()
    let task = try store.createTask(NewTask(title: "Write it down"))
    var full = Seat<Stub>()
    _ = try full.apply(Stub.Route(head: task, tail: "first"), store: store)
    #expect(full.send(.action(.buttonTapped)) == .answered(.action(.buttonTapped)))
    #expect(full.model?.received == [.created, .action(.buttonTapped)])
}

/// What a parent does with a child that asked to be closed (spec section 3): the child goes, and the next
/// route makes one anew rather than finding the old one behind the empty seat.
@Test func droppingEmptiesTheSeat() throws {
    let store = try makeStore()
    let task = try store.createTask(NewTask(title: "Write it down"))
    var seat = Seat<Stub>()
    _ = try seat.apply(Stub.Route(head: task, tail: "first"), store: store)
    _ = try #require(seat.model, "the child is the setup; without it this proves nothing")
    seat.drop()
    #expect(seat.route == nil)
    #expect(seat.model == nil)
    #expect(try seat.apply(Stub.Route(head: task, tail: "first"), store: store) == .answered(.created))
}
