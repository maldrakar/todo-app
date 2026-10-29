// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsDragGesture.swift
import SwiftUI
import TaskViewListFeature
import TodoCore
#if os(iOS)
// The drag's recognizer, below, is UIKit's, and iOS's alone.
import UIKit
#endif

/// A row the drag has lifted in edit mode, from the lift to the release (Lists screen spec, section 7), the way spike
/// #145 answered it: which row and how deep it stood, where the finger lifted it and where it is now, and where the
/// slot stands among the rows left in place, at which depth. It is the view's own state, which nothing else can know,
/// and it sends nothing until the release, which reports `rowDropped` once; what the drop means is the module's to
/// read. Each stage of the press moves it through one step, `after(_:from:among:frames:)`, which knows no platform, so
/// that the drag is tested on the host (`ListsDragTests`).
///
/// The lifted block is a list with the rows after it that are deeper than it, or an area's line with every row up to
/// the next line, so that the slot is offered among the rows the drop would land among. A list's slot goes where the
/// finger is and its depth follows the finger's sideways travel, a level per 22 pt, bounded as the spike bounded it: no
/// shallower than the row after the slot, or 0 at the end, and no deeper than one past the row before it, or 0 when
/// there is none or it is an area's line, where a list goes into that area. An area's slot stands only where spec
/// section 7 lets an area stand, right before another line, the first one included, or at the end of the tree, always
/// at depth 0, and never among an area's lists or above the root's: elsewhere it stays where it was (the controller's
/// ruling on #148).
///
/// It is top-level, and not the phone's screen's, because the iPad's sidebar drags with the phone's gestures in the
/// plan's eighth task (Lists screen spec, section 8).
struct ListsDrag {
    /// A stage of the long press that drives the drag, with the finger's location in the tree's own coordinates where
    /// it has one: the press begins, moves, ends once, or is cancelled once.
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

    /// How far below the card's top the finger holds it.
    let grabOffset: CGFloat

    /// Where the finger is now, in the tree's own coordinates.
    private(set) var location: CGPoint

    /// Where the slot stands, before the row at this index among the rows left in place, and the depth it offers.
    private(set) var slot: Int
    private(set) var depth: Int

    /// The drag after a stage of the press, among the items the tree draws with no row lifted and the frames their last
    /// layout reported, and the drop that stage reports: the press lifts the row under the finger, or nothing where no
    /// row is; a move moves the slot; the release reports the drop once and puts the row down; and a cancel puts it
    /// down and reports nothing. A stage with no row lifted, after a press that began over no row, moves nothing.
    static func after(
        _ phase: Phase, from drag: ListsDrag?, among items: [ListsTreeItem], frames: [ListsTreeItem.ID: CGRect]
    ) -> (drag: ListsDrag?, drop: TaskViewList.UserAction?) {
        switch phase {
        case .began(let point):
            (ListsDrag(liftingAt: point, among: items, frames: frames), nil)
        case .changed(let point):
            (drag?.moved(to: point, among: items, frames: frames), nil)
        case .ended:
            (nil, drag?.drop(among: items))
        case .cancelled:
            (nil, nil)
        }
    }

    /// What the tree draws while the row is lifted: every item but the lifted block, and the slot where the row would
    /// land, with the guides of the levels it would stand under, which are those of the row before it.
    func drawn(_ items: [ListsTreeItem]) -> [ListsTreeItem] {
        var rest = Self.rest(of: items, without: id)
        let slot = min(self.slot, rest.count)
        let guides = slot > 0 ? Array(rest[slot - 1].guidesBelow.prefix(depth)) : []
        rest.insert(.slot(depth: depth, guides: guides), at: slot)
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
        // The card stands 6 pt above the row it lifts, as the canvas's card stands in its slot.
        grabOffset = point.y - (frame.minY - 6)
        location = point
        slot = index
        depth = liftedDepth
    }

