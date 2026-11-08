// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListScreen.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// The list screen on a phone, a screen pushed over the Lists screen in a narrow window's stack, as the canvas draws it
/// (`Phone.dc.html`; list screen spec, sections 1 to 7): the content, a `ScrollView` of the header, the blocks, the
/// empty state, "+ Add list" and the Done strip, or the board under a header that stays; over it the glass circles,
/// back and "…" with Show as, and the floating "+"; and under it the sentence. Everything it draws arrives finished in
/// the model, each part of it the model of the component that draws it, and each gesture is sent as the action its
/// control's model holds, so it decides only what is the platform's: its containers, scrolling and focus
/// (`docs/style.md`, "Views").
///
/// The content is a `VStack` in a `ScrollView`, not a `List`, which moves a row up and down a flat list and takes the
/// row's look, and not a `LazyVStack`, which dropped a field scrolled out of sight and lost its focus with it (spike
/// #145; `ListsTree`).
///
/// A tap on what stands behind the controls is one action, `backgroundTapped`, which closes an open card: a gesture on
/// the content takes every tap no control of it took, the header's words and the room under the rows among them, and a
/// card takes its own (`TaskCardView`).
///
/// The bar is hidden, so the way back is the glass circle, which sends the list's action as every control does, and the
/// swipe from the screen's edge, which a hidden bar turns off, is kept on (`EdgeSwipeBack`) and is the stack's pop, as
/// the system's back button's; the long-press menu of that button goes with it.
///
/// A row's drag, menu, swipe and landing are its own (`BlockRow`); the screen keeps what they share, the drag in
/// progress and the row swiped aside, and stands the drop on its scroll views (`RowDropTarget`). Any control of the
/// content closes a row left swiped open.
///
/// A Mac window can be narrow too, so this draws there as well, each call the Mac lacks fenced and named; Task 9 gives
/// the Mac its look.
struct ListScreen: View {
    private let model: TaskList.Model
    private let send: (TaskList.UserAction) -> Void

    /// How high the sentence's strip stands, which only the view can know and which the floating "+" stands above.
    @State private var sentenceHeight: CGFloat = 0

    /// What the safe area covers at the bottom, the home indicator and the sentence, which the list's scroll view goes
    /// under and its content keeps clear of.
    @State private var bottomInset: CGFloat = 0

    /// What the screen keeps of its rows' gestures.
    private var rowGestures = ListScreenGestures()

