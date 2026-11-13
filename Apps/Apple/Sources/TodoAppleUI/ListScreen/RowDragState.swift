// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowDragState.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature
#if os(iOS)
// The content and the scroll view a board settles by are UIKit's alone.
import UIKit
#endif

/// What the screen's gestures stand at now, which its blocks and rows draw from: the lift, nil while no row is lifted,
/// the row a dropped task's copy is settling onto, nil while none is, what the drag knows of the layout, the swipe, and
/// what a row's Delete sends, which leaves the swipe as it stands, since the row goes from where it stands.
///
/// `RowGestures` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct RowGestures {
    let lift: RowLift?
    let settling: BlockRowID?
    let dragState: RowDragState
    let swipe: ScreenSwipe
    let delete: (TaskList.UserAction) -> Void

    /// Whether the drag has lifted the row, the one fact of the lift a row draws.
    func isLifted(_ row: BlockRowID) -> Bool {
        lift?.task == row.task && lift?.source == row.block
    }

    /// Whether a dropped task's copy is settling onto the row, which stands hidden under it until it is there (#211).
    func isSettling(_ row: BlockRowID) -> Bool {
        settling == row
    }

    /// Sends what a row's swipe or its menu chose, on the motion that takes the row away as a done row leaves with no
    /// wait, the rows under it closing up. A swiped row goes from where it stands, aside, and its swipe ends with the
    /// motion, which brings it back where the store refused.
    @MainActor
    func sendLeaving(_ action: TaskList.UserAction, row: BlockRowID, on leaving: TaskLeavingStyle, reduceMotion: Bool) {
        guard !reduceMotion else {
            delete(action)
            swipe.rowLeft(row)
            return
        }
        withAnimation(Animation(leaving.deleteAnimation), completionCriteria: .logicallyComplete) {
            delete(action)
        } completion: { [swipe] in
            swipe.rowLeft(row)
        }
    }
}

/// What a drag and a swipe read of the layout and of the drag under way, and draw nothing from but the tint of the
/// block a drag would land in (`tint`). Kept in a class that nothing observes, that tint's frame apart, and held in the
/// screen's state, so that a layout that reports frames does not draw the screen again (spike #145).
///
/// `RowDragState` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
@MainActor
final class RowDragState {
    /// The frames the rows, blocks and columns of the layout shown last reported, each as it changed, and kept for one
    /// that has left: what reads them reads those drawn. A row, a column and its cards' area write theirs here
    /// (`reportsLiftFrame`); a part of a list's block goes through `report`, `forgetParts` and `forgetLayout` below and
    /// never straight into the frames, which would leave the tint's frame behind.
    var frames = RowLift.Frames()

    /// The frame the tint of the block a drag would land in stands at, which only the tints observe.
    let tint = BlockTintFrame()

    /// Keeps the frame a part of a list's block reported (`RowLift.Frames.report`), and the tint's where it moved its
    /// block's.
    func report(_ part: RowLift.Frames.BlockPart, of block: TaskList.Model.BlockID, _ frame: CGRect) {
        frames.report(part, of: block, frame)
        tint.follow(frames)
    }

    /// Forgets the parts the list's blocks no longer draw (`RowLift.Frames.forgetParts(notDrawnBy:)`), and moves the
    /// tint's frame where it moved its block's.
    func forgetParts(notDrawnBy blocks: [TaskList.Model.Block]) {
        frames.forgetParts(notDrawnBy: blocks)
        tint.follow(frames)
    }

    /// Forgets every frame, the layout that reported them gone, and the tint's with them: a card of the board and a
    /// row of the list are one row to the frames (`BlockRowID`), and a list's lazy stack reports only the rows it lays
    /// out, so a row not yet laid out kept its card's frame, or the one an earlier list left it, which a drag and a
    /// swipe then read as its own (#196).
    func forgetLayout() {
        frames = RowLift.Frames()
        tint.follow(frames)
    }

