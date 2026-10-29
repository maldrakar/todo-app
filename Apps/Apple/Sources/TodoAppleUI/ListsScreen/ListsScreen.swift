// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsScreen.swift
import SwiftUI
import TaskViewListFeature
import TodoCore

/// The Lists screen on a phone, at the root of a narrow window's stack, as the canvas draws it (`Phone.dc.html`; Lists
/// screen spec, sections 1, 6 and 7): one scrolling tree with no title and no navigation bar, the bar at the bottom
/// (`ListsBottomBar`), the confirmation of a delete as an alert and Move to… as a sheet (`MovePickerSheet`). Everything
/// it draws arrives finished in the model, and each gesture is sent as the one action its control is named for: what
/// follows is the module's. It keeps only what only it can know, the size of its viewport, how far the tree is scrolled
/// sideways, and a drag in progress (`docs/style.md`, "Views").
///
/// The tree is a `ScrollView` over both axes and not a `List`, which moves a row up and down a flat list and knows
/// nothing of depth (spike #145). Past the depth at which a row's tile and a title of 140 pt no longer fit beside the
/// count and the chevron, the tree is as wide as its widest row and scrolls sideways, while the count, the chevron and
/// the grip stay pinned at the right edge of the screen (`Phone.dc.html`, a row's `need`).
///
/// Outside edit mode a tap on a list's row chooses it, its chevron folds its branch, and a long press opens the menu of
/// the row's kind. In edit mode the counts leave the rows and the grips come, a tap on a row or on an area's line opens
/// its field, and a long press lifts the row for the drag (`ListsDragGesture`), where no menu opens.
struct ListsScreen: View {
    private let model: TaskViewList.Model
    private let send: (TaskViewList.UserAction) -> Void

    /// Whether the app can open a window beside this one, which the platform reports: false on iPhone, its Info.plist
    /// declaring multiple scenes or not (`TaskViewListView`, 2026-10-18), so Open in New Window is drawn where a
    /// window can open and not on a phone.
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    /// Whether a person asked for less motion, in which case every change of the tree is drawn without its animation.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The size of the tree's viewport, which only the view can know.
    @State private var viewport = CGSize.zero

    /// How far the tree is scrolled sideways, which only the view can know. Read with `onGeometryChange`, since a
    /// `GeometryReader` with a preference did not update while the tree scrolled on iOS 26.3 (spike #145).
    @State private var sidewaysOffset: CGFloat = 0

    /// The drag in progress, from the lift to the release, and nil while no row is lifted.
    @State private var drag: ListsDrag?

    /// The frames the tree's items last reported, which the drag finds rows by.
    @State private var itemFrames = ListsTreeFrames()

