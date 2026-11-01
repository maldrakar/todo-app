// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsDragGesture.swift
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature
import TodoCore
#if os(iOS)
// The drag's recognizer, below, is UIKit's, and iOS's alone.
import UIKit
#endif

/// A row the drag has lifted, in edit mode on iOS and at any time on the Mac, from the lift to the release (Lists
/// screen spec, sections 7 and 8), the way spike #145 answered it: which row and how deep it stood, where the finger or
/// the pointer lifted it and where it is now, and where the slot stands among the rows left in place, at which depth.
/// It is the view's own state, which nothing else can know, and it sends nothing until the release, which reports
/// `rowDropped` once; what the drop means is the module's to read. Each stage of the press moves it through one step,
/// `after(_:from:among:frames:indent:)`, which knows no platform, so that the drag is tested on the host
/// (`ListsDragTests`).
///
/// The lifted block is a list with the rows after it that are deeper than it, or an area's line with every row up to
/// the next line, so that the slot is offered among the rows the drop would land among. A list's slot goes where the
/// finger is and its depth follows the finger's sideways travel, a level per step of the tree's indent, which the
/// model's look of the drag gives (`DragModel`), bounded as the spike bounded it: no shallower than the row after the
/// slot, or 0 at the end, and no deeper than one past the row before it, or 0 when there is none or it is an area's
/// line, where a list goes into that area. An area's slot stands only where spec section 7 lets an area stand, right
/// before another line, the first one included, or at the end of the tree, always at depth 0, and never among an
/// area's lists or above the root's: elsewhere it stays where it was (the controller's ruling on #148).
///
/// It is the tree's, which the phone's screen and the wide window's sidebar both draw (`ListsTree`): the iPad's sidebar
/// drags with the phone's long press, and the Mac's with the pointer (Lists screen spec, section 8). The drag is the
/// platform's, since only the platform has the finger and the pointer, and its look is the model's (the owner,
/// 2026-10-30).
struct ListsDrag {
    /// A stage of the press that drives the drag, the long press's or the pointer's, with the finger's or the pointer's
    /// location in the tree's own coordinates where it has one: the press begins, moves, ends once, or is cancelled
    /// once.
    enum Phase {
        case began(CGPoint)
        case changed(CGPoint)
        case ended
        case cancelled
    }

    /// The lifted row, and whether it is an area's line.
    private let id: ViewID
    private let isAreaLine: Bool

    /// The depth the row stood at when it was lifted, which the finger's sideways travel adds levels to.
    private let liftedDepth: Int

    /// Where the finger lifted the row, in the tree's own coordinates.
    private let start: CGPoint

    /// How far below the lifted row's top the finger holds it, which the card keeps under the finger.
    let grabOffset: CGFloat

    /// Where the finger is now, in the tree's own coordinates.
    private(set) var location: CGPoint

    /// Where the slot stands, before the row at this index among the rows left in place, and the depth it offers.
    private(set) var slot: Int
    private(set) var depth: Int

    /// The drag after a stage of the press, among the items the tree draws with no row lifted and the frames their last
    /// layout reported, by the tree's indent, and the drop that stage reports: the press lifts the row under the
    /// finger, or nothing where no row is; a move moves the slot; the release reports the drop once and puts the row
    /// down; and a cancel puts it down and reports nothing. A stage with no row lifted, after a press that began over
    /// no row, moves nothing.
    static func after(
        _ phase: Phase, from drag: ListsDrag?, among items: [ListsTreeItem], frames: [ListsTreeItem.ID: CGRect],
        indent: IndentModel
    ) -> (drag: ListsDrag?, drop: TaskViewList.UserAction?) {
        switch phase {
        case .began(let point):
            (ListsDrag(liftingAt: point, among: items, frames: frames), nil)
        case .changed(let point):
            (drag?.moved(to: point, among: items, frames: frames, indent: indent), nil)
        case .ended:
            (nil, drag?.drop(among: items))
        case .cancelled:
            (nil, nil)
        }
    }