    init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        content
            .contentShape(.rect)
            .onTapGesture { sendClosingSwipe(.backgroundTapped) }
            // The content goes down under the home indicator, whichever its layout, for the drop (`RowDropTarget`) and
            // so that the board's columns end above the screen's bottom and not the safe area's (`.board`'s padding);
            // and here, outside the shape above, which ends a hit where it ends: inside it, a drop's point left the
            // target at the safe area's foot (the iOS 26.3 simulator, 2026-11-07). The keyboard still shortens it, its
            // region not ignored.
            .ignoresSafeArea(.container, edges: .bottom)
            .modifier(BottomInsetReader(inset: $bottomInset))
            .safeAreaInset(edge: .bottom, spacing: 0) { sentence }
            .overlay(alignment: .top) { glassButtons }
            .overlay { floatingButton }
            .background(Color(model.style.background))
            // The screen's title is the header's, which names the list in the back button's menu over what stands on it
            // (#126), though its own bar is hidden.
            .navigationTitle(model.header.title.text)
            #if !os(macOS)
            // The canvas has no bar over the content; the screens pushed over it keep theirs. The placement is
            // unavailable on macOS.
            .toolbar(.hidden, for: .navigationBar)
            #endif
            #if os(iOS)
            // iOS alone: the Mac and the watch have no `interactivePopGestureRecognizer`.
            .background { EdgeSwipeBack() }
            #endif
    }

    /// The one switch over the layout's shapes, every case drawn and none by `default` (`docs/style.md`, "Views").
    @ViewBuilder private var content: some View {
        switch model.layout {
        case .list(let blocks):
            list(blocks)
        case .columns(let board):
            columns(board)
        }
    }

    /// What a control of the content sends: any of them closes the row a swipe left open.
    private func sendClosingSwipe(_ action: TaskList.UserAction) {
        rowGestures.closeSwipe()
        send(action)
    }

    /// The list: everything scrolls, under the glass bar, from under the safe area's top, and down to the screen's
    /// foot, what it holds ending as far above what the safe area covers there as its style says.
    private func list(_ blocks: [TaskList.Model.Block]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(blocks) { block in
                    BlockView(block, gestures: rowGestures.forRows(delete: send), send: sendClosingSwipe)
                }
                if let empty = model.empty {
                    EmptyScreenView(empty)
                }
                if let addList = model.addList {
                    AddRowView(addList, send: sendClosingSwipe)
                }
                if let done = model.done {
                    DoneStripView(done, send: sendClosingSwipe)
                    if !model.doneRows.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(model.doneRows) { row in
                                BlockRow(row, send: sendClosingSwipe)
                            }
                        }
                        .modifier(Entrance(done.style.rowsEntrance))
                        .padding(.top, done.style.capsuleToRows)
                    }
                }
            }
            .padding(.top, model.style.contentTop)
            .padding(.bottom, model.style.contentBottom + bottomInset)
            .modifier(rowGestures.listContent(blocks))
        }
        .scrollIndicators(.hidden)
        .modifier(rowGestures.dropTarget(blocks, settleInset: nil, send: send))
        // A row left open is not open when the list comes back, from the board or from a screen over it.
        .onDisappear { rowGestures.closeSwipe() }
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
            BoardView(board, gestures: rowGestures.forRows(delete: send), send: sendClosingSwipe)
                .modifier(rowGestures.dropTarget(
                    board.columns, settleInset: board.snaps ? board.horizontalPadding : nil, send: send
                ))
        }
        .padding(.top, model.style.contentTop)
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

    /// The circles at the safe area's top, over the fade where the layout has one.
    private var glassButtons: some View {
        ZStack(alignment: .top) {
            if let fade = model.style.fade {
                fadeUnderTheButtons(fade)
            }
            HStack(spacing: 0) {
                GlassButton(model.back, send: send)
                Spacer(minLength: 0)
                showAs
            }
            .padding(.horizontal, model.style.edgeInset)
        }
    }

    /// What scrolls under the circles leaves by this, the paper down to its solid depth under the safe area's top and
    /// the same colour clear at its end. Two parts, so that the solid one reaches up under the status bar whatever the
    /// device's inset; it takes no touch, so that a row behind it is still tapped.
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

    /// "…" with Show as (list screen spec, section 5). Left out on the watch, where `Menu` is unavailable, and whose
    /// build is a compile check in this epic.
    @ViewBuilder private var showAs: some View {
        #if os(watchOS)
        EmptyView()
        #else
        Menu { MenuItems(model.showAs, send: send) } label: { GlassButtonFace(model.more) }
            #if os(macOS)
            // Its label alone, as a plain button draws it: the Mac's default style puts it in a pull-down's bezel.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            #endif
            .menuOrder(.fixed)
            .accessibilityLabel(model.more.accessibilityLabel)
        #endif
    }

    /// The floating "+", its margins from the screen's edges and not the safe area's, standing above the sentence while
    /// there is one. The keyboard covers it (`Phone.dc.html`, the keyboard's `z-index`), so it does not rise with it.
    /// The frame takes the room the safe area gave back, which the button alone, at its own size, stayed clear of.
    @ViewBuilder private var floatingButton: some View {
        if let addTask = model.addTask {
            FloatingButton(addTask, send: sendClosingSwipe)
                .padding(.trailing, addTask.style.trailingMargin)
                .padding(.bottom, addTask.style.bottomMargin + sentenceHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .ignoresSafeArea([.container, .keyboard], edges: .bottom)
        }
    }

    /// What went wrong, drawn as the sidebar's sentence is, across the bottom of the screen.
    @ViewBuilder private var sentence: some View {
        if let problem = model.problem {
            Text(problem)
                .listsSentence(on: model.style.background)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sentenceHeight = $0 }
                .onDisappear { sentenceHeight = 0 }
        }
    }
}