    init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        let items = ListsTreeItem.items(of: model.rows)
        let drawn = drag?.drawn(items) ?? items
        let width = drawn.reduce(viewport.width) { max($0, widthNeeded(by: $1)) }
        ScrollViewReader { scroller in
            ScrollView([.horizontal, .vertical]) {
                tree(drawn, width: width, visibleRight: sidewaysOffset + viewport.width, items: items)
            }
            .coordinateSpace(.named(Self.viewportSpace))
            // A field can open on a row the lazy stack has not laid out, a new list in the last area or a new area at
            // the end of a long tree, and the stack makes no field for it, so it would never take the caret: the tree
            // scrolls that row to the middle of the screen, at the tree's leading edge where the field is, and the
            // field focuses itself as it appears. A row the stack has laid out, one on screen renamed from its menu,
            // stays where it is: the scroll with no anchor moved the tree sideways too, since a row wider than the
            // screen is never wholly in view (the iOS 26.3 simulator, 2026-10-29).
            .onChange(of: rowWithField) { _, id in
                guard let id, itemFrames.frames[.row(id)] == nil else { return }
                withAnimation(reduceMotion ? nil : Animation(.popover)) {
                    scroller.scrollTo(ListsTreeItem.ID.row(id), anchor: UnitPoint(x: 0, y: 0.5))
                }
            }
        }
        // A tree as narrow as the screen does not move sideways under a finger, as the canvas's does not.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .onGeometryChange(for: CGSize.self) { proxy in proxy.size } action: { viewport = $0 }
        .background(Color(.paper))
        .safeAreaInset(edge: .top, spacing: 0) { top }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottom }
        #if os(iOS)
        // The canvas has no title and no bar over the tree; the screens pushed over it keep theirs. The placement is
        // unavailable on macOS.
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .alert(model.confirmation?.title ?? "", isPresented: isConfirmationUp, presenting: model.confirmation) { _ in
            Button("Delete", role: .destructive) { send(.deleteConfirmed) }
            Button("Cancel", role: .cancel) { send(.deleteCancelled) }
        } message: { confirmation in
            Text(confirmation.message)
        }
        .sheet(isPresented: isMovePickerUp) {
            if let movePicker = model.movePicker {
                MovePickerSheet(model: movePicker, send: send)
            }
        }
    }



    // MARK: The tree

    /// The row whose field is open, the one row whose `draft` is not nil, and nil while no field is.
    private var rowWithField: ViewID? {
        model.rows.first { $0.draft != nil }?.id
    }

    /// The tree: the items in a lazy stack, each as wide as the tree, the lifted row's card over them, and the drag's
    /// recognizer behind them. The content is at least as tall as the viewport and stands at its top, since a
    /// `ScrollView` over both axes centres content shorter than itself, and a tree that a lifted block shortened would
    /// jump down (spike #145).
    private func tree(
        _ drawn: [ListsTreeItem], width: CGFloat, visibleRight: CGFloat, items: [ListsTreeItem]
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(drawn) { item in
                self.item(item, width: width, visibleRight: visibleRight)
                    .frame(width: width, alignment: .leading)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ListsTreeFramesKey.self, value: [item.id: proxy.frame(in: .named(Self.treeSpace))]
                            )
                        }
                    }
            }
        }
        .frame(width: width, alignment: .topLeading)
        .frame(minHeight: viewport.height, alignment: .topLeading)
        .overlay(alignment: .topLeading) { card(among: items, visibleRight: visibleRight) }
        .onGeometryChange(for: CGFloat.self) { proxy in
            max(0, -proxy.frame(in: .named(Self.viewportSpace)).minX)
        } action: { sidewaysOffset = $0 }
        #if os(iOS)
        // The drag is UIKit's long press, unavailable on macOS and watchOS, where the screen has none.
        .background {
            ListsDragGesture(isEnabled: model.isEditing) { phase in dragMoved(phase, among: items) }
        }
        #endif
        .coordinateSpace(.named(Self.treeSpace))
        .onPreferenceChange(ListsTreeFramesKey.self) { [itemFrames] frames in
            MainActor.assumeIsolated { itemFrames.frames = frames }
        }
    }

    /// One item of the tree, through the one switch over the items, every case drawn and none by `default`
    /// (`docs/style.md`, "Views").
    @ViewBuilder private func item(_ item: ListsTreeItem, width: CGFloat, visibleRight: CGFloat) -> some View {
        switch item {
        case .list(let row, let list, let guides):
            listRow(row, list, guides: guides, width: width, visibleRight: visibleRight)
        case .area(let row, let label):
            areaLine(row, label: label, visibleRight: visibleRight)
        case .slot(let depth, let guides):
            ListsDragSlot(depth: depth, guides: guides, visibleRight: visibleRight)
        }
    }

    /// A list's row in the tree: the row, the guides under it, and its count, chevron and grip pinned at the right edge
    /// of the screen, whose room the title leaves them. The highlighted row, the list declared over the screen, stands
    /// on the fill colour while that list is pushed and as it slides away, which the canvas's press on a row is; Back
    /// takes the highlight away (`TaskViewList`, `.uncovered`). A tap on the row is its choice outside edit mode and
    /// its rename in it. Its field ends where the accessories start on screen, as the canvas's does, where a title may
    /// run on under them to be read when the tree is scrolled sideways.
    private func listRow(
        _ row: TaskViewList.Model.Row, _ list: TaskViewList.Model.ListRow, guides: [CGFloat], width: CGFloat,
        visibleRight: CGFloat
    ) -> some View {
        let background = list.isSelected ? Color(.fill) : Color(.paper)
        return ListRowView(list, depth: row.depth, draft: row.draft, send: send)
            .padding(.trailing, ListRowAccessories.width(isEditing: model.isEditing))
            .frame(width: row.draft == nil ? width : min(width, visibleRight), alignment: .leading)
            .frame(width: width, alignment: .leading)
            .background { TreeGuides(guides) }
            .overlay(alignment: .leading) {
                ListRowAccessories(list, id: row.id, isEditing: model.isEditing, background: background, send: send)
                    .frame(width: visibleRight, alignment: .trailing)
            }
            .background(background)
            .contentShape(.rect)
            .rowTap(row, send: send)
            #if !os(watchOS)
            // Not on the watch, where the modifier is deprecated since watchOS 7, as the sidebar's menu is not
            // (`TaskViewListView`). In edit mode the menu is empty, which iOS opens as no menu, so that the long press
            // there is the drag's.
            .contextMenu {
                if !model.isEditing {
                    Button("Rename", systemImage: "pencil") { send(.renameMenuItemChosen(row.id)) }
                    Button("New List", systemImage: "plus") { send(.newListMenuItemChosen(in: row.id)) }
                    // Only where a window can open beside this one, which iPhone cannot (`docs/specs/navigation.md`,
                    // section 5): the root passes the request on, and the window's view opens the window.
                    if supportsMultipleWindows {
                        Button("Open in New Window", systemImage: "macwindow.badge.plus") {
                            send(.openInNewWindowMenuItemChosen(row.id))
                        }
                    }
                    Button("Move to…", systemImage: "folder") { send(.moveToMenuItemChosen(row.id)) }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { send(.deleteMenuItemChosen(row.id)) }
                }
            }
            #endif
    }

    /// An area's line in the tree, as wide as the part of the tree on screen, so that its line reaches the right edge
    /// of the screen and its grip stands there. A tap on it is sent in edit mode and out of it alike, and the module
    /// decides what it means: in edit mode it opens the area's field, and outside it nothing (the controller's ruling
    /// on #148). Its menu has no Move to…, since an area moves along the root alone, by the drag (Lists screen spec,
    /// section 6).
    private func areaLine(_ row: TaskViewList.Model.Row, label: String?, visibleRight: CGFloat) -> some View {
        AreaLine(label: label, draft: row.draft, isEditing: model.isEditing, send: send)
            .frame(width: visibleRight, alignment: .leading)
            .contentShape(.rect)
            .rowTap(row, send: send)
            #if !os(watchOS)
            // As on a list's row.
            .contextMenu {
                if !model.isEditing {
                    Button("Rename", systemImage: "pencil") { send(.renameMenuItemChosen(row.id)) }
                    Button("New List", systemImage: "plus") { send(.newListMenuItemChosen(in: row.id)) }
                    Divider()
                    Button("Delete Area", systemImage: "trash", role: .destructive) {
                        send(.deleteMenuItemChosen(row.id))
                    }
                }
            }
            #endif
    }

    /// How wide the tree must be for an item: for a list's row, its tile at its depth, a title of 140 pt and the room
    /// its count, chevron and grip take (`Phone.dc.html`, a row's `need`); an area's line and the slot fit any width,
    /// the slot at most one level deeper than the row before it, whose card has room to spare at that row's width.
    private func widthNeeded(by item: ListsTreeItem) -> CGFloat {
        switch item {
        case .list(let row, let list, _):
            ListRowView.tileLeading(atDepth: row.depth) + list.tile.side + ListRowView.tileToTitle
                + ListRowView.minimumTitleWidth + ListRowAccessories.width(isEditing: model.isEditing)
        case .area, .slot:
            0
        }
    }

    // MARK: The drag

    /// The lifted row's card under the finger, while a row is lifted, moving to the slot's depth on the popover's
    /// motion.
    @ViewBuilder private func card(among items: [ListsTreeItem], visibleRight: CGFloat) -> some View {
        if let drag, let lifted = drag.lifted(among: items) {
            ListsDragCard(lifted, depth: drag.depth, visibleRight: visibleRight, send: send)
                .offset(y: drag.location.y - drag.grabOffset)
                .animation(reduceMotion ? nil : Animation(.popover), value: drag.depth)
        }
    }

    #if os(iOS)
    // The handler of `ListsDragGesture`, which is iOS's alone.

    /// A stage of the long press, among the items drawn with no row lifted: the lift, every move, which moves the slot
    /// on the popover's motion when it changes its place or its depth, and the release, which sends the drop once and
    /// puts the row down; a press that is cancelled puts it down and sends nothing.
    private func dragMoved(_ phase: ListsDragGesture.Phase, among items: [ListsTreeItem]) {
        let motion = reduceMotion ? nil : Animation(.popover)
        switch phase {
        case .began(let point):
            guard let lifted = ListsDrag(liftingAt: point, among: items, frames: itemFrames.frames) else { return }
            withAnimation(motion) { drag = lifted }
        case .changed(let point):
            guard let current = drag else { return }
            let moved = current.moved(to: point, among: items, frames: itemFrames.frames)
            if moved.slot != current.slot || moved.depth != current.depth {
                withAnimation(motion) { drag = moved }
            } else {
                drag = moved
            }
        case .ended:
            guard let current = drag else { return }
            withAnimation(motion) {
                send(current.drop(among: items))
                drag = nil
            }
        case .cancelled:
            withAnimation(motion) { drag = nil }
        }
    }
    #endif

    // MARK: The chrome

    /// The bar, and the sentence under the rows above it, where it stays as the sidebar's does, with the root's strip
    /// under the window below both (`RootView`). The canvas fades the rows out behind the bar over the 52 pt above it,
    /// which the tree's last row scrolls up to clear; the fade takes no touch, so a row behind it is still tapped.
    private var bottom: some View {
        VStack(spacing: 0) {
            if let problem = model.problem {
                Text(problem)
                    .foregroundStyle(Color(.ink))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.paper))
            }
            ListsBottomBar(isEditing: model.isEditing, send: send)
        }
        .padding(.top, 52)
        .background {
            LinearGradient(
                stops: [
                    .init(color: Color(.paper).opacity(0), location: 0), .init(color: Color(.paper), location: 0.72),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    /// The canvas's 4 pt between the status bar and the first row, and its fade under the status bar, the paper down to
    /// 55 % of the way and fading out below, so that the rows scrolled up under the status bar do not run into its
    /// text. An inset of the screen's own, whose fade reaches up under the status bar: the scroll view already stands
    /// under it, so a fade laid over the scroll view's top and told to ignore the safe area stayed 2 pt tall (the iOS
    /// 26.3 simulator, 2026-10-29).
    private var top: some View {
        Color.clear
            .frame(height: 4)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: Color(.paper), location: 0.55),
                        .init(color: Color(.paper).opacity(0), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
    }

    // MARK: The dialogs

    /// Whether the confirmation is up, read from the model and moved only by an action, which a write of false is not.
    /// Every dismissal of an alert is one of its own buttons, since iOS has no tap outside one, and each button sends
    /// its own action, so the alert's dismissal is its Cancel through the button, whichever SwiftUI does first, the
    /// button's action or its write into this binding (`TaskViewListView`, 2026-10-29).
    private var isConfirmationUp: Binding<Bool> {
        Binding(get: { model.confirmation != nil }, set: { _ in })
    }

    /// Whether the move picker is up, read from the model and moved only by an action. The swipe down is one write of
    /// false, which goes to the module as the picker's Cancel; the write that follows a close the module drove, a row
    /// tapped or Cancel, reaches no picker and moves nothing.
    private var isMovePickerUp: Binding<Bool> {
        Binding(get: { model.movePicker != nil }, set: { isUp in
            guard !isUp else { return }
            send(.movePickerCancelled)
        })
    }

    /// The coordinate space of the tree's content, which the rows report their frames in and the drag's recognizer
    /// measures the finger in, and the one of the scroll view's viewport, against which the content's sideways offset
    /// is read.
    private nonisolated static let treeSpace = "ListsScreen.tree"
    private nonisolated static let viewportSpace = "ListsScreen.viewport"
}

extension View {
    /// The tap on a row or a line of the tree, sent as `rowSelected`, whose meaning, a choice or a rename, is the
    /// module's. A row whose field is open takes no tap of its own, its field and its chevron keeping theirs, so that
    /// every tap on the field is the field's.
    fileprivate func rowTap(
        _ row: TaskViewList.Model.Row, send: @escaping (TaskViewList.UserAction) -> Void
    ) -> some View {
        gesture(TapGesture().onEnded { send(.rowSelected(row.id)) }, including: row.draft == nil ? .all : .subviews)
    }
}

/// What the tree draws, in order: a list's row with the guides down the levels it stands under, an area's line, and,
/// while a row is lifted, the slot where it would land, with its own guides. The items are built from the model's rows
/// through the one switch over a row's kind (`items(of:)`), and the tree draws each through one switch over these.
enum ListsTreeItem: Identifiable {
    case list(TaskViewList.Model.Row, TaskViewList.Model.ListRow, guides: [CGFloat])
    case area(TaskViewList.Model.Row, label: String?)
    case slot(depth: Int, guides: [CGFloat])

    /// An item's identity in the tree: its row's id, or the slot, of which there is one.
    enum ID: Hashable {
        case row(ViewID)
        case slot
    }

    var id: ID {
        switch self {
        case .list(let row, _, _), .area(let row, _): .row(row.id)
        case .slot: .slot
        }
    }

    /// The id of the row the item draws, and nil for the slot.
    var rowID: ViewID? {
        switch self {
        case .list(let row, _, _), .area(let row, _): row.id
        case .slot: nil
        }
    }

    /// The depth the item is drawn at.
    var depth: Int {
        switch self {
        case .list(let row, _, _), .area(let row, _): row.depth
        case .slot(let depth, _): depth
        }
    }

    /// Whether the item is an area's line, which the drag carries with its lists and sets down only where an area can
    /// stand (Lists screen spec, section 7).
    var isAreaLine: Bool {
        switch self {
        case .area: true
        case .list, .slot: false
        }
    }

    /// The guides a row one level deeper than this item stands under: a list's own, and one under its tile; none under
    /// an area's line, whose lists stand at its own depth, or under the slot.
    var guidesBelow: [CGFloat] {
        switch self {
        case .list(let row, let list, let guides):
            guides + [Self.guideCentre(atDepth: row.depth, tileSide: list.tile.side)]
        case .area, .slot: []
        }
    }

    /// The tree's items for the rows, in one pass in tree order that carries the centres of the tiles of the branch it
    /// is in, so that each list's row has a guide under every ancestor's tile: in tree order a row's ancestor at a
    /// depth is the last list passed at that depth.
    static func items(of rows: [TaskViewList.Model.Row]) -> [ListsTreeItem] {
        var centres: [CGFloat] = []
        return rows.map { row in
            switch row.kind {
            case .area(let label):
                return .area(row, label: label)
            case .list(let list):
                let guides = Array(centres.prefix(row.depth))
                centres = guides + [guideCentre(atDepth: row.depth, tileSide: list.tile.side)]
                return .list(row, list, guides: guides)
            }
        }
    }

    /// Where the guide under a tile of the side at the depth stands: under its centre (`Phone.dc.html`, `guidesFor`).
    private static func guideCentre(atDepth depth: Int, tileSide: Double) -> CGFloat {
        ListRowView.tileLeading(atDepth: depth) + tileSide / 2
    }
}