    /// What the tree draws while the row is lifted: every item but the lifted block, and the slot where the row would
    /// land, under the list's row before it, whose guides it stands under as far as its depth, and under none after an
    /// area's line or at the top.
    func drawn(_ items: [ListsTreeItem]) -> [ListsTreeItem] {
        var rest = Self.rest(of: items, without: id)
        let slot = min(self.slot, rest.count)
        rest.insert(.slot(depth: depth, under: slot > 0 ? rest[slot - 1].listRow : nil), at: slot)
        return rest
    }

    /// The lifted row's item, which the card draws.
    func lifted(among items: [ListsTreeItem]) -> ListsTreeItem? {
        items.first { $0.rowID == id }
    }

    /// Lifts the row under the point, by the frames the last layout reported; nothing when no row is under the finger.
    /// A row lifts where it stands, so its slot is its own place and its depth its own.
    private init?(liftingAt point: CGPoint, among items: [ListsTreeItem], frames: [ListsTreeItem.ID: CGRect]) {
        guard let index = items.firstIndex(where: { frames[$0.id]?.contains(point) == true }),
              let id = items[index].rowID, let frame = frames[items[index].id]
        else { return nil }
        self.id = id
        isAreaLine = items[index].isAreaLine
        liftedDepth = items[index].depth
        start = point
        grabOffset = point.y - frame.minY
        location = point
        slot = index
        depth = liftedDepth
    }

    /// The drag once the finger is at the point. Over the slot the slot stays, so that it does not flicker under the
    /// finger, the slot being taller than a row; over a row it goes before that row in the row's upper half and after
    /// it in the lower; above the first row it goes to the top, and below the last to the end. The rule reads the
    /// frames the rows reported and counts no rows, so it holds in a lazy stack too (spike #145).
    private func moved(
        to point: CGPoint, among items: [ListsTreeItem], frames: [ListsTreeItem.ID: CGRect], indent: IndentModel
    ) -> ListsDrag {
        let rest = Self.rest(of: items, without: id)
        let previous = min(slot, rest.count)
        var slot = previous
        if let frame = frames[.slot], frame.minY <= point.y, point.y < frame.maxY {
            // Over the slot, it stays.
        } else if let index = rest.firstIndex(where: { item in
            frames[item.id].map { $0.minY <= point.y && point.y < $0.maxY } ?? false
        }), let frame = frames[rest[index].id] {
            slot = point.y < frame.midY ? index : index + 1
        } else if let first = rest.first, let frame = frames[first.id], point.y < frame.minY {
            slot = 0
        } else if let last = rest.last, let frame = frames[last.id], point.y >= frame.maxY {
            slot = rest.count
        }
        if isAreaLine, rest.indices.contains(slot), !rest[slot].isAreaLine { slot = previous }
        var moved = self
        moved.location = point
        moved.slot = slot
        if isAreaLine {
            moved.depth = 0
        } else {
            let depths = Self.depths(
                after: slot > 0 ? rest[slot - 1] : nil, next: rest.indices.contains(slot) ? rest[slot] : nil
            )
            let levels = Int(((point.x - start.x) / indent.step).rounded())
            moved.depth = min(max(liftedDepth + levels, depths.lowerBound), depths.upperBound)
        }
        return moved
    }

    /// The drag's one report, on release: the row let go after the row before the slot, nil at the top of the tree, at
    /// the slot's depth.
    private func drop(among items: [ListsTreeItem]) -> TaskViewList.UserAction {
        let rest = Self.rest(of: items, without: id)
        let slot = min(self.slot, rest.count)
        return .rowDropped(id, after: slot > 0 ? rest[slot - 1].rowID : nil, depth: depth)
    }

    /// The items left in place while the row's block is lifted. A row no longer there, gone by a peer's change in the
    /// middle of the drag, lifts nothing, and its drop names a row the module does not draw, which moves nothing.
    private static func rest(of items: [ListsTreeItem], without id: ViewID) -> [ListsTreeItem] {
        guard let start = items.firstIndex(where: { $0.rowID == id }) else { return items }
        let lifted = items[start]
        let end = items[(start + 1)...].firstIndex { item in
            item.isAreaLine || (!lifted.isAreaLine && item.depth <= lifted.depth)
        } ?? items.endIndex
        return Array(items[..<start] + items[end...])
    }

