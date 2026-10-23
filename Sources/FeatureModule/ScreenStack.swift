// Sources/FeatureModule/ScreenStack.swift

/// The identity of an element of a `ScreenStack`, which the stack hands out in order and never twice, so that
/// the same kind of screen can stand twice, a task over a task, the view finds an element's model without a
/// search, and SwiftUI has a stable identity for a pushed screen (spec section 2, "Each element of the stack
/// has an id"). It is opaque: nothing but the stack makes one, and it is never written into the text form of a
/// route.
public struct StackElementID: Hashable, Sendable {
    private let number: Int

    fileprivate init(_ number: Int) {
        self.number = number
    }
}

/// The screens open over a flow's base, held flat, base first, and the walk that follows what each of them
/// declares (spec section 2; ADR-0009, amendment of 2026-10-22, point 2). A flow is a window today, and a modal
/// with screens of its own when one is built.
///
/// The base is not an element. It is the owner's typed module, made by the owner and handed to the stack, which
/// keeps it to itself: the owner reads its model through `baseModel` and reaches it only through `send(_:)`, so
/// no event reaches the base without the walk after it. The elements over it are the cases of the owner's enum
/// of screens, in `path`, bottom up, each with an id the stack hands out.
///
/// After every call the stack walks up from the base, and at each opener, the base or an element, whose
/// destination holds a write the stack has not followed, it follows that write by the seat's rule: a write that
/// declares nothing drops everything above the opener; one with the head of the screen above keeps that screen,
/// with its session state, and hands it `.declared(route)` once; another head makes the declared screen before
/// anything is let go, replaces everything above with it and hands it `.created`. A screen that cannot be made
/// leaves what stands, and its opener takes `.notOpened` with the route of what still stands over it. What a
/// screen answers goes down: its opener takes `.answered(output)`, the opener's answer goes to its own opener,
/// and the base's answers come back out of the call, to the owner (spec section 2, "Answers go to the
/// opener").
///
/// A struct holding classes, like `Seat`: the owner keeps it in a `var` of its own state, and a call that moves
/// what stands is a mutation of that state, which the owner's model, computed from the state, shows at its next
/// read (`docs/style.md`, "A module's model is computed from its state").
public struct ScreenStack<Screen: StackScreen> {
    /// A screen of the stack, with its id, and the write mark of its destination the stack followed last, nil
    /// until the first walk over it.
    private struct Element {
        let id: StackElementID
        let screen: Screen
        var followed: Int?
    }

    private let base: Screen.Base

    private let make: (Screen.Route) throws(Screen.Failure) -> Screen

    private var elements: [Element] = []

    /// The write mark of the base's destination the stack followed last, nil until the first walk.
    private var baseFollowed: Int?

    /// How many ids the stack has handed out, which is the number of the last one.
    private var handedOut = 0

    /// A stack with nothing over its base, and the way to make a screen of it from a route: the owner builds it
    /// once, with a closure that switches over the route and calls the `init` of the kind of screen it names
    /// with what that screen needs, so that the stack, and the target it lives in, name no dependency of any
    /// screen (ADR-0007, amendment of 2026-10-15).
    ///
    /// The closure captures the screens' dependencies and never the owner, which holds the stack in its state:
    /// a closure holding the owner would be a cycle that is never released, as it would be for a seat. It names
    /// its error, which is the enum's `Failure`.
    ///
    /// It does not walk, since an `init` has nowhere to put the base's answers. The owner's first call,
    /// `send(.created)`, makes the first walk, so the base hears `.created` before any notice, and a screen the
    /// stack makes hears `.created` before anything else (ADR-0006, amendment of 2026-10-03).
    public init(base: Screen.Base, make: @escaping (Screen.Route) throws(Screen.Failure) -> Screen) {
        self.base = base
        self.make = make
    }

    /// The base's model, which the owner carries into its own whole and decides nothing in.
    public var baseModel: Screen.Base.Model { base.model }

    /// The ids of the screens over the base, bottom up, which the owner hands its view as the path it binds.
    public var path: [StackElementID] { elements.map(\.id) }

    /// The model of each screen over the base, by id, so that the view finds an element's model without a
    /// search.
    public var models: [StackElementID: Screen.Model] {
        elements.reduce(into: [:]) { models, element in models[element.id] = element.screen.model }
    }

    /// The flow's route, written from the top down: each element's route with what it declared replaced by the
    /// route of what actually stands over it, then the base's, so that a declaration that has aged since it was
    /// written never reaches the text (spec section 3).
    public var route: Screen.Base.Event.Route {
        let above = elements.reversed().reduce(nil as Screen.Route?) { above, element in
            element.screen.route(over: above)
        }
        return Screen.route(of: base, over: above)
    }

    /// Hands the base an event the owner spells, `.created` first, then a link's `.route`, `.changed` and the
    /// actions its view sent, and walks.
    ///
    /// When one call draws more than one answer from the base, the owner gets the first drawn, the base's answer
    /// to the event itself before any the walk draws. A window's base answers only a gesture made on it, so it
    /// answers once at most.
    public mutating func send(_ event: Screen.Base.Event) -> Screen.Base.Output? {
        walk(after: base.send(event))
    }