    /// Has the tint watch the block the slot names, at its frame as reported so far. With `report`, `forgetParts` and
    /// `forgetLayout` the one way the tint's frame is set, so that it is set from the frames it follows.
    func watch(_ slot: RowLift.Slot?) {
        tint.watch(slot, in: frames)
    }

    // iOS alone: only there does a system drag stand on the screen, and these are UIKit's.
    #if os(iOS)
    /// The drags the system's drag has begun on the screen's rows (`RowSystemDrag`).
    var sessions = RowDragSessions()

    /// The content the rows reported their frames in, and the scroll view it is drawn in (`ScrollContentFinder`).
    weak var content: UIView?
    weak var scrollView: UIScrollView?

    /// Brings the board to the nearest column's leading edge, its start or its end, where the system's scroll under a
    /// drag left it between two: that scroll knows nothing of the board's snap (spike #174). Answers how far it moves
    /// the board across, which a copy settling onto a card of it goes along with (#211).
    func settle(among blocks: [TaskList.Model.Block], inset: CGFloat, animated: Bool) -> CGFloat {
        guard let scrollView, let content else { return 0 }
        let low = -scrollView.adjustedContentInset.left
        let high = max(
            low, scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right
        )
        let columns = blocks.compactMap { frames.blocks[$0.id] }.map { frame in
            min(max(content.convert(frame, to: scrollView).minX - inset, low), high)
        }
        let current = scrollView.contentOffset.x
        guard let nearest = (columns + [low, high]).min(by: { abs($0 - current) < abs($1 - current) }),
              nearest != current
        else { return 0 }
        scrollView.setContentOffset(CGPoint(x: nearest, y: scrollView.contentOffset.y), animated: animated)
        return nearest - current
    }
    #elseif os(macOS)
    /// How large the scroll view the content stands in is, below the window's bar, and where the content's top left
    /// corner stands in it, as the sidebar reads its own (`ListsTree`'s `viewport` and `contentTop`): the one reported
    /// by the scroll view (`RowDragViewport`), the other by the content (`RowPointerDrag`).
    var viewportSize = CGSize.zero
    var contentOrigin = CGPoint.zero

    /// The part of the content in sight, in its own coordinates, its scroll view's margins included, which the
    /// pointer's drag lets go of nothing outside: none until the scroll view reports its size, so that no press lifts
    /// a row before.
    var viewport: CGRect {
        CGRect(origin: CGPoint(x: -contentOrigin.x, y: -contentOrigin.y), size: viewportSize)
    }
    #endif
}

/// The frame the tint of the block a drag would land in stands at (`BlockDropTints`): while the slot names a block
/// other than the one the task was dragged from, that block's frame, the union of its parts, which grows as the lazy
/// stack lays them out during the drag, the auto-scroll's among them, as the block's own overlay covered it when the
/// block was one view. The one part of the drag's state anything observes, and only the tints: it changes only where
/// that block's frame does, so a report of any other part, or of one that leaves the frame as it was, draws nothing
/// (#196).
///
/// `BlockTintFrame` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-10).
@MainActor @Observable
final class BlockTintFrame {
    /// The block the slot names, nil while it names none or a place in the block dragged from, which is not tinted.
    private var block: TaskList.Model.BlockID?

    /// That block's frame as the frames last had it.
    private var blockFrame: CGRect?

    /// The block's frame while it is the one tinted, and nil for any other, whose reader observes only which one is.
    func frame(of block: TaskList.Model.BlockID) -> CGRect? {
        self.block == block ? blockFrame : nil
    }

    /// Watches the block the slot names, among the frames reported (`RowDragState.watch`).
    fileprivate func watch(_ slot: RowLift.Slot?, in frames: RowLift.Frames) {
        let block: TaskList.Model.BlockID? = if case .into(let target)? = slot { target } else { nil }
        if self.block != block { self.block = block }
        follow(frames)
    }