    /// The depths a list can be let go at between two rows (spike #145).
    private static func depths(after: ListsTreeItem?, next: ListsTreeItem?) -> ClosedRange<Int> {
        let lowest = next?.depth ?? 0
        let deepest = after.map { $0.isAreaLine ? 0 : $0.depth + 1 } ?? 0
        return lowest...max(lowest, deepest)
    }
}

extension ListsDrag {
    /// The frames of the tree's items as their last layout reported them, in the tree's own coordinates, which the drag
    /// finds rows by. Kept in a class that nothing observes and held in the tree's state, so that a layout pass that
    /// reports them does not draw the tree again (spike #145).
    @MainActor
    final class ItemFrames {
        var byID: [ListsTreeItem.ID: CGRect] = [:]
    }

    /// How each item of the tree reports its frame: every item laid out puts its own into the preference, and the
    /// tree keeps the whole of what the last layout reported.
    struct ItemFramesKey: PreferenceKey {
        static let defaultValue: [ListsTreeItem.ID: CGRect] = [:]

        static func reduce(value: inout [ListsTreeItem.ID: CGRect], nextValue: () -> [ListsTreeItem.ID: CGRect]) {
            value.merge(nextValue()) { $1 }
        }
    }

    /// The mark of the place where the lifted row would land, as the drag's look describes it (`DragModel.Look`), drawn
    /// through the one switch over the look, both cases drawn and none by `default` (`docs/style.md`, "Views"), with
    /// the guides of the levels the row would stand under behind it, the list's row before it's own, as many as its
    /// depth, so that a branch's lines run on through it. It is the view's own feedback and sends nothing.
    ///
    /// The phone's slot (`DragModel.Slot`; `Phone.dc.html`, the slot's row) is taller than a row, so that it is steady
    /// under the finger, its frame drawn within it from its inset before the tile of its depth to its gap short of the
    /// right edge of the screen, filled and edged as the model says. The sidebar's indicator (`DragModel.Indicator`;
    /// `Mac.dc.html`, the drag's slot row) is a gap between the rows with the line and the circle centred in it, placed
    /// from the leading edge of the tile of its depth, and the lifted row's card at it (`IndicatorCard`).
    struct Slot: View {
        private let model: DragModel
        private let depth: Int
        private let under: ListRowModel<TaskViewList.UserAction>?
        private let lifted: ListsTreeItem?
        private let visibleRight: CGFloat

        /// The mark at the depth, after the list's row it stands under, and nil after an area's line or at the top, for
        /// the lifted item, which the indicator's card draws.
        init(
            _ model: DragModel, depth: Int, under: ListRowModel<TaskViewList.UserAction>?, lifted: ListsTreeItem?,
            visibleRight: CGFloat
        ) {
            self.model = model
            self.depth = depth
            self.under = under
            self.lifted = lifted
            self.visibleRight = visibleRight
        }

        var body: some View {
            mark
                .background {
                    if let under {
                        ListsTreeItem.Guides(under.childGuides.prefix(depth), in: under.guide)
                    }
                }
                .accessibilityHidden(true)
        }

        @ViewBuilder private var mark: some View {
            switch model.look {
            case .slot(let slot, _):
                slotMark(slot)
            case .indicator(let indicator):
                indicatorMark(indicator)
            }
        }

