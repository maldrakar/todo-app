// Apps/Apple/Sources/TodoAppleUI/QuickEntryView.swift
import QuickEntryFeature
import SwiftUI

/// Quick entry's field and buttons, drawn in the sheet the root view puts over the window (`docs/specs/navigation.md`,
/// section 5), every gesture sent as the one action its control is named for: what Return, Add and Cancel mean, a task
/// created or quick entry closed, is the module's to decide (`docs/style.md`).
struct QuickEntryView: View {
    private let model: QuickEntry.Model
    private let send: (QuickEntry.UserAction) -> Void

    /// Whether the caret is in the field, which only the view can know (`docs/style.md`, "Views").
    @FocusState private var isTitleFieldFocused: Bool

    init(model: QuickEntry.Model, send: @escaping (QuickEntry.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        VStack(alignment: .leading) {
            // Every change is sent as it comes, the field's echo of the text it holds included: the module ignores
            // a text that is already the draft (#81, `QuickEntry`).
            TextField("Title", text: Binding(get: { model.draft }, set: { send(.titleFieldChanged($0)) }))
                .focused($isTitleFieldFocused)
                .onSubmit { send(.titleFieldSubmitted) }
            if let problem = model.problem {
                Text(problem)
            }
            HStack {
                Spacer()
                Button("Cancel") { send(.cancelButtonTapped) }
                Button("Add") { send(.addButtonTapped) }
            }
        }
        // Wide enough for the sentence: at the field's own width the Mac's sheet was 147 pt wide and "A title cannot
        // be empty." was cut short (2026-10-18). An ideal and not a minimum, which a screen narrower than it, the
        // watch's, could not hold.
        .frame(idealWidth: 320)
        .padding()
        // At the top of a sheet taller than the form, as iPhone's is, where the form stood in the middle of the
        // screen (2026-10-18, the iOS 26.3 simulator); the Mac's sheet is as tall as the form.
        .frame(maxHeight: .infinity, alignment: .top)
        // Quick entry opens for a person to type in.
        .onAppear { isTitleFieldFocused = true }
    }
}
