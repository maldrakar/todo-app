// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowSystemDrag.swift
// iOS alone: the drag, the drop and the menu are UIKit's interactions, which the Mac, whose drag is its pointer's, and
// the watch do not have.
#if os(iOS)
import DesignSystemComponents
import SwiftUI
import TaskListFeature
import TodoCore
import UIKit
import UniformTypeIdentifiers

extension UTType {
    /// A task carried by the drag, which only this app reads (`TodoIOS`, which says why its Info.plist exports it).
    fileprivate static let todoTask = UTType(exportedAs: "dev.maldrakar.todo.task")
}

/// The system's drag, drop and menu of the rows of the list or of the board (#211): UIKit's three interactions on the
/// screen's scroll view, which find the row under the finger by the frames the rows reported, among the blocks drawn
/// (`RowLift.Frames.row(at:among:)`), and act only on a row whose model gives it a menu and a lift. SwiftUI's drag,
/// which they replace (spike #174, y1), let the system shrink the copy to a fraction of the row and fade it where it
/// was let go; UIKit's keeps it full size under the finger and moves it where it lands.
///
/// The menu and the drag stand on the same view and so stay paired: a still press opens the menu over the row's lifted
/// copy, and a move after the press drags. The drag carries the copy at the lift's scale, on its background and
/// corners, and plays the lift's impact as it lifts. Each call of the drop is handed to the session it names
/// (`RowDragSessions`) with its point in the content's space, and the stage that makes moves the lift on the slot's
/// motion (`RowLift.step`); the system scrolls the scroll view under the drag. Leaving the scroll view puts the lift
/// down, and a drag that comes back lifts again (spike #174); one that ends anyhow puts it down.
///
/// Let go, the copy settles (`RowLift.Settling`): the drop is sent on the slot's motion and the layout it makes read at
/// once, and the copy goes onto the row the task landed as, or back onto its own where nothing landed, turning on its
/// way into the row as its block draws it, while that row stands hidden under it (`RowGestures.isSettling`) until the
/// system's motion ends; or, where that row is out of sight or not laid out, toward the edge of what is in sight or
/// into its block's tinted area, fading as it goes. A drop that lands plays the lift's impact; one that lands nothing
/// plays none. The board, which the system's scroll left between two columns, comes to rest on one as the copy settles,
/// and the copy goes where its card will stand.
@MainActor
final class RowSystemDrag: NSObject {
    /// What the screen hands the drag at each pass: the blocks drawn, the lift and the row a copy settles onto, which
    /// it writes, the screen's gestures, the board's inset to settle by where it snaps, and what a drop sends.
    struct Screen {
        let blocks: [TaskList.Model.Block]
        let lift: Binding<RowLift?>
        let settling: Binding<BlockRowID?>
        let gestures: RowGestures
        let settleInset: CGFloat?
        let send: (TaskList.UserAction) -> Void
    }

    /// A row with a menu and a lift, as the finger found it.
    private struct Source {
        let row: BlockRowID
        let task: TaskRowModel<TaskList.UserAction>
        let menu: MenuModel<TaskList.UserAction>
        let lift: TaskLiftStyle
        let frame: CGRect
    }

    /// The drag's item as this process alone sees it: the row it carries and its session's token, which the drop reads.
    private struct Item {
        let row: BlockRowID
        let session: String
    }

    private var screen: Screen?

    /// The environment the screen is drawn in, which the copies are drawn in as well.
    private var environment = EnvironmentValues()

    private weak var scrollView: UIScrollView?

    private lazy var drag: UIDragInteraction = {
        let drag = UIDragInteraction(delegate: self)
        // Off by default on the iPhone.
        drag.isEnabled = true
        return drag
    }()

    private lazy var drop = UIDropInteraction(delegate: self)
    private lazy var menu = UIContextMenuInteraction(delegate: self)

    /// The row let go, as it stood before its drop, and where its copy goes, from the drop to the system's asking for
    /// its preview.
    private var dropped: (source: Source, settling: RowLift.Settling?)?

    /// How far the board will still move across once it settles, from the drop to the preview's target, whose place in
    /// the window is read before the board has moved.
    private var boardShift: CGFloat = 0

