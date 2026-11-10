// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListSurface.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// What the list screen draws wherever it stands, the phone's screen in a narrow window's stack (`ListScreen`) and the
/// pane of a wide one (`ListPane`), as the canvas draws it (`Phone.dc.html`, `Mac.dc.html`; list screen spec, sections
/// 1 to 7 and 10): the content, a `ScrollView` of the header, the blocks, the empty state, "+ Add list" and the Done
/// strip, or the board under a header that stays, at most as wide as the model's style says and centred; over it the
/// fade where the layout has one, and the floating "+" where the "+" floats; and under it the sentence. Everything it
/// draws arrives finished in the model, each part of it the model of the component that draws it, the numbers of the
/// phone or of the pane as the window's width chose them (`TaskList.Metrics`), and each gesture is sent as the action
/// its control's model holds, so it decides only what is the platform's: its containers, scrolling and focus
/// (`docs/style.md`, "Views"). Where the glass buttons stand is its screen's, over the content on the phone and in the
/// window's bar in the pane, which `buttons` puts there, handed what a control of the content sends.
///
/// The content is a `ScrollView`, not a `List`, which moves a row up and down a flat list and takes the row's look. In
/// it the blocks and the Done strip's rows stand in lazy stacks, which lay out only the rows in sight, where a plain
/// stack laid out every row at opening (#196), around each part that holds a field, an open card or a list's name being
/// typed, which stands outside them, laid out wherever it is: a lazy stack took a field scrolled out of sight out of
/// the window, and its focus with it (spike #145; `ListsTree`; `ListRuns`). A stack begun at such a part stays begun
/// there once its field has closed, for as long as the list is shown, so that closing a card moves no row (`ListCuts`).
///
/// A tap on what stands behind the controls is one action, `backgroundTapped`, which closes an open card: a gesture on
/// the content takes every tap no control of it took, the header's words and the room under the rows among them, and a
/// card takes its own (`TaskCardView`).
///
/// A row's drag, menu, swipe and landing are its own (`BlockRow`); the surface keeps what they share, the drag in
/// progress and the row swiped aside, and stands the system's drop on its scroll views on iOS (`RowDropTarget`) and the
/// pointer's drag on their content on the Mac (`RowPointerDrag`). Any control of the content, and either "+", closes a
/// row left swiped open.
///
/// `ListSurface` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
struct ListSurface<Buttons: ViewModifier>: View {
    private let model: TaskList.Model
    private let send: (TaskList.UserAction) -> Void
    private let buttons: (_ sendFromContent: @escaping (TaskList.UserAction) -> Void) -> Buttons

    /// What the safe area covers at the bottom, the home indicator while no sentence's strip stands under the content,
    /// which the list's scroll view goes under and its content keeps clear of.
    @State private var bottomInset: CGFloat = 0

    /// What the surface keeps of its rows' gestures.
    private var rowGestures = ListScreenGestures()

    /// The parts at which the list's runs have started, kept while the list is shown (`ListCuts`).
    @State private var cuts = ListCuts()

    /// The surface of the list, with its screen's glass buttons, which `buttons` stands where the screen has them,
    /// handed the send of a control of the content, which closes a row a swipe left open, for its "+".
    init(
        model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void,
        buttons: @escaping (_ sendFromContent: @escaping (TaskList.UserAction) -> Void) -> Buttons
    ) {
        self.model = model
        self.send = send
        self.buttons = buttons
    }

    var body: some View {
        content
            .contentShape(.rect)
            .onTapGesture { sendClosingSwipe(.backgroundTapped) }
            // The content goes down under the home indicator, whichever its layout, while no sentence's strip stands
            // under it, and ends at the strip's top while one does (`stripUnder`, #193): for the drop (`RowDropTarget`)
            // and so that the board's columns end above the screen's bottom or the strip and not the safe area's
            // (`.board`'s padding); and here, outside the shape above, which ends a hit where it ends: inside it, a
            // drop's point left the target at the safe area's foot (the iOS 26.3 simulator, 2026-11-07). The keyboard
            // still shortens it, its region not ignored.
            .ignoresSafeArea(.container, edges: .bottom)
            .modifier(BottomInsetReader(inset: $bottomInset))
            // The list and the board share nothing of their layout: as one gives way to the other, the frames it
            // reported and the starts of the list's runs are forgotten. Here, on the surface, whose change runs before
            // the layout that comes reports its first frame (probed on macOS 26, 2026-11-10: this action, then the
            // new content's rows' `onGeometryChange`), and only on a change of the shape, never when the screen comes
            // back from under another.
            .onChange(of: shape) {
                rowGestures.forgetLayout()
                cuts.kept = []
            }
            .overlay { floatingButton }
            .stripUnder { sentence }
            .overlay(alignment: .top) {
                if let fade = model.style.fade {
                    fadeUnderTheButtons(fade)
                }
            }
            .modifier(buttons(sendClosingSwipe))
            .background(Color(model.style.background))
            // The screen's title is the header's, which names the list in the back button's menu over what stands on it
            // (#126), and in the Mac's toolbar.
            .navigationTitle(model.header.title.text)
    }

