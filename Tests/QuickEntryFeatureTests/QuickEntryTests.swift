import Testing
import TestSupport
import FeatureModule
import QuickEntryFeature
@testable import TodoCore
import SQLiteKit

/// The titles of the Inbox, where quick entry files what it creates: a task with no day and no parent is the
/// Inbox's by the Inbox's own filter, which reads no day, so the day asked about is a fixed one and not the
/// wall clock, which a module test never reads.
private func inbox(of store: Store) throws -> [String] {
    try store.tasks(in: BuiltInTaskViews.inbox, today: Day(year: 2026, month: 10, day: 16)).map(\.title)
}

/// Quick entry opens on an empty field with nothing to say, on the one route it has, and answers being created
/// with nothing: it reads nothing to show and has no choice to report.
@Test func quickEntryStartsEmpty() throws {
    let entry = QuickEntry(store: try makeStore())
    #expect(entry.model.draft == "")
    #expect(entry.model.problem == nil)
    #expect(entry.route == .init())
    let before = entry.model
    #expect(entry.send(.created) == nil)
    #expect(entry.model == before)
}

/// Every keystroke is a round trip through the model, as the sidebar's rename is (ADR-0006), and the draft is
/// what the person typed, down to the spaces at its ends. A keystroke is the next thing the person did, so a
/// sentence a refusal left goes with it.
@Test func typingMovesTheDraft() throws {
    let entry = QuickEntry(store: try makeStore())
    #expect(entry.send(.action(.titleFieldChanged("B"))) == nil)
    #expect(entry.model.draft == "B")
    #expect(entry.send(.action(.titleFieldChanged(" Buy milk "))) == nil)
    #expect(entry.model.draft == " Buy milk ")
    #expect(entry.model.problem == nil)
    _ = entry.send(.action(.titleFieldChanged(" ")))
    _ = entry.send(.action(.titleFieldSubmitted))
    #expect(entry.model.problem == "A title cannot be empty.", "the sentence is the setup")
    #expect(entry.send(.action(.titleFieldChanged(" B"))) == nil)
    #expect(entry.model.draft == " B")
    #expect(entry.model.problem == nil, "the keystroke after the refusal takes its sentence away")
}

/// A field writes the text it holds back through its binding, after a keystroke and after Return (#81), and
/// that is no keystroke: taken for one, the echo after a refused Return would clear the sentence the refusal
/// had just set, and the person would never read it.
@Test func anEchoOfTheDraftMovesNothing() throws {
    let entry = QuickEntry(store: try makeStore())
    _ = entry.send(.action(.titleFieldChanged("   ")))
    _ = entry.send(.action(.titleFieldSubmitted))
    let refused = entry.model
    #expect(refused.problem == "A title cannot be empty.")
    #expect(entry.send(.action(.titleFieldChanged("   "))) == nil)
    #expect(entry.model == refused)
}

/// Return creates the task and asks to be closed, which is the modal's own half of the way back (spec section
/// 5). The draft stays as typed, because nothing cleared after this answer is seen: the parent drops the module
/// on it, in the same event, before any view draws again.
@Test func submittingCreatesTheTaskInTheInboxAndAsksToClose() throws {
    let store = try makeStore()
    let entry = QuickEntry(store: store)
    _ = entry.send(.action(.titleFieldChanged("Buy milk")))
    #expect(entry.send(.action(.titleFieldSubmitted)) == .closeRequested)
    #expect(try inbox(of: store) == ["Buy milk"])
    #expect(entry.model.draft == "Buy milk")
    #expect(entry.model.problem == nil)
}

/// The button and Return are two gestures for one thing, so they end in the same model, the same output and
/// the same Inbox.
@Test func theAddButtonTakesTheSameRoadAsReturn() throws {
    let returnStore = try makeStore()
    let buttonStore = try makeStore()
    let returned = QuickEntry(store: returnStore)
    let tapped = QuickEntry(store: buttonStore)
    _ = returned.send(.action(.titleFieldChanged("Buy milk")))
    _ = tapped.send(.action(.titleFieldChanged("Buy milk")))
    #expect(returned.send(.action(.titleFieldSubmitted)) == .closeRequested)
    #expect(tapped.send(.action(.addButtonTapped)) == .closeRequested)
    #expect(tapped.model == returned.model)
    #expect(try inbox(of: buttonStore) == ["Buy milk"])
}

/// A title that is nothing but whitespace trims to nothing, which is what empty means here: nothing is written,
/// the module says why and stays open, and the field keeps the text the person is looking at.
@Test func aBlankTitleIsRefusedWithASentenceAndKeepsTheText() throws {
    let store = try makeStore()
    let entry = QuickEntry(store: store)
    _ = entry.send(.action(.titleFieldChanged("   ")))
    #expect(entry.send(.action(.titleFieldSubmitted)) == nil)
    #expect(try inbox(of: store) == [])
    #expect(entry.model.problem == "A title cannot be empty.")
    #expect(entry.model.draft == "   ")
}