    /// The copy fading on its way toward a point, which fades with the system's motion.
    private var fadingCopy: UIView?

    /// The row the menu stands on, from the menu's configuration to its end.
    private var menuRow: Source?

    /// The impact the drag under way plays, made ready as it begins.
    private var impact: UIImpactFeedbackGenerator?

    func update(_ screen: Screen, environment: EnvironmentValues) {
        self.screen = screen
        self.environment = environment
    }

    /// Stands the interactions on the scroll view, and takes them off the one they stood on.
    func install(on scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }
        uninstall()
        scrollView.addInteraction(menu)
        scrollView.addInteraction(drag)
        scrollView.addInteraction(drop)
        self.scrollView = scrollView
    }

    func uninstall() {
        guard let scrollView else { return }
        scrollView.removeInteraction(menu)
        scrollView.removeInteraction(drag)
        scrollView.removeInteraction(drop)
        self.scrollView = nil
    }

    private var dragState: RowDragState? { screen?.gestures.dragState }
    private var content: UIView? { dragState?.content }
    private var reduceMotion: Bool { environment.accessibilityReduceMotion }

    /// The row with a menu and a lift whose frame holds the point of the content.
    private func source(at point: CGPoint) -> Source? {
        guard let screen, let frames = dragState?.frames, let row = frames.row(at: point, among: screen.blocks) else {
            return nil
        }
        return source(of: row)
    }

    private func source(of row: BlockRowID) -> Source? {
        guard let drawn = drawn(row), let menu = drawn.task.menu, let lift = drawn.task.style.lift else { return nil }
        return Source(row: row, task: drawn.task, menu: menu, lift: lift, frame: drawn.frame)
    }

    /// A task's row as the blocks drawn have it, and its frame, nil where either is missing.
    private func drawn(_ row: BlockRowID) -> (task: TaskRowModel<TaskList.UserAction>, frame: CGRect)? {
        guard let screen, let frame = dragState?.frames.rows[row], let task = row.rowModel(among: screen.blocks) else {
            return nil
        }
        return (task, frame)
    }

    // MARK: - Copies

    /// The view drawn, at the size given, as a picture in the screen's environment: a hosting controller made for a
    /// drag's preview drew nothing in time, and a picture is what the system shows of a preview anyway.
    private func picture(of view: some View, size: CGSize) -> UIImageView? {
        let renderer = ImageRenderer(
            content: view
                .environment(\.colorScheme, environment.colorScheme)
                .environment(\.dynamicTypeSize, environment.dynamicTypeSize)
                .environment(\.legibilityWeight, environment.legibilityWeight)
                .environment(\.layoutDirection, environment.layoutDirection)
                .environment(\.locale, environment.locale)
        )
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = environment.displayScale
        guard let image = renderer.uiImage else { return nil }
        let picture = UIImageView(image: image)
        picture.frame = CGRect(origin: .zero, size: image.size)
        return picture
    }

    /// The row's lifted copy, grown to its lift's scale, on the lift's background and corners.
    private func liftedCopy(of source: Source) -> (view: UIView, parameters: UIPreviewParameters)? {
        guard let dragState else { return nil }
        let scale = source.lift.scale
        let size = CGSize(width: source.frame.width * scale, height: source.frame.height * scale)
        let copy = RowDragCopy(task: source.task, lift: source.lift, row: source.row, dragState: dragState)
            .frame(width: source.frame.width, height: source.frame.height)
            .scaleEffect(scale)
            .frame(width: size.width, height: size.height)
        guard let view = picture(of: copy, size: size) else { return nil }
        let parameters = UIPreviewParameters()
        parameters.visiblePath = UIBezierPath(roundedRect: view.bounds, cornerRadius: source.lift.cornerRadius * scale)
        return (view, parameters)
    }

    /// The row as its block draws it, which the copy turns into as it settles onto it: with nothing under it but what
    /// the row itself stands on, a column's card's surface, and within its own corners.
    private func settledCopy(of row: BlockRowID) -> (view: UIView, parameters: UIDragPreviewParameters)? {
        guard let drawn = drawn(row) else { return nil }
        let column = screen?.blocks.first { $0.id == row.block }?.column?.style
        let face = RowFace(drawn.task, column: column, send: { _ in })
            .frame(width: drawn.frame.width, height: drawn.frame.height)
        guard let view = picture(of: face, size: drawn.frame.size) else { return nil }
        let parameters = UIDragPreviewParameters()
        parameters.visiblePath = UIBezierPath(roundedRect: view.bounds, cornerRadius: drawn.task.style.cornerRadius)
        parameters.backgroundColor = .clear
        return (view, parameters)
    }

    private func dragParameters(_ parameters: UIPreviewParameters) -> UIDragPreviewParameters {
        let drag = UIDragPreviewParameters()
        drag.visiblePath = parameters.visiblePath
        return drag
    }

    /// Where a point of the content stands in its window once the board has settled.
    private func target(at point: CGPoint) -> UIDragPreviewTarget? {
        guard let content, let window = content.window else { return nil }
        let place = content.convert(point, to: window)
        return UIDragPreviewTarget(container: window, center: CGPoint(x: place.x - boardShift, y: place.y))
    }

    /// The part of the content in sight once the board has settled, in the content's own coordinates.
    private func sight() -> CGRect? {
        guard let content, let scrollView else { return nil }
        return content.convert(scrollView.bounds, from: scrollView).offsetBy(dx: boardShift, dy: 0)
    }

    /// The preview of a copy settling as the settling says: onto its row, turned into the row, or toward a point,
    /// lifted and fading; nil where it has nowhere to go.
    private func preview(settling: RowLift.Settling?, from source: Source) -> UITargetedDragPreview? {
        switch settling {
        case .onto(let row, let frame)?:
            guard let copy = settledCopy(of: row), let target = target(at: CGPoint(x: frame.midX, y: frame.midY))
            else { return nil }
            return UITargetedDragPreview(view: copy.view, parameters: copy.parameters, target: target)
        case .toward(let point)?:
            guard let copy = liftedCopy(of: source), let target = target(at: point) else { return nil }
            fadingCopy = copy.view
            return UITargetedDragPreview(view: copy.view, parameters: dragParameters(copy.parameters), target: target)
        case nil:
            return nil
        }
    }

    /// Fades the copy going toward a point with the system's motion, and shows the row a copy settled onto once it
    /// ends.
    private func settle(with animator: UIDragAnimating, onto row: BlockRowID?) {
        if let fadingCopy {
            animator.addAnimations { fadingCopy.alpha = 0 }
        }
        animator.addCompletion { [weak self] _ in
            guard let self else { return }
            fadingCopy = nil
            boardShift = 0
            if let row, let settling = screen?.settling, settling.wrappedValue == row { settling.wrappedValue = nil }
        }
    }

    // MARK: - The drag's stages

    private func session(of drop: UIDropSession) -> String? {
        (drop.items.first?.localObject as? Item)?.session
    }

    /// Whether the drop is the drag this screen's lift stands for.
    private func isLifting(_ session: UIDropSession) -> Bool {
        guard let lift = screen?.lift.wrappedValue else { return false }
        return lift.session == self.session(of: session)
    }

    /// Hands a call of the drop to the session it names, where it means a stage, and makes that stage.
    private func hear(_ call: RowDragSessions.Call, _ session: UIDropSession) {
        guard let screen, let dragState,
              let phase = dragState.sessions.phase(
                  for: call, session: self.session(of: session), lift: screen.lift.wrappedValue
              )
        else { return }
        step(phase)
    }

    /// A stage of the drag: the lift it leaves and the drop it reports (`RowLift.step`), the swipe closed while a row
    /// is lifted, and, where it ended a lift, the board brought to rest on a column; and how far across that moves it.
    @discardableResult
    private func step(_ phase: RowLift.Phase) -> CGFloat {
        guard let screen, let dragState else { return 0 }
        let hasEnded = RowLift.step(
            phase, of: screen.lift, among: screen.blocks, frames: dragState.frames, reduceMotion: reduceMotion,
            send: screen.send
        )
        if screen.lift.wrappedValue != nil { screen.gestures.swipe.close() }
        guard hasEnded, let inset = screen.settleInset else { return 0 }
        return dragState.settle(among: screen.blocks, inset: inset, animated: !reduceMotion)
    }

    private func point(of session: UIDropSession) -> CGPoint? {
        content.map(session.location(in:))
    }
}