    /// The switch over the layout's shapes that picks the container, every case drawn and none by `default`
    /// (`docs/style.md`, "Views").
    @ViewBuilder private var content: some View {
        switch model.layout {
        case .list(let blocks):
            list(blocks)
        case .columns(let board):
            columns(board)
        }
    }

    /// The layout's shape with nothing of what it holds, whose change alone is the list giving way to the board or the
    /// board to the list; every case named and none by `default`.
    private var shape: TaskList.Model.Layout.Kind {
        switch model.layout {
        case .list: .list
        case .columns: .columns
        }
    }

    /// What a control of the content sends: any of them closes the row a swipe left open.
    private func sendClosingSwipe(_ action: TaskList.UserAction) {
        rowGestures.closeSwipe()
        send(action)
    }

    /// The list: everything scrolls, under the glass bar, from under the safe area's top, and down to the screen's
    /// foot, or to the top of a sentence's strip under it, what it holds ending as far above what the safe area covers
    /// there, or above the strip, as its style says.
    private func list(_ blocks: [TaskList.Model.Block]) -> some View {
        let runs = ListRuns(blocks, doneRows: model.doneRows, cuts: cuts.kept)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(runs.runs) { run in
                    if let field = run.field {
                        blockView(field)
                    }
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(run.lazy) { piece in blockView(piece) }
                    }
                }
                LazyVStack(alignment: .leading, spacing: 0) {
                    tail
                }
                doneRows(holdingField: runs.doneRowsHoldField)
            }
            .padding(.top, model.style.contentTop)
            .padding(.bottom, model.style.contentBottom + bottomInset)
            .modifier(ContentWidth(model.style))
            .overlay(alignment: .topLeading) {
                BlockDropTints(blocks, gestures: rowGestures.forRows(delete: send))
            }
            .modifier(rowGestures.listContent(blocks, send: send))
        }
        .scrollIndicators(.hidden)
        .modifier(rowGestures.dropTarget(blocks, settleInset: nil, send: send))
        // A row left open is not open when the list comes back, from the board or from a screen over it.
        .onDisappear { rowGestures.closeSwipe() }
        // Each block's frame the union of the parts it draws now.
        .onChange(of: blocks, initial: true) { rowGestures.forgetParts(notDrawnBy: blocks) }
        // The starts this pass drew are kept for the next, after it.
        .onChange(of: runs.cuts, initial: true) { _, drawn in cuts.kept = drawn }
    }

    /// What a run holds of a block.
    private func blockView(_ piece: ListRuns.Piece) -> some View {
        BlockView(piece.block, parts: piece.parts, gestures: rowGestures.forRows(delete: send), send: sendClosingSwipe)
    }

    /// What follows the blocks in a lazy stack: the empty state, "+ Add list" and the Done strip.
    @ViewBuilder private var tail: some View {
        if let empty = model.empty {
            EmptyScreenView(empty)
        }
        if let addList = model.addList {
            AddRowView(addList, send: sendClosingSwipe)
        }
        if let done = model.done {
            DoneStripView(done, send: sendClosingSwipe)
        }
    }

    /// The Done strip's rows while it is open, coming in as it opens: in a lazy stack, and out of it while one of them
    /// holds a field, as a block's parts are (`ListRuns`). Their group stands outside the lazy stacks, so that leaving
    /// the window does not play its entrance again.
    @ViewBuilder private func doneRows(holdingField: Bool) -> some View {
        if let done = model.done, !model.doneRows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if holdingField {
                    doneRowViews
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        doneRowViews
                    }
                }
            }
            .modifier(Entrance(done.style.rowsEntrance))
            .padding(.top, done.style.capsuleToRows)
        }
    }

    /// The Done strip's rows, each a row of the strip.
    private var doneRowViews: some View {
        ForEach(model.doneRows) { row in
            BlockRow(row, send: sendClosingSwipe)
                .equatable()
        }
    }

    /// The board: the header stays under the circles, and the board takes the rest of the screen. The canvas draws no
    /// empty state here; a board with nothing on it says so as the list does, above the columns it does have.
    private func columns(_ board: TaskList.Model.Board) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let empty = model.empty {
                EmptyScreenView(empty)
                    .padding(.bottom, empty.style.bottomMargin)
            }
            BoardView(
                board, gestures: rowGestures.forRows(delete: send),
                dragContent: rowGestures.boardContent(board.columns, send: send), send: sendClosingSwipe
            )
            .modifier(rowGestures.dropTarget(
                board.columns, settleInset: board.snaps ? board.horizontalPadding : nil, send: send
            ))
        }
        .padding(.top, model.style.contentTop)
        .modifier(ContentWidth(model.style))
        // The whole screen whatever the board holds: a sideways scroll view is as high as its content, and with no
        // column to stretch it the screen stood in the middle of the window (the iOS 26.3 simulator, 2026-11-07).
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// The screen's header and the tag bar under it, and the gap to what follows. Its words take no touch, so that a
    /// tap on them is the background's; the bar's chips and its scroll are its own.
    private var header: some View {
        let style = model.header.style
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: style.titleToSubtitle) {
                HStack(spacing: style.spacing) {
                    ListTile(model.header.tile)
                    Text(model.header.title)
                }
                if let subtitle = model.header.subtitle {
                    Text(subtitle)
                        .padding(.leading, style.subtitleLeading)
                }
            }
            .allowsHitTesting(false)
            if let tagBar = model.tagBar {
                TagBarView(tagBar, send: sendClosingSwipe)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.bottom, style.bottomMargin)
    }

    /// What scrolls under the buttons leaves by this, the paper down to its solid depth under the safe area's top and
    /// the same colour clear at its end. Two parts, so that the solid one reaches up under the status bar or the bar
    /// whatever its inset, the phone's circles or the pane's bar standing over it; it takes no touch, so that a row
    /// behind it is still tapped.
    private func fadeUnderTheButtons(_ fade: ListScreenStyle.Fade) -> some View {
        let color = Color(fade.color)
        return VStack(spacing: 0) {
            color
                .frame(height: fade.solidDepth)
                .background(color.ignoresSafeArea(edges: .top))
            LinearGradient(colors: [color, color.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: fade.height - fade.solidDepth)
        }
        .allowsHitTesting(false)
    }

    /// The floating "+" over the content alone, its margins from the content's edges and not the safe area's: from the
    /// screen's bottom while nothing stands under the content, and from the top of a sentence's strip while one does,
    /// the list's own or the sidebar's its window lays under the screen, which the content ends at (`stripUnder`). The
    /// keyboard covers it (`Phone.dc.html`, the keyboard's `z-index`), so it does not rise with it while nothing stands
    /// under the content; a strip rises with the keyboard, and the "+" stands above the strip there, as it did over
    /// the root's before (the iOS 26.3 simulator, 2026-11-09). The frame takes the room the safe area gave back, which
    /// the button alone, at its own size, stayed clear of.
    @ViewBuilder private var floatingButton: some View {
        if let addTask = model.addTask {
            FloatingButton(addTask, send: sendClosingSwipe)
                .padding(.trailing, addTask.style.trailingMargin)
                .padding(.bottom, addTask.style.bottomMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .ignoresSafeArea([.container, .keyboard], edges: .bottom)
        }
    }

    /// What went wrong, drawn as the sidebar's sentence is, across the bottom of the screen, under the content.
    @ViewBuilder private var sentence: some View {
        if let problem = model.problem {
            Text(problem)
                .listsSentence(on: model.style.background)
        }
    }
}

/// The content of the list or of the board as wide as the screen's style lets it be: in from the screen's sides by its
/// padding, and at most its widest, centred in the screen (`Mac.dc.html`, the scroller's `max-width` and `margin`,
/// whose width holds the padding). The phone's style has neither, and its content is the screen's width.
private struct ContentWidth: ViewModifier {
    private let style: ListScreenStyle

    init(_ style: ListScreenStyle) {
        self.style = style
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, style.contentHorizontalPadding)
            .frame(maxWidth: style.contentMaxWidth.map { CGFloat($0) })
            .frame(maxWidth: .infinity)
    }
}
