// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListSurface.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// What the list screen draws wherever it stands, the phone's screen in a narrow window's stack (`ListScreen`) and the
/// pane of a wide one (`ListPane`), as the canvas draws it (`Phone.dc.html`, `Mac.dc.html`; list screen spec, sections
/// 1 to 7 and 10): the content, a `ScrollView` of the header, the blocks, the empty state, "+ Add list" and the Done
/// strip, or the board under a header that stays, at most as wide as the model's style says and centred; over it the
/// row of glass buttons, back where the screen has it, then "…" with Show as, alone or in the capsule beside the "+",
/// and the floating "+" where the "+" floats; and under it the sentence. Everything it draws arrives finished in the
/// model, each part of it the model of the component that draws it, the numbers of the phone or of the pane as the
/// window's width chose them (`TaskList.Metrics`), and each gesture is sent as the action its control's model holds, so
/// it decides only what is the platform's: its containers, scrolling and focus (`docs/style.md`, "Views"). Whether it
/// draws its back is its screen's, which knows where it stands in its stack.
///
/// The content is a `VStack` in a `ScrollView`, not a `List`, which moves a row up and down a flat list and takes the
/// row's look, and not a `LazyVStack`, which dropped a field scrolled out of sight and lost its focus with it (spike
/// #145; `ListsTree`).
///
/// A tap on what stands behind the controls is one action, `backgroundTapped`, which closes an open card: a gesture on
/// the content takes every tap no control of it took, the header's words and the room under the rows among them, and a
/// card takes its own (`TaskCardView`).
///
/// A row's drag, menu, swipe and landing are its own (`BlockRow`); the surface keeps what they share, the drag in
/// progress and the row swiped aside, and stands the drop on its scroll views (`RowDropTarget`). Any control of the
/// content, and either "+", closes a row left swiped open.
///
/// `ListSurface` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
struct ListSurface: View {
    private let model: TaskList.Model
    private let send: (TaskList.UserAction) -> Void
    private let showsBack: Bool

    /// How high the sentence's strip stands, which only the view can know and which the floating "+" stands above.
    @State private var sentenceHeight: CGFloat = 0

    /// What the safe area covers at the bottom, the home indicator and the sentence, which the list's scroll view goes
    /// under and its content keeps clear of.
    @State private var bottomInset: CGFloat = 0

    /// What the surface keeps of its rows' gestures.
    private var rowGestures = ListScreenGestures()

    init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void, showsBack: Bool) {
        self.model = model
        self.send = send
        self.showsBack = showsBack
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
            // (#126), and in the Mac's toolbar.
            .navigationTitle(model.header.title.text)
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
            .modifier(ContentWidth(model.style))
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

    /// The row of glass buttons at the safe area's top, as high as the style says, over the fade where the layout has
    /// one: back where the screen draws it, at the leading edge, and at the trailing one the capsule where the style
    /// has one, or "…" alone.
    private var glassButtons: some View {
        ZStack(alignment: .top) {
            if let fade = model.style.fade {
                fadeUnderTheButtons(fade)
            }
            HStack(spacing: model.style.barSpacing) {
                if showsBack {
                    GlassButton(model.back, send: send)
                }
                Spacer(minLength: 0)
                if let capsule = model.style.capsule {
                    self.capsule(capsule)
                } else {
                    showAs
                }
            }
            .frame(height: model.style.barHeight)
            .padding(.horizontal, model.style.edgeInset)
        }
    }

    /// What scrolls under the buttons leaves by this, the paper down to its solid depth under the safe area's top and
    /// the same colour clear at its end. Two parts, so that the solid one reaches up under the status bar or the
    /// toolbar whatever its inset; it takes no touch, so that a row behind it is still tapped.
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

    /// The glass capsule of the pane (`Mac.dc.html`, the nav row's `.glass`): the "+" where the list takes a task, the
    /// divider after it, and "…", standing on the capsule's glass and on none of their own (`GlassButtonFace`).
    private func capsule(_ style: GlassCapsuleStyle) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .circular)
        return HStack(spacing: 0) {
            if let addTask = model.glassAddTask {
                GlassButton(addTask, send: sendClosingSwipe)
                Rule(style.divider, along: .vertical)
                    .frame(height: style.dividerHeight)
            }
            showAs
        }
        .padding(.horizontal, style.horizontalPadding)
        .frame(height: style.height)
        .glassSurface(style.glass, in: shape)
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