extension RowSystemDrag: UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        guard let dragState, let content, let source = source(at: session.location(in: content)) else { return [] }
        let token = dragState.sessions.begin(source.row)
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.todoTask.identifier, visibility: .ownProcess) {
            done in
            done(Data(source.row.task.rawValue.utf8), nil)
            return nil
        }
        let item = UIDragItem(itemProvider: provider)
        item.localObject = Item(row: source.row, session: token)
        let impact = UIImpactFeedbackGenerator(style: .init(source.lift.impact))
        impact.prepare()
        self.impact = impact
        return [item]
    }

    func dragInteraction(
        _ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession
    ) -> UITargetedDragPreview? {
        guard let row = (item.localObject as? Item)?.row, let source = source(of: row),
              let copy = liftedCopy(of: source), let content
        else { return nil }
        let center = CGPoint(x: source.frame.midX, y: source.frame.midY)
        let target = UIDragPreviewTarget(container: content, center: center)
        return UITargetedDragPreview(view: copy.view, parameters: dragParameters(copy.parameters), target: target)
    }

    func dragInteraction(
        _ interaction: UIDragInteraction, willAnimateLiftWith animator: UIDragAnimating, session: UIDragSession
    ) {
        impact?.impactOccurred()
    }

    /// Full size, as a reorder's copy is: the system would shrink it otherwise.
    func dragInteraction(_ interaction: UIDragInteraction, prefersFullSizePreviewsFor session: UIDragSession) -> Bool {
        true
    }

    func dragInteraction(_ interaction: UIDragInteraction, sessionAllowsMoveOperation session: UIDragSession) -> Bool {
        true
    }

    func dragInteraction(
        _ interaction: UIDragInteraction, sessionIsRestrictedToDraggingApplication session: UIDragSession
    ) -> Bool {
        true
    }

    /// Let go where no drop takes it, outside the scroll view, the copy goes back onto the row it was dragged from.
    func dragInteraction(
        _ interaction: UIDragInteraction, previewForCancelling item: UIDragItem,
        withDefault defaultPreview: UITargetedDragPreview
    ) -> UITargetedDragPreview? {
        guard let screen, let dragState, let row = (item.localObject as? Item)?.row, let source = source(of: row),
              let sight = sight()
        else { return defaultPreview }
        let settling = RowLift.settling(onto: row, among: screen.blocks, frames: dragState.frames, inSight: sight)
        guard let preview = preview(settling: settling, from: source) else { return defaultPreview }
        if case .onto = settling { screen.settling.wrappedValue = row }
        return preview
    }

    func dragInteraction(
        _ interaction: UIDragInteraction, item: UIDragItem, willAnimateCancelWith animator: UIDragAnimating
    ) {
        settle(with: animator, onto: (item.localObject as? Item)?.row)
    }

    /// The drag is over, dropped or not: its lift, where it still stands, is put down, as when it leaves the scroll
    /// view, and its session forgotten. Another drag's lift and session stay: one may have begun while the system still
    /// settled this one's copy, which it does for about a second after the drop (the iOS 26.3 simulator, 2026-11-13).
    func dragInteraction(
        _ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation
    ) {
        guard let screen, let dragState, let token = (session.items.first?.localObject as? Item)?.session else {
            return
        }
        if let phase = dragState.sessions.phase(for: .left, session: token, lift: screen.lift.wrappedValue) {
            step(phase)
        }
        dragState.sessions.forget(token)
    }
}