        private func slotMark(_ slot: DragModel.Slot) -> some View {
            let leading = model.indent.leading(atDepth: depth) - slot.inset
            let shape = RoundedRectangle(cornerRadius: slot.cornerRadius)
            return shape
                .fill(Color(slot.fill))
                .overlay { shape.stroke(slot.stroke) }
                .frame(
                    width: max(0, visibleRight - slot.trailingGap - leading),
                    height: slot.height - 2 * slot.verticalInset
                )
                .padding(.leading, leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .frame(height: slot.height)
        }

        /// The line, a rule rounded at its ends, and the circle over its start, ringed inside its diameter as the
        /// canvas's border is, each placed from the tile's leading edge at the mark's depth; and the card at the mark,
        /// centred on the line.
        private func indicatorMark(_ indicator: DragModel.Indicator) -> some View {
            let tile = model.indent.leading(atDepth: depth)
            let lineStart = tile + indicator.lineOffset
            return ZStack(alignment: .leading) {
                Rule(indicator.line, along: .horizontal)
                    .frame(width: max(0, visibleRight - indicator.trailingGap - lineStart))
                    .clipShape(.rect(cornerRadius: indicator.lineCornerRadius))
                    .padding(.leading, lineStart)
                Circle()
                    .fill(Color(indicator.circleFill))
                    .overlay { Circle().inset(by: indicator.circleRing.width / 2).stroke(indicator.circleRing) }
                    .frame(width: indicator.circleDiameter, height: indicator.circleDiameter)
                    .padding(.leading, tile + indicator.circleOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .frame(height: indicator.height)
            .overlay(alignment: .leading) {
                if let lifted {
                    IndicatorCard(lifted, indicator.card)
                        .padding(.leading, tile + indicator.card.offset)
                }
            }
        }
    }

    /// The lifted row on the sidebar's card, as the indicator's card describes it (`DragModel.Indicator.Card`;
    /// `Mac.dc.html`, `.drag-ghost`): its size, on its background with its corners, casting its shadow, turned by its
    /// rotation and at its opacity, grown by nothing. A list's card holds the lifted row's tile, in its own colour and
    /// with its own icon at the card's sizes, and its title in the card's font, its padding in, its gap apart. A line's
    /// card holds the lifted line as the line draws itself, at its own leading and its own end inside the card, since
    /// the canvas draws no line's card and the card's model carries no numbers of its own for one: its label, or the
    /// line alone, across the card. It takes no touch.
    fileprivate struct IndicatorCard: View {
        private let item: ListsTreeItem
        private let card: DragModel.Indicator.Card

        init(_ item: ListsTreeItem, _ card: DragModel.Indicator.Card) {
            self.item = item
            self.card = card
        }

        var body: some View {
            content
                .frame(width: card.width, height: card.height)
                // Circular corners, as the canvas's `border-radius` draws them (`ListTile`).
                .background(Color(card.background), in: .rect(cornerRadius: card.cornerRadius, style: .circular))
                .shadow(card.shadow)
                .rotationEffect(.degrees(card.rotation))
                .opacity(card.opacity)
                .allowsHitTesting(false)
        }

        /// The card's content of the lifted row's kind. The slot is never lifted, so its case draws nothing.
        @ViewBuilder private var content: some View {
            switch item {
            case .list(_, let list):
                HStack(spacing: card.tileToTitle) {
                    ListTile(
                        TileModel(
                            color: list.tile.color, icon: list.tile.glyph.icon, side: card.tileSide,
                            cornerRadius: card.tileCornerRadius, glyphSize: card.glyphSize
                        )
                    )
                    Text(TextModel(text: list.title.text, font: card.titleFont, color: list.title.color))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, card.padding)
            case .area(_, let line):
                AreaLine(lifted: line)
            case .slot:
                EmptyView()
            }
        }
    }

    /// The lifted row, carried under the finger, as the phone's card describes it (`DragModel.Card`; `Phone.dc.html`,
    /// the drag's card): on its background with its shadow, grown to its scale on the drag's motion once it appears and
    /// turned by its rotation. A list's card stands at the tile of the slot's depth, the lifted row's tile and title on
    /// it with the grip at its end, out to its gap short of the right edge of the screen; an area's is the lifted line
    /// across the screen. The canvas's overshoot and bob have no motion of the look and are left out; with Reduce
    /// Motion the card is at its scale at once.
    struct Card: View {
        private let item: ListsTreeItem
        private let card: DragModel.Card
        private let model: DragModel
        private let depth: Int
        private let visibleRight: CGFloat

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// Whether the card has grown to its lifted scale, which it does once it appears.
        @State private var isLifted = false

        /// The card of the drag's look for the lifted item, placed by the drag's indent and grown on its motion.
        init(_ item: ListsTreeItem, _ card: DragModel.Card, of model: DragModel, depth: Int, visibleRight: CGFloat) {
            self.item = item
            self.card = card
            self.model = model
            self.depth = depth
            self.visibleRight = visibleRight
        }

        var body: some View {
            content
                .scaleEffect(isLifted ? card.scale : 1)
                .rotationEffect(.degrees(card.rotation))
                .shadow(card.shadow)
                .onAppear {
                    withAnimation(reduceMotion ? nil : Animation(model.animation)) { isLifted = true }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }

        /// The card of the lifted row's kind. The slot is never lifted, so its case draws nothing.
        @ViewBuilder private var content: some View {
            switch item {
            case .list(_, let list):
                let leading = model.indent.leading(atDepth: depth) - card.listInset
                HStack(spacing: list.tileToTitle) {
                    ListTile(list.tile)
                    Text(list.title)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Icon(card.grip)
                        .frame(width: card.gripCell, height: card.listHeight)
                }
                .padding(.leading, card.listPadding)
                .frame(
                    width: max(card.minimumWidth, visibleRight - card.listTrailingGap - leading),
                    height: card.listHeight
                )
                .background(Color(card.background), in: .rect(cornerRadius: card.listCornerRadius))
                .offset(x: leading)
            case .area(_, let line):
                AreaLine(lifted: line)
                    .frame(
                        width: max(card.minimumWidth, visibleRight - card.lineInset - card.lineTrailingGap),
                        height: card.lineHeight
                    )
                    .background(Color(card.background), in: .rect(cornerRadius: card.lineCornerRadius))
                    .offset(x: card.lineInset)
            case .slot:
                EmptyView()
            }
        }
    }
}

#if os(iOS)
/// The drag's long press, which only UIKit can give the tree (spike #145, approach B2): one
/// `UILongPressGestureRecognizer` of 0.4 s on the `UIScrollView` behind the tree's `ScrollView`, found from a plain
/// view placed as the tree's background by walking up its superviews. SwiftUI's own long press sequenced before a drag
/// took the touch from the scroll view, and the tree scrolled on neither axis; this recognizer and the scroll view's
/// pan share the touch through UIKit's defaults alone: a finger that moves 10 pt before 0.4 s fails the press and
/// scrolls, and once the press has begun the pan cannot, so the tree does not slide under a drag. A location in the
/// background view is a location in the tree's own coordinates, the space the rows report their frames in.
///
/// It is enabled in edit mode only, where the rows' context menus are off, so that outside it the long press is the
/// menu's (the controller's ruling on #148). The touch it is handed is its own unless it lands in a text field, whose
/// long press is the caret's loupe. While a row is lifted and the finger is within 60 pt of the top or the bottom of
/// the scroll view, the tree scrolls toward it, up to 12 pt a frame, as the spike's tried and the bottom edge checked.
/// It is iOS's alone: UIKit's recognizers are unavailable on macOS, where the pointer drags at any time
/// (`ListsTree`), and on watchOS, where the tree has no drag.
struct ListsDragGesture: UIViewRepresentable {
    private let isEnabled: Bool
    private let isRowLifted: Bool
    private let onPhase: (ListsDrag.Phase) -> Void

    /// A recognizer enabled or not, scrolling near the edges while the tree says a row is lifted, which hands each
    /// stage of the press to the tree.
    init(isEnabled: Bool, isRowLifted: Bool, onPhase: @escaping (ListsDrag.Phase) -> Void) {
        self.isEnabled = isEnabled
        self.isRowLifted = isRowLifted
        self.onPhase = onPhase
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ScrollViewFinder {
        let finder = ScrollViewFinder()
        // The view only places the recognizer and measures the finger; the rows under it take the touches.
        finder.isUserInteractionEnabled = false
        finder.coordinator = context.coordinator
        context.coordinator.finder = finder
        return finder
    }

    func updateUIView(_ finder: ScrollViewFinder, context: Context) {
        context.coordinator.onPhase = onPhase
        context.coordinator.recognizer.isEnabled = isEnabled
        context.coordinator.scrollsNearTheEdges(isRowLifted)
    }

    static func dismantleUIView(_ finder: ScrollViewFinder, coordinator: Coordinator) {
        coordinator.scrollsNearTheEdges(false)
        coordinator.recognizer.view?.removeGestureRecognizer(coordinator.recognizer)
    }

    /// The recognizer's target and delegate, which hands each stage of the press to the tree, and the scroll near the
    /// edges while a row is lifted.
    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPhase: (ListsDrag.Phase) -> Void = { _ in }
        weak var finder: UIView?
        private var autoScroll: CADisplayLink?

        private(set) lazy var recognizer: UILongPressGestureRecognizer = {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(recognizerChanged(_:)))
            recognizer.minimumPressDuration = 0.4
            recognizer.delegate = self
            return recognizer
        }()

        @objc private func recognizerChanged(_ recognizer: UILongPressGestureRecognizer) {
            guard let finder else { return }
            switch recognizer.state {
            case .began:
                onPhase(.began(recognizer.location(in: finder)))
            case .changed:
                onPhase(.changed(recognizer.location(in: finder)))
            case .ended:
                onPhase(.ended)
            case .cancelled, .failed:
                onPhase(.cancelled)
            case .possible:
                break
            @unknown default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextInput { return false }
                view = current.superview
            }
            return true
        }

        /// Starts the scroll near the edges when a row is lifted, and stops it when none is, from the tree's drag and
        /// not the press, so that a press over no row scrolls nothing.
        func scrollsNearTheEdges(_ isRowLifted: Bool) {
            if isRowLifted, autoScroll == nil {
                let link = CADisplayLink(target: self, selector: #selector(autoScrollTick))
                link.add(to: .main, forMode: .common)
                autoScroll = link
            } else if !isRowLifted {
                autoScroll?.invalidate()
                autoScroll = nil
            }
        }

        /// One frame of the scroll toward the edge the finger is near, faster the nearer it is, and a `changed` after
        /// it, so that the slot follows the rows moving under a finger that stands still.
        @objc private func autoScrollTick() {
            guard let scrollView = recognizer.view as? UIScrollView, let finder,
                  recognizer.state == .began || recognizer.state == .changed
            else { return }
            let finger = recognizer.location(in: scrollView.superview)
            let top = scrollView.frame.minY + scrollView.adjustedContentInset.top
            let bottom = scrollView.frame.maxY - scrollView.adjustedContentInset.bottom
            let zone: CGFloat = 60
            let nearness = if finger.y < top + zone {
                -(top + zone - finger.y) / zone
            } else if finger.y > bottom - zone {
                (finger.y - (bottom - zone)) / zone
            } else {
                CGFloat(0)
            }
            guard nearness != 0 else { return }
            let highest = -scrollView.adjustedContentInset.top
            let lowest = max(
                highest,
                scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
            )
            let offset = min(max(scrollView.contentOffset.y + min(max(nearness, -1), 1) * 12, highest), lowest)
            guard offset != scrollView.contentOffset.y else { return }
            scrollView.contentOffset.y = offset
            onPhase(.changed(recognizer.location(in: finder)))
        }
    }

    /// The plain view placed as the tree's background, which finds the scroll view above it once it is in a window and
    /// puts the recognizer on it. It depends on SwiftUI building a `ScrollView` as a `UIScrollView` above its content,
    /// which iOS 26.3 does as `HostingScrollView` (spike #145); iOS 18's `UIGestureRecognizerRepresentable` is the
    /// official route, and iOS 17 needs this one.
    final class ScrollViewFinder: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil, let coordinator else { return }
            var view = superview
            while let candidate = view, !(candidate is UIScrollView) { view = candidate.superview }
            guard let scrollView = view as? UIScrollView, coordinator.recognizer.view !== scrollView else { return }
            scrollView.addGestureRecognizer(coordinator.recognizer)
        }
    }
}
#endif
