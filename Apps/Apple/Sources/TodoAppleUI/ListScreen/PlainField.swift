// Apps/Apple/Sources/TodoAppleUI/ListScreen/PlainField.swift
import DesignSystem
import DesignSystemComponents
import SwiftUI

/// A field with no ring of its own that stands in what it belongs to, a card's title, notes and subtask's and a list's
/// name's (`TaskList.plainField`), a view of its own so that each field watches its own focus. It draws what its model
/// holds in its model's look (`fieldLook(_:)`), sends its model's actions for Return, Esc and a lost focus, and for the
/// text what `changed` makes of it, which a model cannot hold (`TextFieldModel`).
///
/// What is typed goes up only while the field has the focus: a field writes its text back through its binding as it
/// goes too, and that echo, after a card has closed, names no card and would land on the one opened since. What it
/// shows is its own (`TypedText`), since a model drawn before the last keystroke would take that letter back. It is not
/// `TitleField`, which asks the caret back on every lost focus and cannot stand beside another field. Whether it takes
/// the focus when it appears, and takes it back after Return, is its caller's, which is the view's own focus: a new
/// task's title does and a stored one does not, and on the Mac a `TextField` ends editing on a Return, so that the next
/// empty subtask's field the module opens would close at once on the lost focus (Task 7's hand check).
///
/// `PlainField` was probed free against SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with
/// Xcode 27.1 (2026-11-07), as `CheckButton`, `WrappingRow`, `BlockRow`, `AddRowView` and `BlockHeaderView` were.
struct PlainField<Action: Equatable & Sendable>: View {
    private let model: TextFieldModel<Action>
    private let axis: Axis
    private let focusesOnAppear: Bool
    private let keepsFocusOnSubmit: Bool
    private let selectsAllOnFocus: Bool
    private let color: DesignSystem.Color?
    private let strike: DesignSystem.Color?
    private let changed: (String) -> Action
    private let send: (Action) -> Void

    @FocusState private var isFocused: Bool
    @State private var typed: TypedText

    #if os(iOS)
    /// Whether the field has selected its text on taking the focus, which it does once.
    @State private var hasSelectedAll = false
    #endif

    /// The field, on one line unless `axis` says it grows down, as a card's notes do, in its model's colour unless
    /// `color` gives another, and with a line through it in `strike`, as a done task's title has on its card.
    init(
        _ model: TextFieldModel<Action>, axis: Axis = .horizontal, focusesOnAppear: Bool,
        keepsFocusOnSubmit: Bool = false, selectsAllOnFocus: Bool = false, color: DesignSystem.Color? = nil,
        strike: DesignSystem.Color? = nil, changed: @escaping (String) -> Action, send: @escaping (Action) -> Void
    ) {
        self.model = model
        self.axis = axis
        self.focusesOnAppear = focusesOnAppear
        self.keepsFocusOnSubmit = keepsFocusOnSubmit
        self.selectsAllOnFocus = selectsAllOnFocus
        self.color = color
        self.strike = strike
        self.changed = changed
        self.send = send
        _typed = State(initialValue: TypedText(model.text))
    }

    var body: some View {
        field
            // Plain, its look the model's: the Mac's default style draws a bezel of its own inside it, where iOS's
            // draws none.
            .textFieldStyle(.plain)
            .strikethrough(strike != nil, color: strike.map { Color($0) })
            .fieldLook(model, color: color)
            .focused($isFocused)
            .onSubmit {
                send(model.submitted)
                typed.settled()
                if keepsFocusOnSubmit { isFocused = true }
            }
            .onChange(of: isFocused) { _, isFocused in
                guard !isFocused else { return }
                send(model.focusLost)
                typed.settled()
            }
            .onAppear {
                if focusesOnAppear { isFocused = true }
            }
            .onChange(of: model.text) { _, text in typed.modelHolds(text) }
            #if os(iOS)
            // A list's new name replaces "New list" as it is typed (`Phone.dc.html`, the name field's `selectAll`).
            // SwiftUI can select a field's text from iOS 18 and the app runs on 17, so the selection is UIKit's, and on
            // the next turn, since a field beginning to edit sets its own caret after this. The Mac's field selects its
            // text as it takes the focus. Once: the notification names any field, and the first to begin after this one
            // appears is this one, where `isFocused` cannot tell, being false through its own notification and true
            // through another's, so that a card's title tapped after it lost its text to the next letter (the iOS 26.3
            // simulator, 2026-11-07).
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
                guard selectsAllOnFocus, !hasSelectedAll, let field = note.object as? UITextField else { return }
                hasSelectedAll = true
                DispatchQueue.main.async { field.selectAll(nil) }
            }
            #endif
    }

    /// The field, which reads Esc where a keyboard has one: `onKeyPress` has no watchOS.
    @ViewBuilder private var field: some View {
        let text = TextField(
            model.placeholder,
            text: Binding(get: { typed.text }, set: { text in
                if typed.typed(text, goesUp: isFocused) { send(changed(text)) }
            }),
            prompt: Text(model.placeholder).foregroundStyle(Color(model.style.placeholder)),
            axis: axis
        )
        #if os(watchOS)
        text
        #else
        text.onKeyPress(.escape) {
            send(model.cancelled)
            return .handled
        }
        #endif
    }
}

/// What a field shows while what it sent up comes back to it late: what is typed stands at once, and a text of the
/// model's that this field sent is an echo of what it has moved on from, while any other is the module's own and
/// stands, the next subtask's empty field after Return, a title the store kept trimmed or another device's change. A
/// field bound to the model itself lost letters: a model drawn before a keystroke, handed to the field after it, wrote
/// the text back without that letter, on an iPhone 17 one title in five at the speed a test types and however slowly a
/// long list draws (the iOS 26.3 simulator, 2026-11-07).
///
/// Nothing says when the module has answered but a change of the model the view can see, and a letter and Return
/// handled with no render between them, "" to "a" and back to "", is none. So Return and a lost focus end what was
/// waited for and put the field back on what the model last showed, and the model's next change, if it has one, settles
/// the rest.
struct TypedText {
    private(set) var text: String

    /// What was sent up and not yet seen back, oldest first.
    private var sent: [String] = []

    /// What the model last showed.
    private var shown: String

    init(_ text: String) {
        self.text = text
        shown = text
    }

    /// Takes what the field now holds, and answers whether it goes up: a keystroke, not the text the field held, while
    /// it has the focus. Only what goes up is waited for.
    mutating func typed(_ new: String, goesUp: Bool) -> Bool {
        guard new != text else { return false }
        text = new
        guard goesUp else { return false }
        sent.append(new)
        return true
    }

    /// Takes the text the model now shows. An echo answers everything sent before it too, the newest of equal texts
    /// first, so that an old entry cannot swallow a later answer.
    mutating func modelHolds(_ new: String) {
        shown = new
        if let index = sent.lastIndex(of: new) {
            sent.removeFirst(index + 1)
        } else {
            text = new
            sent = []
        }
    }

    /// Return or a lost focus: nothing more is waited for, and the field stands on what the model last showed.
    mutating func settled() {
        text = shown
        sent = []
    }
}
