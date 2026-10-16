// Sources/Features/TaskScreen/TaskScreen.swift
import FeatureModule
import TodoCore

/// One task on a screen of its own: its title, read from the store, and nothing a person can edit yet.
///
/// It is the first screen opened from below the root, the child of the list of a view's tasks, and the first
/// that needs a stack, which is why the epic builds one (spec section 10). What it holds is exactly what makes
/// the navigation to it real: a head, the id of its task, and a title to show that it arrived. The editor is
/// M4's.
///
/// It is a routable module (spec section 4): its route is the task's id and has no tail, because nothing
/// opens inside it yet.
public final class TaskScreen: Routable {
    public struct Model: Equatable, Sendable {
        /// The title as the last read of the task answered.
        public let title: String
    }

    /// The address of the screen: the task it shows, and nothing after it (spec section 2).
    public struct Route: RouteValue {
        /// The task the screen is on, which is what makes this screen this one: a route to another task is
        /// another screen, which the seat holding this one makes in its place (spec section 3).
        public let head: TaskID

        public init(head: TaskID) {
            self.head = head
        }
    }

    /// Nothing yet: the screen shows a title and offers nothing to do with it. The type is there because the
    /// contract asks every module for one and `Event` lifts it, and it has no case, so a view of this screen
    /// can send nothing (ADR-0006).
    public enum UserAction: Equatable, Sendable {}

    public enum Event: RoutedEvent {
        /// Never sent, since `UserAction` has no case to send: the case is the contract's (`FeatureEvent`),
        /// and `send` has no arm for it, because there is no value of it to switch over.
        case action(UserAction)
        case changed(ChangeSet)

        /// The parent has just made this screen: sent once by the seat that holds it, right after `init`. The
        /// screen has no choice to report, so it answers nothing.
        case created

        /// A route onto this same task, which is the only route a live screen is handed: a seat sends `.route`
        /// only when the head is the one it holds, so the screen reads the tail, and there is none.
        case route(Route)
    }

    public enum Output: Equatable, Sendable {
        /// The task is gone, so the screen asks its parent to drop it (spec section 3): the stack it was pushed
        /// onto pops on every platform (spec section 6), and the mechanism is the way back's with the store as
        /// the occasion.
        case closeRequested
    }

    /// What a view draws, computed from the state on every read and never kept beside it, as every module's
    /// model is (owner's review of #101).
    public var model: Model { state.model }

    /// A constant, because the head of a live module never changes and this route has no tail (spec section
    /// 3, `docs/style.md`): nothing that happens to the screen can change its address.
    public let route: Route

    private let store: Store

    private var state: State

    /// Made from its route, the one way a screen is made (spec section 3). A task the store does not hold, one
    /// deleted since a link was written or one a peer deleted under a tap, is refused with `.notFound` and the
    /// task's id: a screen on a task that is gone is not made, and the parent, which catches what this
    /// throws, keeps what was open and says so (spec section 3, the fourth flow). A store that cannot be read
    /// throws what it threw, which the parent tells apart from a task that is gone.
    public init(store: Store, route: Route) throws(StoreError) {
        guard let task = try store.task(route.head) else { throw .notFound(route.head) }
        self.store = store
        self.route = route
        self.state = State(title: task.title)
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .changed(let changes):
            // A commit that touched another task touched nothing on this screen, and the guard is what keeps a
            // write to another task, from quick entry or from a peer, from costing this screen a read. A commit
            // naming this task can have changed its title or deleted it, and the read tells the two apart.
            guard changes.tasks.contains(route.head) else { return nil }
            do {
                guard let task = try store.task(route.head) else { return .closeRequested }
                state.title = task.title
            } catch {
                // The title stays. A read that failed says nothing about the task, and a screen emptied by it
                // would show nothing in place of what is still likely true; the screen has no sentence of its
                // own to say it in, and the next change naming the task reads again.
            }
            return nil
        case .created, .route:
            return nil
        }
    }

    /// Everything the screen holds between two events besides its route and the store: the title as the last
    /// read answered. The model is computed from it, which is the shape every module has, one with a single
    /// field included (owner's review of #101).
    private struct State {
        var title: String

        /// The model a view draws: the title.
        var model: Model { Model(title: title) }
    }
}
