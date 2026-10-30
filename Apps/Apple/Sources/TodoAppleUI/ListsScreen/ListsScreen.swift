// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsScreen.swift
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature
import TodoCore

/// The Lists screen on a phone, at the root of a narrow window's stack, as the canvas draws it (`Phone.dc.html`; Lists
/// screen spec, sections 1, 6 and 7): one scrolling tree with no title and no navigation bar, the bar at the bottom
/// (`ListsBottomBar`), the confirmation of a delete as an alert and Move to… as a sheet (`MovePickerSheet`). Everything
/// it draws arrives finished in the model, each part of it the model of the component that draws it, with every size,
/// colour, font, glyph and word (ADR-0007, amendment of 2026-10-30), and each gesture is sent as the action its
/// control's model holds: what follows is the module's. It decides only what is the platform's: its containers, the
/// fades and the sheet and the alert; its gestures and the drag; scrolling, focus and Reduce Motion. It keeps only what
/// only it can know, the size of its viewport, how far the tree is scrolled sideways, and a drag in progress
/// (`docs/style.md`, "Views").
///
/// The tree is a `ScrollView` over both axes and not a `List`, which moves a row up and down a flat list and knows
/// nothing of depth (spike #145). A tree narrower than a row's need, the room its tile, its title's least width and its
/// accessories take, is as wide as its widest row and scrolls sideways, while the count, the chevron and the grip stay
/// pinned at the right edge of the screen (`Phone.dc.html`, a row's `need`).
///
/// Outside edit mode a tap on a list's row chooses it, its chevron folds its branch, and a long press opens the menu of
/// the row's kind. In edit mode the counts leave the rows and the grips come, a tap on a row or on an area's line opens
/// its field, and a long press lifts the row for the drag (`ListsDragGesture`), where no row has a menu.
struct ListsScreen: View {
    private let model: TaskViewList.Model
    private let send: (TaskViewList.UserAction) -> Void

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
    @State private var itemFrames = ListsDrag.ItemFrames()

    /// Where the tree stands up and down in its viewport, which a field that opens is shown by (`showField`).
    @State private var treePosition = TreePosition()