    /// Hands an element an event the owner spells, an action its view sent or `.changed`, hands its answer down,
    /// and walks; the answer that came down is returned before any the walk draws. An id the stack does not hold,
    /// one it dropped since the view read it, moves nothing and answers nothing.
    public mutating func send(_ event: Screen.Event, to id: StackElementID) -> Screen.Base.Output? {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return nil }
        let answer = elements[index].screen.send(event).flatMap { hand(.answered($0), to: index) }
        return walk(after: answer)
    }

    /// Takes the way back, which SwiftUI reports only as the shorter path it wrote, whole, from the back button,
    /// the swipe from the edge or the long-press menu that goes back several screens at once (spec section 3).
    ///
    /// It moves only a strict prefix of `path`. An id the stack never gave, a path that is not a prefix, the
    /// same path and a longer one move nothing, so a write SwiftUI makes after a pop the model drove changes
    /// nothing (spec section 3, "A pop the model drove"). Otherwise it drops everything above the prefix, then
    /// tells the screen now on top, or the base, `.uncovered`, and walks: the screen cannot keep a destination the
    /// person closed, since what was over it is already gone. The answer that came down is returned before any
    /// the walk draws.
    public mutating func wentBack(to path: [StackElementID]) -> Screen.Base.Output? {
        guard path.count < elements.count, self.path.starts(with: path) else { return nil }
        elements.removeSubrange(path.count...)
        return walk(after: hand(.uncovered, to: path.count))
    }

    /// The walk after a call, which runs on every call that moved something, and returns `answer`, the base's
    /// answer the call itself drew, or, when the call drew none, the first the walk drew.
    ///
    /// It goes up the openers, passing over each whose write mark it has followed, and follows the first new
    /// write it meets, which it records as followed first. It then starts again from the base, so that a lower
    /// destination an answer moved while the write was followed is followed before anything above it; a pass
    /// over an opener whose write is followed is one comparison. A mark moves only when a screen declares, so
    /// the walk ends once what it hands the screens has them declare nothing new. It is a loop and not a
    /// recursion, so a chain of screens as deep as a link can make costs the call stack nothing.
    private mutating func walk(after answer: Screen.Base.Output?) -> Screen.Base.Output? {
        var first = answer
        var level = 0
        while level <= elements.count {
            let destination = destination(at: level)
            guard destination.mark != followed(at: level) else {
                level += 1
                continue
            }
            recordFollowed(at: level)
            let drawn = follow(destination.declared, at: level)
            first = first ?? drawn
            level = 0
        }
        return first
    }

    /// Follows a write of the destination at `level`, and returns the first answer it drew from the base. A
    /// write that declares nothing drops everything above the opener, which answers nothing.
    private mutating func follow(
        _ declared: Destination<Screen.Route>.Declared?,
        at level: Int
    ) -> Screen.Base.Output? {
        switch declared {
        case nil:
            elements.removeSubrange(level...)
            return nil
        case .pushed(let route)?:
            return push(route, at: level)
        }
    }

    /// Has `route` stand over the opener at `level`, by the seat's rule, and returns the first answer it drew from
    /// the base.
    ///
    /// The screen above with the route's head is kept and handed the route. Any other screen is made before
    /// anything is let go, so that one that cannot be made leaves what stands: the opener is told why and what
    /// still stands over it, and takes that back as its destination, which the stack records as followed, so
    /// that the declaration is tried once and the screen over the opener is handed nothing (spec, "Risks").
    private mutating func push(_ route: Screen.Route, at level: Int) -> Screen.Base.Output? {
        let above = level < elements.count ? elements[level].screen : nil
        if let above, above.route.head == route.head {
            return hand(.declared(route), to: level + 1)
        }
        let made: Screen
        do {
            made = try make(route)
        } catch {
            let answer = hand(.notOpened(error, stillOpen: above?.route), to: level)
            recordFollowed(at: level)
            return answer
        }
        elements.removeSubrange(level...)
        handedOut += 1
        elements.append(Element(id: StackElementID(handedOut), screen: made))
        return hand(.created, to: level + 1)
    }

    /// Hands `notice` to the opener at `level`, and each answer on down, the answer of the opener at one level to
    /// the opener at the level below, until one answers nothing or the base answers, whose answer is returned.
    private func hand(_ notice: StackNotice<Screen>, to level: Int) -> Screen.Base.Output? {
        var notice = notice
        var level = level
        while level > 0 {
            guard let answer = elements[level - 1].screen.take(notice) else { return nil }
            notice = .answered(answer)
            level -= 1
        }
        return Screen.take(notice, base: base)
    }

    /// The destination of the opener at `level`. The openers stand at levels: the base at 0, and the element at
    /// index `n` of `elements` at `n + 1`, so that what stands over the opener at a level is the element at that
    /// index, when there is one.
    private func destination(at level: Int) -> Destination<Screen.Route> {
        level == 0 ? Screen.destination(of: base) : elements[level - 1].screen.destination
    }

    /// The write mark of the destination at `level` the stack followed last, nil until the first walk over it.
    private func followed(at level: Int) -> Int? {
        level == 0 ? baseFollowed : elements[level - 1].followed
    }

    /// Records the write mark the destination at `level` holds now as followed, so that it is never followed
    /// again.
    private mutating func recordFollowed(at level: Int) {
        let mark = destination(at: level).mark
        if level == 0 {
            baseFollowed = mark
        } else {
            elements[level - 1].followed = mark
        }
    }
}
