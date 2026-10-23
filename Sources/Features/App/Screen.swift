// Sources/Features/App/Screen.swift
import FeatureModule
import TaskListFeature
import TaskScreenFeature
import TaskViewListFeature
import TodoCore

extension AppModule {
    /// The model of a screen standing in the window's stack, one case per kind, which the root view switches over in
    /// one place to pick a view per case, every case drawn and none by `default`, so that a kind added to the stack
    /// and not drawn stops the view compiling (`docs/style.md`, "Views"; navigation state spec, section 6). Each is
    /// the screen's own model, carried whole.
    public enum ScreenModel: Equatable, Sendable {
        case list(TaskList.Model)
        case task(TaskScreen.Model)
    }

    /// What a view of a screen standing in the window's stack may send, one case per kind of screen that has
    /// actions, each its own actions as they came. The task screen has none to send, its actions being an empty
    /// enum, so it has no case.
    public enum ScreenAction: Equatable, Sendable {
        case list(TaskList.UserAction)
    }

    /// The kinds of screen that stand in a window's stack over the sidebar, holding the modules, with the mappings
    /// the stack needs to reach each without knowing which it holds (navigation state spec, section 2; ADR-0009,
    /// amendment of 2026-10-22, points 2 and 3).
    ///
    /// Every mapping is a `switch` over the cases with no `default`, and decides nothing: a pairing that cannot
    /// occur, a task's answer handed to the sidebar, an action for a list sent to a task, answers nothing. A list
    /// stands only on the sidebar and a task only on a list, so the sidebar declares only a list and the list only a
    /// task, and neither hears the other's answer. The root learns from it which kinds of screen its window can hold
    /// and never which opens which, which stays in the openers' destinations.
    ///
    /// The task screen declares nothing over it, so its destination is an empty one, which the stack follows once,
    /// dropping nothing, and passes over after that. Swift 6.4 infers neither `Base` nor `Failure` from the
    /// requirements that use them, so both are spelled.
    enum Screen: StackScreen {
        typealias Base = TaskViewList
        typealias Model = ScreenModel
        typealias Failure = StoreError

        case list(TaskList)
        case task(TaskScreen)

        /// The route of a screen of the stack, whose head tells the kinds apart, so that the stack compares a
        /// declaration with what stands by head alone.
        enum Route: RouteValue {
            case list(TaskList.Route)
            case task(TaskScreen.Route)

            enum Head: Equatable, Sendable {
                case list(ViewID)
                case task(TaskID)
            }

            var head: Head {
                switch self {
                case .list(let route): .list(route.head)
                case .task(let route): .task(route.head)
                }
            }

            /// The list's route, nil for a task's: the part of a route the sidebar reads, as its declaration and as
            /// what stands over it. One accessor per case, since the payload of one case of an optional route does
            /// not typecheck inline in an argument (plan, Task 1, "Verified facts and traps").
            var list: TaskList.Route? {
                guard case .list(let route) = self else { return nil }
                return route
            }

            /// The task screen's route, nil for a list's: the part of a route a list reads.
            var task: TaskScreen.Route? {
                guard case .task(let route) = self else { return nil }
                return route
            }
        }

        /// What the root hands an element: an action its view sent, or a change the store committed.
        enum Event {
            case action(ScreenAction)
            case changed(ChangeSet)
        }

        /// What a screen of the stack answers, which the stack hands its opener.
        enum Output {
            case list(TaskList.Output)
            case task(TaskScreen.Output)
        }

        var route: Route {
            switch self {
            case .list(let list): .list(list.route)
            case .task(let task): .task(task.route)
            }
        }

        var model: ScreenModel {
            switch self {
            case .list(let list): .list(list.model)
            case .task(let task): .task(task.model)
            }
        }

        var destination: Destination<Route> {
            switch self {
            case .list(let list): list.destination.map(Route.task)
            case .task: Destination()
            }
        }

        func send(_ event: Event) -> Output? {
            switch (self, event) {
            case (.list(let list), .action(.list(let action))): list.send(.action(action)).map(Output.list)
            case (.list(let list), .changed(let changes)): list.send(.changed(changes)).map(Output.list)
            case (.task(let task), .changed(let changes)): task.send(.changed(changes)).map(Output.task)
            case (.task, .action(.list)): nil
            }
        }

        /// A notice of the stack, in each module's own terms: `.declared` reaches a kept screen as its `.route`, and
        /// the rest as the events of the same names. The task screen declares nothing, so nothing stands over it to
        /// answer it, be gone from over it or be refused it.
        func take(_ notice: StackNotice<Screen>) -> Output? {
            switch (self, notice) {
            case (.list(let list), .created): list.send(.created).map(Output.list)
            case (.list(let list), .declared(.list(let route))): list.send(.route(route)).map(Output.list)
            case (.list(let list), .answered(.task(let output))): list.send(.answered(output)).map(Output.list)
            case (.list(let list), .uncovered): list.send(.uncovered).map(Output.list)
            case (.list(let list), .notOpened(let error, let stillOpen)):
                list.send(.notOpened(error, stillOpen: stillOpen?.task)).map(Output.list)
            case (.task(let task), .created): task.send(.created).map(Output.task)
            case (.task(let task), .declared(.task(let route))): task.send(.route(route)).map(Output.task)
            case (.list, .declared(.task)), (.list, .answered(.list)), (.task, .declared(.list)):
                nil
            case (.task, .answered), (.task, .uncovered), (.task, .notOpened):
                nil
            }
        }

        func route(over above: Route?) -> Route {
            switch self {
            case .list(let list): .list(TaskList.Route(head: list.route.head, task: above?.task))
            case .task(let task): .task(task.route)
            }
        }

        static func destination(of base: TaskViewList) -> Destination<Route> {
            base.destination.map(Route.list)
        }

        static func take(_ notice: StackNotice<Screen>, base: TaskViewList) -> TaskViewList.Output? {
            switch notice {
            case .answered(.list(let output)): base.send(.answered(output))
            case .uncovered: base.send(.uncovered)
            case .notOpened(let error, let stillOpen): base.send(.notOpened(error, stillOpen: stillOpen?.list))
            case .created, .declared, .answered(.task): nil
            }
        }

        static func route(of base: TaskViewList, over above: Route?) -> TaskViewList.Route {
            TaskViewList.Route(list: above?.list)
        }
    }
}