    init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        let items = ListsTreeItem.items(of: model.rows)
        let drawn = drag?.drawn(items) ?? items
        // Over every row and not the drawn ones, so that lifting the deepest rows does not narrow the tree under a
        // still finger, which would slide it sideways and move the depth the finger chose.
        let width = items.reduce(viewport.width) { max($0, widthNeeded(by: $1)) }
        ScrollViewReader { scroller in
            ScrollView([.horizontal, .vertical]) {
                tree(drawn, width: width, visibleRight: sidewaysOffset + viewport.width, items: items)
            }
            .coordinateSpace(.named(Self.viewportSpace))
            .onChange(of: model.renaming) { _, id in
                guard let id else { return }
                showField(of: id, among: items, width: width, scroller: scroller)
            }
        }
        // A tree as narrow as the screen does not move sideways under a finger, as the canvas's does not.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .onGeometryChange(for: CGSize.self) { proxy in proxy.size } action: { viewport = $0 }
        .background(Color(.paper))
        .safeAreaInset(edge: .top, spacing: 0) { top }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottom }
        #if !os(macOS)
        // The canvas has no title and no bar over the tree; the screens pushed over it keep theirs. The placement is
        // unavailable on macOS.
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .modifier(ListsDialogs(model: model, send: send) { MovePickerSheet(model: $0, send: send) })
    }

    // MARK: The tree

    /// The tree: the items in a stack, each as wide as the tree, the lifted row's card over them, and the drag's
    /// recognizer behind them. The content is at least as tall as the viewport and stands at its top, since a
    /// `ScrollView` over both axes centres content shorter than itself, and a tree that a lifted block shortened would
    /// jump down (spike #145).
    ///
    /// The stack makes every row, a `VStack` where the spike's was a `LazyVStack`. A lazy stack made a new row's field
    /// below the screen and dropped it again as the tree scrolled there, and the field lost the caret as it went, which
    /// is a lost focus to the module, so the field closed before it was seen: by taps on "+" → New Area, + List and
    /// + Area, from the top of the seeded tree (the controller's hand check of #148, the iOS 26.3 simulator,
    /// 2026-10-29). The tree is tens of rows, as the module reads it whole (`TaskViewList`, `.changed`), and the
    /// drag's rule reads whatever frames the rows report.
    private func tree(
        _ drawn: [ListsTreeItem], width: CGFloat, visibleRight: CGFloat, items: [ListsTreeItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(drawn) { item in
                self.item(item, width: width, visibleRight: visibleRight)
                    .frame(width: width, alignment: .leading)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ListsDrag.ItemFramesKey.self,
                                value: [item.id: proxy.frame(in: .named(Self.treeSpace))]
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
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .named(Self.viewportSpace)).minY
        } action: { treePosition.contentTop = $0 }
        #if os(iOS)
        // The drag is UIKit's long press, unavailable on macOS and watchOS, where the screen has none.
        .background {
            ListsDragGesture(isEnabled: model.isEditing, isRowLifted: drag != nil) { phase in
                pressChanged(phase, among: items)
            }
        }
        #endif
        .coordinateSpace(.named(Self.treeSpace))
        .onPreferenceChange(ListsDrag.ItemFramesKey.self) { [itemFrames] frames in
            MainActor.assumeIsolated { itemFrames.byID = frames }
        }
    }

    /// One item of the tree, through the one switch over the items, every case drawn and none by `default`
    /// (`docs/style.md`, "Views").
    @ViewBuilder private func item(_ item: ListsTreeItem, width: CGFloat, visibleRight: CGFloat) -> some View {
        switch item {
        case .list(_, let list):
            listRow(list, width: width, visibleRight: visibleRight)
        case .area(_, let line):
            areaLine(line, visibleRight: visibleRight)
        case .slot(let depth, let under):
            ListsDrag.Slot(model.drag, depth: depth, under: under, visibleRight: visibleRight)
        }
    }

    /// A list's row in the tree: the row, the guides under it, and its accessories pinned at the right edge of the
    /// screen, whose room the title leaves them, all on the row's background. The highlighted row, the list declared
    /// over the screen, stands on its highlight while that list is pushed and as it slides away, which the canvas's
    /// press on a row is; Back takes the highlight away (`TaskViewList`, `.uncovered`). A tap on the row is its choice
    /// outside edit mode and its rename in it.
    ///
    /// A title runs on under the accessories, to be read when the tree is scrolled sideways, and so does the canvas's
    /// field, across the whole tree. This field stops where the accessories start on screen instead, so that its end
    /// and its caret are never under them, but never short of the row's need, its title's least width among it, which
    /// the tree scrolls sideways to show when the field opens (`showField`).
    private func listRow(
        _ list: ListRowModel<TaskViewList.UserAction>, width: CGFloat, visibleRight: CGFloat
    ) -> some View {
        let background = Color(list.background)
        return ListRowView(list, send: send)
            .padding(.trailing, list.accessories.width)
            .frame(width: list.field == nil ? width : min(width, max(visibleRight, list.need)), alignment: .leading)
            .frame(width: width, alignment: .leading)
            .background { ListsTreeItem.Guides(list.guides, in: list.guide) }
            .overlay(alignment: .leading) {
                ListRowView.Accessories(list.accessories, background: background, height: list.height, send: send)
                    .frame(width: visibleRight, alignment: .trailing)
            }
            .overlay(alignment: .leading) {
                if list.field != nil {
                    fieldSpan(from: list.leading + list.tile.side + list.tileToTitle, to: list.need)
                }
            }
            .background(background)
            .contentShape(.rect)
            .rowTap(list.tap, hasField: list.field != nil, send: send)
            #if !os(watchOS)
            // Not on the watch, where the modifier is deprecated since watchOS 7, as the sidebar's menu is not
            // (`TaskViewListView`). A row with no menu, every row in edit mode, has an empty one, which iOS opens as no
            // menu, so that the long press there is the drag's.
            .contextMenu {
                if let menu = list.menu {
                    MenuItems(menu, send: send)
                }
            }
            #endif
    }

    /// An area's line in the tree, as wide as the part of the tree on screen, so that its line reaches the right edge
    /// of the screen and its grip stands there. A tap on it is sent in edit mode and out of it alike, and the module
    /// decides what it means: in edit mode it opens the area's field, and outside it nothing (the controller's ruling
    /// on #148).
    private func areaLine(_ line: AreaLineModel<TaskViewList.UserAction>, visibleRight: CGFloat) -> some View {
        AreaLine(line, send: send)
            .frame(width: visibleRight, alignment: .leading)
            .overlay(alignment: .leading) {
                if let field = line.field {
                    fieldSpan(from: 0, to: line.leading + field.minimumWidth)
                }
            }
            .contentShape(.rect)
            .rowTap(line.tap, hasField: line.field != nil, send: send)
            #if !os(watchOS)
            // As on a list's row.
            .contextMenu {
                if let menu = line.menu {
                    MenuItems(menu, send: send)
                }
            }
            #endif
    }

    /// How wide the tree must be for an item: a list's row's need (`Phone.dc.html`, a row's `need`); an area's line
    /// fits any width, and the slot, which is never among the rows the tree's width is read from, needs nothing either.
    private func widthNeeded(by item: ListsTreeItem) -> CGFloat {
        switch item {
        case .list(_, let list):
            list.need
        case .area, .slot:
            0
        }
    }

    /// The part of a row its open field needs on screen, from where the field starts to the end of the row's need, or
    /// of the line's field, which the scroll to a field that opens shows with the least movement: one row at a time has
    /// a field, so its identity is one constant.
    private func fieldSpan(from start: CGFloat, to end: CGFloat) -> some View {
        Color.clear
            .frame(width: max(0, end - start))
            .frame(maxHeight: .infinity)
            .padding(.leading, start)
            .id(Self.fieldSpanID)
    }

    /// Shows the field that has just opened on the row the model names as `renaming`, read from where the row stands. A
    /// row on screen, one renamed from its menu, is scrolled as little as shows its field's span, once that span is
    /// laid out, which for a shallow row is not at all. A row off screen, a new list in the last area or a new area at
    /// the end of a long tree, is scrolled to the middle of the screen, and sideways as far as its need, the field's
    /// least width among it. A scroll to the row itself with no anchor moved the tree sideways to its far end, since a
    /// row wider than the screen is never wholly in view (the iOS 26.3 simulator, 2026-10-29). The scroll is the
    /// platform's, and so is its motion, the popover's.
    private func showField(
        of id: ViewID, among items: [ListsTreeItem], width: CGFloat, scroller: ScrollViewProxy
    ) {
        let motion = reduceMotion ? nil : Animation(.popover)
        if let frame = itemFrames.byID[.row(id)], treePosition.shows(frame, in: viewport.height) {
            Task { @MainActor in
                withAnimation(motion) { scroller.scrollTo(Self.fieldSpanID) }
            }
            return
        }
        // The anchor's x puts that fraction of the row's width at the same fraction of the screen's, so the tree's
        // offset is the fraction of how far it scrolls, and the row's need ends at the right edge.
        let need = items.first { $0.rowID == id }.map { widthNeeded(by: $0) } ?? 0
        let travel = width - viewport.width
        let sideways = travel > 0 ? min(1, max(0, need - viewport.width) / travel) : 0
        withAnimation(motion) {
            scroller.scrollTo(ListsTreeItem.ID.row(id), anchor: UnitPoint(x: sideways, y: 0.5))
        }
    }

    // MARK: The drag

    /// The lifted row's card under the finger, while a row is lifted, standing its raise above the row as the finger
    /// holds it, as the canvas's card stands in its slot, and moving to the slot's depth on the drag's motion.
    @ViewBuilder private func card(among items: [ListsTreeItem], visibleRight: CGFloat) -> some View {
        if let drag, let lifted = drag.lifted(among: items) {
            ListsDrag.Card(lifted, model.drag, depth: drag.depth, visibleRight: visibleRight)
                .offset(y: drag.location.y - drag.grabOffset - model.drag.card.raise)
                .animation(reduceMotion ? nil : Animation(model.drag.animation), value: drag.depth)
        }
    }

    #if os(iOS)
    // The handler of `ListsDragGesture`, which is iOS's alone.

    /// Hands a stage of the long press to the drag, among the items drawn with no row lifted and by the tree's indent,
    /// and sends the drop the release reports. The lift, the release and a move of the slot to another place or depth
    /// go on the drag's motion, and a move that leaves the slot where it was, the card alone following the finger, on
    /// none.
    private func pressChanged(_ phase: ListsDrag.Phase, among items: [ListsTreeItem]) {
        let step = ListsDrag.after(phase, from: drag, among: items, frames: itemFrames.byID, indent: model.drag.indent)
        let slotMoves = step.drag?.slot != drag?.slot || step.drag?.depth != drag?.depth
        withAnimation(slotMoves && !reduceMotion ? Animation(model.drag.animation) : nil) {
            if let drop = step.drop { send(drop) }
            drag = step.drag
        }
    }
    #endif

    // MARK: The chrome

    /// The bar, and the sentence under the rows above it, where it stays as the sidebar's does, with the root's strip
    /// under the window below both (`RootView`); the sentence's strip is the one every module's sentence shares, whose
    /// look no component's model holds yet (Lists screen plan, Task 8). The canvas fades the rows out behind the bar
    /// over the 52 pt above it, which the tree's last row scrolls up to clear; the fade is the platform's, as the glass
    /// under the bar's controls is, and takes no touch, so a row behind it is still tapped.
    private var bottom: some View {
        VStack(spacing: 0) {
            if let problem = model.problem {
                Text(problem)
                    .foregroundStyle(Color(.ink))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.paper))
            }
            ListsBottomBar(model.bar, send: send)
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
    /// text: the platform's, as the fade over the bar is. An inset of the screen's own, whose fade reaches up under the
    /// status bar: the scroll view already stands under it, so a fade laid over the scroll view's top and told to
    /// ignore the safe area stayed 2 pt tall (the iOS 26.3 simulator, 2026-10-29).
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

    /// The coordinate space of the tree's content, which the rows report their frames in and the drag's recognizer
    /// measures the finger in, and the one of the scroll view's viewport, against which the content's sideways offset
    /// is read.
    private nonisolated static let treeSpace = "ListsScreen.tree"
    private nonisolated static let viewportSpace = "ListsScreen.viewport"

    /// The identity of the open field's span (`fieldSpan`).
    private static let fieldSpanID = "ListsScreen.fieldSpan"
}