    /// The drag once the finger is at the point. Over the slot the slot stays, so that it does not flicker under the
    /// finger, the slot being taller than a row; over a row it goes before that row in the row's upper half and after
    /// it in the lower; above the first row it goes to the top, and below the last to the end. Only the rows laid out
    /// report frames, so the rule counts no rows and holds in a lazy stack (spike #145).
    private func moved(
        to point: CGPoint, among items: [ListsTreeItem], frames: [ListsTreeItem.ID: CGRect]
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
            let levels = Int(((point.x - start.x) / ListRowView.indent).rounded())
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
    /// finds rows by. Kept in a class that nothing observes and held in the screen's state, so that a layout pass that
    /// reports them does not draw the screen again (spike #145).
    @MainActor
    final class ItemFrames {
        var byID: [ListsTreeItem.ID: CGRect] = [:]
    }

    /// How each item of the tree reports its frame: every item laid out puts its own into the preference, and the
    /// screen keeps the whole of what the last layout reported.
    struct ItemFramesKey: PreferenceKey {
        static let defaultValue: [ListsTreeItem.ID: CGRect] = [:]

        static func reduce(value: inout [ListsTreeItem.ID: CGRect], nextValue: () -> [ListsTreeItem.ID: CGRect]) {
            value.merge(nextValue()) { $1 }
        }
    }

    /// The slot the canvas draws while a row is lifted (`Phone.dc.html`, the slot's row): 52 pt high, 6 pt more than a
    /// row, so that it is steady under the finger, a frame dashed in the accent on the accent's soft fill, from 6 pt
    /// before the tile of its depth to 12 pt short of the right edge of the screen, with the guides of the levels the
    /// row would stand under. It is the view's own feedback and sends nothing.
    struct Slot: View {
        private static let height: CGFloat = 52

        private let depth: Int
        private let guides: [CGFloat]
        private let visibleRight: CGFloat

        init(depth: Int, guides: [CGFloat], visibleRight: CGFloat) {
            self.depth = depth
            self.guides = guides
            self.visibleRight = visibleRight
        }

        var body: some View {
            let leading = ListRowView.tileLeading(atDepth: depth) - 6
            let shape = RoundedRectangle(cornerRadius: 13)
            shape
                .fill(Color(.accentSoft))
                .overlay { shape.stroke(Color(.accent), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])) }
                .frame(width: max(0, visibleRight - 12 - leading), height: Self.height - 8)
                .padding(.leading, leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .frame(height: Self.height)
                .background { ListsTreeItem.Guides(guides) }
                .accessibilityHidden(true)
        }
    }

    /// The lifted row, carried under the finger (`Phone.dc.html`, the drag's card): on the surface with the canvas's
    /// large soft shadow, scaled to 1.03 on the popover's motion and tilted −1.5°. A list's card stands at the tile of
    /// the slot's depth, its tile, its title and a grip on it, 50 pt high, out to 6 pt short of the right edge of the
    /// screen; an area's is its line on a card 36 pt high across the screen. The canvas's overshoot to 1.045 and its
    /// bob have no motion of the look and are left out; with Reduce Motion the card is at its scale at once.
    struct Card: View {
        private let item: ListsTreeItem
        private let depth: Int
        private let visibleRight: CGFloat
        private let send: (TaskViewList.UserAction) -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// Whether the card has grown to its lifted scale, which it does once it appears.
        @State private var isLifted = false

        init(
            _ item: ListsTreeItem, depth: Int, visibleRight: CGFloat, send: @escaping (TaskViewList.UserAction) -> Void
        ) {
            self.item = item
            self.depth = depth
            self.visibleRight = visibleRight
            self.send = send
        }

        var body: some View {
            card
                .scaleEffect(isLifted ? 1.03 : 1)
                .rotationEffect(.degrees(-1.5))
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
                .onAppear {
                    withAnimation(reduceMotion ? nil : Animation(.popover)) { isLifted = true }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }

        /// The card of the lifted row's kind. The slot is never lifted, so its case draws nothing.
        @ViewBuilder private var card: some View {
            switch item {
            case .list(_, let list, _):
                let leading = ListRowView.tileLeading(atDepth: depth) - 2
                HStack(spacing: ListRowView.tileToTitle) {
                    ListTile(list.tile)
                    Text(list.title)
                        .font(Font(list.titleFont))
                        .foregroundStyle(Color(.ink))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ListRowView.Grip()
                        .foregroundStyle(Color(.ink2))
                        .frame(width: 40, height: 50)
                }
                .padding(.leading, 12)
                .frame(width: max(120, visibleRight - 6 - leading), height: 50)
                .background(Color(.surface), in: .rect(cornerRadius: 14))
                .offset(x: leading)
            case .area(_, let label):
                AreaLine(label: label, draft: nil, isEditing: true, send: send)
                    .frame(width: max(120, visibleRight - 16), height: 36)
                    .background(Color(.surface), in: .rect(cornerRadius: 12))
                    .offset(x: 8)
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
/// It is iOS's alone: UIKit's recognizers are unavailable on macOS and watchOS, where the screen has no drag.
struct ListsDragGesture: UIViewRepresentable {
    private let isEnabled: Bool
    private let isRowLifted: Bool
    private let onPhase: (ListsDrag.Phase) -> Void

    /// A recognizer enabled or not, scrolling near the edges while the screen says a row is lifted, which hands each
    /// stage of the press to the screen.
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

    /// The recognizer's target and delegate, which hands each stage of the press to the screen, and the scroll near the
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

        /// Starts the scroll near the edges when a row is lifted, and stops it when none is, from the screen's drag and
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