extension RowSystemDrag: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        session.hasItemsConforming(toTypeIdentifiers: [UTType.todoTask.identifier])
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
        if let point = point(of: session) { hear(.moved(point), session) }
    }

    /// A move for the drag the lift stands for, never `.forbidden`, over a block that takes no drop either: a release
    /// under it left the lift standing, by what the board showed (the iOS 26.3 simulator, 2026-11-07), and the release
    /// reports no drop there by itself, having no slot. Any other drag, another window's or a second finger's, is
    /// cancelled here, so that its copy goes back to its own row.
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        if let point = point(of: session) { hear(.moved(point), session) }
        return UIDropProposal(operation: isLifting(session) ? .move : .cancel)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        hear(.left, session)
    }

    /// The drop: the slot read at the point let go, the impact played where it lands, the row it settles onto hidden,
    /// the drop sent on the slot's motion and the board settled, and where the copy goes read from the layout the drop
    /// makes, which laying the window out now gives at once (the iOS 26.3 simulator, 2026-11-13). The frame that row
    /// kept from before it left its block, if it did, is forgotten first, so that a row the drop does not lay out is
    /// not settled onto where it stood then.
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        if let point = point(of: session) { hear(.moved(point), session) }
        guard let screen, let dragState, let released = screen.lift.wrappedValue,
              let phase = dragState.sessions.phase(for: .released, session: self.session(of: session), lift: released),
              let source = source(of: BlockRowID(block: released.source, task: released.task))
        else { return }
        if released.slot != nil { impact?.impactOccurred() }
        let row = BlockRowID(block: released.slot?.block ?? released.source, task: released.task)
        dragState.frames.forgetRow(row, notDrawnBy: screen.blocks)
        screen.settling.wrappedValue = row
        let before = scrollView?.contentOffset.x ?? 0
        let shift = step(phase)
        dragState.sessions.forget()
        scrollView?.window?.layoutIfNeeded()
        // The board's move ahead, as much of it as is still to come: none where it moved at once.
        boardShift = before + shift - (scrollView?.contentOffset.x ?? 0)
        let settling = sight().flatMap { sight in
            released.settling(among: screen.blocks, frames: dragState.frames, inSight: sight)
        }
        dropped = (source, settling)
        if case .onto? = settling { return }
        screen.settling.wrappedValue = nil
    }

    func dropInteraction(
        _ interaction: UIDropInteraction, previewForDropping item: UIDragItem,
        withDefault defaultPreview: UITargetedDragPreview
    ) -> UITargetedDragPreview? {
        defer { dropped = nil }
        guard let dropped else { return defaultPreview }
        return preview(settling: dropped.settling, from: dropped.source) ?? defaultPreview
    }

    func dropInteraction(
        _ interaction: UIDropInteraction, item: UIDragItem, willAnimateDropWith animator: UIDragAnimating
    ) {
        settle(with: animator, onto: screen?.settling.wrappedValue)
    }
}