extension ListsScreen {
    /// Where the top of the tree's content stands in its viewport, which moves with every frame of a scroll and which
    /// only a field that opens reads: kept in a class that nothing observes and held in the screen's state, so that a
    /// scroll does not draw the screen again, as the drag's frames are (`ListsDrag.ItemFrames`).
    @MainActor
    final class TreePosition {
        var contentTop: CGFloat = 0

        /// Whether a frame of the tree's content stands wholly in a viewport of the height. The viewport is the part of
        /// the screen between the bars, so its height leaves them out, and its top is the content's top at rest: 674
        /// and 0 on an iPhone 17 (the iOS 26.3 simulator, 2026-10-29).
        func shows(_ frame: CGRect, in height: CGFloat) -> Bool {
            contentTop + frame.minY >= 0 && contentTop + frame.maxY <= height
        }
    }
}

extension View {
    /// The tap on a row or a line of the tree, sent as the action its model holds, `rowSelected`, whose meaning, a
    /// choice or a rename, is the module's. A row whose field is open takes no tap of its own, its field and its
    /// chevron keeping theirs, so that every tap on the field is the field's.
    fileprivate func rowTap(
        _ tap: TaskViewList.UserAction, hasField: Bool, send: @escaping (TaskViewList.UserAction) -> Void
    ) -> some View {
        gesture(TapGesture().onEnded { send(tap) }, including: hasField ? .subviews : .all)
    }
}

