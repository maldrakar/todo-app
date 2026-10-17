// Sources/Features/QuickEntry/QuickEntry.swift
import FeatureModule
import TodoCore

/// A field and a button that put a task in the Inbox: what a person types becomes the title of a new task, and
/// once the task exists the module asks its parent to close it.
///
/// It is the root's child on every platform and is drawn as a sheet on every Apple platform (spec section 5).
/// What it holds is exactly what makes the modal real: a draft, a write, and the two ways it ends, a task
/// created and a person who changed their mind. Which view it files into, a date, a tag: M4's (spec section
/// 10).
///
/// It is a routable module (spec section 4): its route has no head, because a window has one quick entry, and
/// no tail, because nothing opens inside it and no argument opens it in this epic (spec section 2).
public final class QuickEntry: Routable {
    /// The address of quick entry, the same for every one: it says that quick entry is up and nothing else,
    /// since what a person has typed is session state and no route carries it (spec section 2).
    public struct Route: RouteValue {
        /// The same for every quick entry, so a route that keeps quick entry up, `?quick-entry` in the
        /// window's text form, keeps the live one alive, and its draft with it, rather than making it again
        /// (spec sections 2 and 3).
        public var head: NoHead { NoHead() }

        public init() {}

        /// The name of the query item that says quick entry is up in a window's text form, by which the window
        /// knows that an item is this route's and hands it here alone (spec section 2).
        package static let name = "quick-entry"

        /// Reads its item, which is the bare name, since no screen in this epic opens with an argument (spec
        /// section 2): anything else, the name with a value included, an empty one too, is refused as written.
        package init(item: String) throws(RouteError) {
            guard item == Route.name else { throw .unknownQuery(item) }
        }

        /// This route's item in a window's query.
        package var item: String { Route.name }
    }

    public struct Model: Equatable, Sendable {
        /// The text of the field, as the person typed it, down to the spaces at its ends: what the store gets
        /// is that text trimmed (`add`), since a caret is no place for the module to be moving text about.
        public let draft: String

        /// What went wrong, as the finished sentence the view shows, and nil when there is nothing to say:
        /// `send` cannot throw, so a refusal inside it has nowhere else to go, and a view that had to spell one
        /// would be a view holding logic (`docs/specs/feature-module-architecture.md`, section 2).
        public let problem: String?
    }