extension RowSystemDrag: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let content, let view = interaction.view, let source = source(at: view.convert(location, to: content))
        else { return nil }
        menuRow = source
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(source.menu) { action in self?.sendFromMenu(action, of: source) }
        }
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, configuration: UIContextMenuConfiguration,
        highlightPreviewForItemWithIdentifier identifier: any NSCopying
    ) -> UITargetedPreview? {
        menuPreview()
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, configuration: UIContextMenuConfiguration,
        dismissalPreviewForItemWithIdentifier identifier: any NSCopying
    ) -> UITargetedPreview? {
        menuPreview()
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        animator?.addCompletion { [weak self] in self?.menuRow = nil }
    }

    /// The row's lifted copy, over the row, which the menu stands over as the drag would carry it.
    private func menuPreview() -> UITargetedPreview? {
        guard let menuRow, let content, let copy = liftedCopy(of: menuRow) else { return nil }
        let target = UIPreviewTarget(container: content, center: CGPoint(x: menuRow.frame.midX, y: menuRow.frame.midY))
        return UITargetedPreview(view: copy.view, parameters: copy.parameters, target: target)
    }

    /// What an item of the row's menu chose, sent on the motion that takes the row away (`RowGestures.sendLeaving`).
    private func sendFromMenu(_ action: TaskList.UserAction, of source: Source) {
        screen?.gestures.sendLeaving(
            action, row: source.row, on: source.task.style.leaving, reduceMotion: reduceMotion
        )
    }
}
#endif