/// The store gets the title trimmed at both ends and the field keeps what was typed: padding is no part of a
/// name, and a caret is no place for the module to be moving text about. The run of spaces between the words
/// is part of the name and goes in as typed.
@Test func theTitleIsTrimmedOnTheWayToTheStore() throws {
    let store = try makeStore()
    let entry = QuickEntry(store: store)
    _ = entry.send(.action(.titleFieldChanged("  Buy  milk \n")))
    #expect(entry.send(.action(.titleFieldSubmitted)) == .closeRequested)
    #expect(try inbox(of: store) == ["Buy  milk"])
    #expect(entry.model.draft == "  Buy  milk \n")
}

/// A store that refuses the write leaves nothing written and a sentence in its place, and the module stays open
/// on the text, for the person to try again. Once the store writes again the same text goes in, and the sentence
/// goes with the write that answers it.
///
/// The refusal is SQLite's own: `query_only` on the store's connection refuses every write and no read, which
/// is a store that cannot write as quick entry meets one. The connection is the store's internal `db`, reached
/// the way `StoreOpenTests` reaches it, so that the core grows no API for a test.
@Test func aRefusedWriteBecomesASentence() throws {
    let store = try makeStore()
    let entry = QuickEntry(store: store)
    _ = entry.send(.action(.titleFieldChanged("Buy milk")))
    try store.db.execute("PRAGMA query_only = ON")
    #expect(entry.send(.action(.titleFieldSubmitted)) == nil)
    #expect(try inbox(of: store) == [])
    #expect(entry.model.problem == "The task could not be saved.")
    #expect(entry.model.draft == "Buy milk")
    try store.db.execute("PRAGMA query_only = OFF")
    #expect(entry.send(.action(.titleFieldSubmitted)) == .closeRequested)
    #expect(try inbox(of: store) == ["Buy milk"])
    #expect(entry.model.problem == nil)
}

/// Cancel asks to be closed and leaves the store alone: the draft was never anywhere but here, and it goes with
/// the module, which the parent drops. Nothing in the model moves, since nothing it would clear is seen again.
@Test func theCancelButtonAsksToCloseAndWritesNothing() throws {
    let store = try makeStore()
    let entry = QuickEntry(store: store)
    _ = entry.send(.action(.titleFieldChanged("Buy milk")))
    let typed = entry.model
    #expect(entry.send(.action(.cancelButtonTapped)) == .closeRequested)
    #expect(try inbox(of: store) == [])
    #expect(entry.model == typed)
}

/// A change is delivered over a draft and a sentence, and neither moves: quick entry reads nothing from the
/// store, and what another write did is no answer to what a person is typing.
@Test func aChangeMovesNothing() throws {
    let store = try makeStore()
    let entry = QuickEntry(store: store)
    _ = entry.send(.action(.titleFieldChanged("   ")))
    _ = entry.send(.action(.titleFieldSubmitted))
    let before = entry.model
    let change = try changeSet(of: store) { try store.createTask(NewTask(title: "Call the bank")) }
    #expect(entry.send(.changed(change)) == nil)
    #expect(entry.model == before)
}

/// The route has neither a head nor a tail, so a route applied to a live quick entry has nothing to say to it,
/// and the draft and the sentence a person is looking at stay (spec section 2).
@Test func aRouteMovesNothing() throws {
    let entry = QuickEntry(store: try makeStore())
    _ = entry.send(.action(.titleFieldChanged("   ")))
    _ = entry.send(.action(.titleFieldSubmitted))
    let before = entry.model
    #expect(entry.send(.route(.init())) == nil)
    #expect(entry.model == before)
}

/// Quick entry's route owns the `quick-entry` item of a window's query, a bare flag, which the window hands it alone,
/// found by its name: it reads it and writes it.
@Test func theRouteReadsAndWritesItsQueryItem() throws {
    #expect(try QuickEntry.Route(item: "quick-entry") == .init())
    #expect(QuickEntry.Route().item == "quick-entry")
}

/// Anything but the bare name is refused as written, its name with a value included, an empty one too, since no
/// screen in this epic opens with an argument (spec section 2).
@Test func theRouteRefusesAnyOtherItem() {
    for item in ["quick-entry=1", "quick-entry=", "search", "Quick-Entry", ""] {
        #expect(throws: RouteError.unknownQuery(item)) { try QuickEntry.Route(item: item) }
    }
}