    /// What a view may send. Each case is named for the control and the gesture and never for what the module
    /// does about it, so that what a gesture means is decided here (ADR-0006, `docs/style.md`).
    public enum UserAction: Equatable, Sendable {
        /// The text of the field, on every keystroke.
        case titleFieldChanged(String)
        /// Return in the field.
        case titleFieldSubmitted
        /// The Add button.
        case addButtonTapped
        /// The sheet's Cancel button, tapped, or the swipe down or Esc that do the same: SwiftUI reports those
        /// two as one write of false through the sheet's binding, and the view sends this for it. It names the
        /// control and the gesture, and closing is what quick entry decides it means (owner's ruling on #101),
        /// where the spec has the root's `quickEntryDismissed` (`docs/plans/navigation.md`, Deviations).
        case cancelButtonTapped
    }

    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)

        /// The parent has just made quick entry: sent once by the seat that holds it, right after `init`. Quick
        /// entry has no choice to report, so it answers nothing.
        case created

        /// A route applied to the live quick entry, which has no head to change and no tail to read, so it
        /// moves nothing.
        case route(Route)
    }

    public enum Output: Equatable, Sendable {
        /// Quick entry is done, with a task created or with none, and asks its parent to drop it: the modal's
        /// own half of the way back (spec section 5).
        case closeRequested
    }

    /// What a view draws, computed from the state on every read and never kept beside it, as every module's
    /// model is (owner's review of #101).
    public var model: Model { state.model }

    /// Assembled on every read, as every module's route is, and always the same, because this route has
    /// neither a head nor a tail: nothing that happens to quick entry can change its address. Nothing is kept
    /// from the route `init` was given, since what opens a screen is read once and never written back, and a
    /// copy kept here would carry it into the window's route (spec section 2).
    public var route: Route { Route() }

    /// The one write the module makes goes here. Nothing is read from it: quick entry shows only what the
    /// person typed.
    private let store: Store

    private var state: State

    /// Made from its route, the one way a screen is made (spec section 3), and it cannot fail: quick entry reads
    /// nothing to show, so there is nothing to refuse, and its parent holds it in a `Seat<QuickEntry, Never>`,
    /// applied without `try`. It opens on an empty field with nothing to say, and the route has nothing in it
    /// to read: no tail, and no argument opens quick entry in this epic (spec section 2).
    ///
    /// The route defaults to `Route()` because that is the one route there is, with no head and no tail, so a
    /// caller that has none to hand on spells nothing (owner's review of #102). A seat still passes the route it
    /// applies.
    public init(store: Store, route: Route = Route()) {
        self.store = store
        self.state = State(draft: "", problem: nil)
    }

    public func send(_ event: Event) -> Output? {
        // No sentence survives the next thing a person does that the module acts on, as in the sidebar: a
        // keystroke clears it, Return and the button clear it or replace it with a fresh refusal. An echo, an
        // event of the world and Cancel move nothing.
        switch event {
        case .action(.titleFieldChanged(let text)):
            // A text that is already the draft is ignored, sentence included, because it is no keystroke: a
            // `TextField` writes the text it holds back through its binding after every keystroke and after
            // Return (#81). Taken for typing, the echo after a refused Return would clear the sentence the
            // refusal had just set, and the person would never read it.
            guard text != state.draft else { return nil }
            state.draft = text
            state.problem = nil
            return nil
        case .action(.titleFieldSubmitted), .action(.addButtonTapped):
            // Two gestures, one line: Return and the button both say "this is the task", and a module that told
            // them apart would be guessing at a difference the person did not make.
            return add()
        case .action(.cancelButtonTapped):
            // Closing is what the gesture means, and that is the module's to decide (owner's ruling on #101,
            // `docs/style.md`). Nothing is written, since the draft was never anywhere but here, and nothing in
            // the state moves, since it goes with the module, which the parent drops on this answer.
            return .closeRequested
        case .changed:
            // Quick entry reads nothing from the store, so nothing it shows can be stale, and a change elsewhere,
            // a peer's or one this window made, is no answer to what a person is typing: the draft and the
            // sentence stay.
            return nil
        case .created, .route:
            return nil
        }
    }

    /// Writes the draft as a new task and asks to be closed, or refuses and stays open on the text.
    ///
    /// The empty title is refused here and not by the store: what a person's word for a task has to be is this
    /// module's rule, and a core that had an opinion about it would hold the policy of its client
    /// (`docs/style.md`). The field keeps the raw text on every refusal, because the person is mid-word and
    /// the text they typed is the only place the title exists.
    private func add() -> Output? {
        // Trimmed once, and the one value both the refusal and the write work off: a draft that is nothing but
        // whitespace trims to nothing, which is what empty means here, and no second rule has to agree with
        // this one.
        let title = state.draft.trimmed()
        guard !title.isEmpty else {
            state.problem = Problem.emptyTitle.sentence
            return nil
        }
        do {
            // A task with no day and no parent, which is the Inbox's by the Inbox's own filter, at the end of
            // it, where the store places a task by default.
            try store.createTask(NewTask(title: title))
        } catch {
            state.problem = Problem.couldNotSave.sentence
            return nil
        }
        // The draft stays as typed, because nothing cleared after this answer is seen: the parent drops the
        // module on it, in the same event, before any view draws again.
        state.problem = nil
        return .closeRequested
    }

    /// Everything quick entry holds between two events besides its route and the store: the text in the field
    /// and the sentence the person was last told. The model is computed from it, which is the shape every
    /// module has (owner's review of #101).
    private struct State {
        var draft: String
        var problem: String?

        /// The model a view draws: the draft and the sentence, if any.
        var model: Model { Model(draft: draft, problem: problem) }
    }

    /// What can go wrong in this module, with the sentence each one reads as. The store's own error stays here:
    /// it names SQLite codes, which is what a bug report is made of and not what a person can do anything
    /// about.
    private enum Problem {
        case emptyTitle
        case couldNotSave

        var sentence: String {
            switch self {
            case .emptyTitle: "A title cannot be empty."
            case .couldNotSave: "The task could not be saved."
            }
        }
    }
}