/// What the tree draws, in order: a list's row, an area's line, and, while a row is lifted, the slot where it would
/// land, under the list's row before it, whose guides it stands under. The items are built from the model's rows
/// through the one switch over a row's kind (`items(of:)`), and the tree draws each through one switch over these.
enum ListsTreeItem: Identifiable {
    case list(TaskViewList.Model.Row, ListRowModel<TaskViewList.UserAction>)
    case area(TaskViewList.Model.Row, AreaLineModel<TaskViewList.UserAction>)
    case slot(depth: Int, under: ListRowModel<TaskViewList.UserAction>?)

    /// An item's identity in the tree: its row's id, or the slot, of which there is one.
    enum ID: Hashable {
        case row(ViewID)
        case slot
    }

    var id: ID {
        switch self {
        case .list(let row, _), .area(let row, _): .row(row.id)
        case .slot: .slot
        }
    }

    /// The id of the row the item draws, and nil for the slot.
    var rowID: ViewID? {
        switch self {
        case .list(let row, _), .area(let row, _): row.id
        case .slot: nil
        }
    }

    /// The depth the item is drawn at.
    var depth: Int {
        switch self {
        case .list(let row, _), .area(let row, _): row.depth
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

    /// The list's row the item draws, and nil for an area's line and the slot: what a slot after the item stands under.
    var listRow: ListRowModel<TaskViewList.UserAction>? {
        switch self {
        case .list(_, let list): list
        case .area, .slot: nil
        }
    }

    /// The tree's items for the rows, each with the model of the row's kind.
    static func items(of rows: [TaskViewList.Model.Row]) -> [ListsTreeItem] {
        rows.map { row in
            switch row.kind {
            case .area(let line): .area(row, line)
            case .list(let list): .list(row, list)
            }
        }
    }

    /// The guides down the levels a row stands under (`Phone.dc.html`, `.guide`), each a rule of the row's guide the
    /// whole height of the row, centred where its model says from the tree's leading edge, so that the rows of a branch
    /// join them into lines.
    struct Guides: View {
        private let centres: [Double]
        private let guide: StrokeModel

        init(_ centres: some Sequence<Double>, in guide: StrokeModel) {
            self.centres = Array(centres)
            self.guide = guide
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                ForEach(centres.indices, id: \.self) { index in
                    Rule(guide, along: .vertical)
                        .offset(x: centres[index] - guide.width / 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