    /// Follows the frame of the block watched, set only where it changed (`RowDragState.report`, `forgetParts`,
    /// `forgetLayout`).
    fileprivate func follow(_ frames: RowLift.Frames) {
        let frame = block.flatMap { frames.blocks[$0] }
        if blockFrame != frame { blockFrame = frame }
    }
}

extension RowLift {
    /// The name of the space the frames are reported in, which is the content's of the list or of the board, and the
    /// Mac's pointer is read in.
    static let contentSpace = "RowLift.content"

    #if os(macOS)
    /// The name of the space of the scroll view the content stands in, which the content's place is read in, on the
    /// Mac alone, whose pointer's drag reads what of the content is in sight.
    static let viewportSpace = "RowLift.viewport"
    #endif

    /// A stage of a screen's drag, the system's on iOS or the pointer's on the Mac: the lift it leaves, written into
    /// the screen's where it changed, and the drop it reports, sent, both on the motion the lifted task's slot moves on
    /// (`TaskLiftStyle.slotAnimation`), so that the mark goes from place to place and the rows open and close its gap
    /// and close up at the drop on it, or at once where a person asked for less motion (#211); and whether it put a
    /// lift down.
    @MainActor @discardableResult
    static func step(
        _ phase: Phase, of lift: Binding<RowLift?>, among blocks: [TaskList.Model.Block], frames: Frames,
        reduceMotion: Bool, send: (TaskList.UserAction) -> Void
    ) -> Bool {
        let current = lift.wrappedValue
        let step = after(phase, from: current, among: blocks, frames: frames)
        let style = (step.lift ?? current)?.style(among: blocks)
        withAnimation(reduceMotion ? nil : style.map { Animation($0.slotAnimation) }) {
            if step.lift != current { lift.wrappedValue = step.lift }
            if let drop = step.drop { send(drop) }
        }
        return current != nil && step.lift == nil
    }

    /// How the lifted task looks lifted, by its row among the blocks drawn, and nil where that row is drawn no longer
    /// or has no lift.
    private func style(among blocks: [TaskList.Model.Block]) -> TaskLiftStyle? {
        BlockRowID(block: source, task: task).rowModel(among: blocks)?.style.lift
    }
}

extension View {
    /// Reports this view's frame in the content's space into a table of the screen's frames, as it changes, which reads
    /// true while a column scrolls under its rows, by `onGeometryChange` and not a preference: measured in a release
    /// build, the swipe's frames took half as long, with the lift and the scroll no different (fix round 1 of #177).
    @MainActor
    func reportsLiftFrame<Key: Hashable & Sendable>(
        _ table: WritableKeyPath<RowLift.Frames, [Key: CGRect]> & Sendable, _ key: Key, to dragState: RowDragState
    ) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(RowLift.contentSpace)) } action: { frame in
            dragState.frames[keyPath: table][key] = frame
        }
    }
}

/// The content of the list or of the board as the space a drag finds its place in, which its rows report their frames
/// in, and on iOS what only UIKit gives it (`ScrollContentFinder`), on the Mac the pointer's drag over it
/// (`RowPointerDrag`), which reads the pointer in that space and so stands inside it.
struct RowDragContent: ViewModifier {
    private let dragState: RowDragState
    #if os(iOS)
    private let finder: ScrollContentFinder
    #elseif os(macOS)
    private let pointerDrag: RowPointerDrag
    #endif

    #if os(iOS)
    init(dragState: RowDragState, finder: ScrollContentFinder) {
        self.dragState = dragState
        self.finder = finder
    }
    #elseif os(macOS)
    init(dragState: RowDragState, pointerDrag: RowPointerDrag) {
        self.dragState = dragState
        self.pointerDrag = pointerDrag
    }
    #else
    init(dragState: RowDragState) {
        self.dragState = dragState
    }
    #endif

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .modifier(pointerDrag)
            #endif
            .coordinateSpace(.named(RowLift.contentSpace))
            #if os(iOS)
            .background { finder }
            #endif
    }
}
