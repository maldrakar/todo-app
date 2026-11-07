// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowDrag.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature
import TodoCore
#if os(iOS)
import UniformTypeIdentifiers
#endif

/// A row's or a column's closed card's system menu and system drag (spike #174, y1, the owner's choice), both only
/// where its model gives it a menu and a lift, which the module gives together: a still press opens the menu, and a
/// move after the press drags. While it is lifted the row it was dragged from dims to its lift's opacity on the lift's
/// motion; the dragged copy is the system's, on the lift's background and corners. Delete in the menu sends what
/// `delete` does, on its way out. The watch has no such menu, and the Mac's pointer drag is another task's.
struct RowDragSource: ViewModifier {
    private let task: TaskRowModel<TaskList.UserAction>
    private let row: BlockRowID
    private let gestures: ScreenGestures
    private let delete: (TaskList.UserAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ task: TaskRowModel<TaskList.UserAction>, row: BlockRowID, gestures: ScreenGestures,
        delete: @escaping (TaskList.UserAction) -> Void
    ) {
        self.task = task
        self.row = row
        self.gestures = gestures
        self.delete = delete
    }

    func body(content: Content) -> some View {
        if let menu = task.menu, let lift = task.style.lift {
            let isLifted = gestures.lift?.task == row.task && gestures.lift?.source == row.block
            content
                #if os(iOS)
                .contentShape(.contextMenuPreview, .rect(cornerRadius: lift.cornerRadius, style: .circular))
                #endif
                #if !os(watchOS)
                .contextMenu { MenuItems(menu, send: delete) }
                #endif
                #if os(iOS)
                .onDrag {
                    itemProvider(of: row.task, session: gestures.space.sessions.begin(row))
                } preview: {
                    RowDragCopy(task: task, lift: lift, row: row, space: gestures.space)
                }
                #endif
                // The opacity alone: over the whole row, a drop's own end of the lift carried the row to its place on
                // this motion, over the rows that had already moved (the iOS 26.3 simulator, 2026-11-07).
                .animation(reduceMotion ? nil : Animation(lift.dimAnimation)) { row in
                    row.opacity(isLifted ? lift.opacity : 1)
                }
        } else {
            content
        }
    }
}

#if os(iOS)
extension UTType {
    /// A task carried by the drag, which only this app reads (`TodoIOS`, which says why its Info.plist exports it).
    fileprivate static let todoTask = UTType(exportedAs: "dev.maldrakar.todo.task")
}

/// The system's copy of the row it drags, on the lift's background and corners, as wide as the row stands: alone it
/// would stand as wide as its title on one line. A view of its own, so that the width is read when the copy is drawn,
/// by when the row has laid out, and not when `onDrag`'s preview is asked for, with every draw of the row.
private struct RowDragCopy: View {
    let task: TaskRowModel<TaskList.UserAction>
    let lift: TaskLiftStyle
    let row: BlockRowID
    let space: RowDragSpace

    var body: some View {
        TaskRowView(task, tap: {}, send: { _ in })
            .frame(width: space.frames.rows[row]?.width)
            .background(Color(lift.background), in: .rect(cornerRadius: lift.cornerRadius, style: .circular))
    }
}

/// The drag's item: the task's id in the private type, seen by this process alone, under its session's token. The drop
/// reads the token and not the id; the system asks for an item with something to give.
private func itemProvider(of task: TaskID, session: String) -> NSItemProvider {
    let provider = NSItemProvider()
    provider.suggestedName = session
    let type = UTType.todoTask.identifier
    provider.registerDataRepresentation(forTypeIdentifier: type, visibility: .ownProcess) { done in
        done(Data(task.rawValue.utf8), nil)
        return nil
    }
    return provider
}

/// The drop's side of the system's drag, which stands on the screen's `ScrollView`s, hands each call to the session it
/// names (`RowDragSessions`) with its point in the content's space, and the stage that makes to `step`. Leaving the
/// scroll view clears the lift, and a drag that comes back lifts again (spike #174).
private struct RowDropDelegate: DropDelegate {
    let space: RowDragSpace
    let lift: () -> RowLift?
    let step: (RowLift.Phase) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.todoTask])
    }

    func dropEntered(info: DropInfo) {
        hear(.moved(space.contentPoint(fromDrop: info.location)), info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        hear(.moved(space.contentPoint(fromDrop: info.location)), info)
        // Never `.forbidden`, over a block that takes no drop either: a release under it left the lift standing, by
        // what the board showed (the iOS 26.3 simulator, 2026-11-07). The release reports no drop there by itself,
        // having no slot.
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        hear(.left, info)
    }

    func performDrop(info: DropInfo) -> Bool {
        hear(.moved(space.contentPoint(fromDrop: info.location)), info)
        guard let lift = lift(), lift.session == session(of: info) else { return false }
        hear(.released, info)
        space.sessions.forget()
        return lift.slot != nil
    }

    private func hear(_ call: RowDragSessions.Call, _ info: DropInfo) {
        space.wasHeard = true
        if let phase = space.sessions.phase(for: call, session: session(of: info), lift: lift()) { step(phase) }
    }

    private func session(of info: DropInfo) -> String? {
        info.itemProviders(for: [.todoTask]).first?.suggestedName
    }
}
#endif

/// A `ScrollView` of the list or the board as the target of the system's drag (spike #174, y1): on the scroll view, its
/// margins included, and not on its content, and with the screen's content going down under the home indicator
/// (`ListScreen`), since a release in that inset cancelled. The system scrolls the scroll views under the drag, so it
/// has no display link. A board that snaps comes to rest on a column when the lift ends. iOS alone: the Mac's pointer
/// drag is another task's, and the watch has neither.
struct RowDropTarget: ViewModifier {
    private let blocks: [TaskList.Model.Block]
    @Binding private var lift: RowLift?
    private let gestures: ScreenGestures
    private let settleInset: CGFloat?
    private let send: (TaskList.UserAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The target among the blocks drawn, with the board's inset to settle by where it snaps, and what a drop sends.
    init(
        _ blocks: [TaskList.Model.Block], lift: Binding<RowLift?>, gestures: ScreenGestures, settleInset: CGFloat?,
        send: @escaping (TaskList.UserAction) -> Void
    ) {
        self.blocks = blocks
        _lift = lift
        self.gestures = gestures
        self.settleInset = settleInset
        self.send = send
    }

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { [space = gestures.space] in
                space.dropOrigin = $0
            }
            .onDrop(
                of: [.todoTask],
                delegate: RowDropDelegate(space: gestures.space, lift: { lift }, step: { step($0) })
            )
            .task(id: lift != nil) {
                if lift != nil { await cleanUpOnSilence() }
            }
        #else
        content
        #endif
    }

    #if os(iOS)
    /// Clears a lift no call has ended. The system calls the delegate every frame for as long as a drag stands over the
    /// target, moving or not, and a drag can end with no call at all: let go at the very edge of the screen, neither
    /// `performDrop` nor `dropExited` came, and the card stayed dimmed (the iOS 26.3 simulator, 2026-11-07). SwiftUI
    /// has no end of a drag before iOS 26, and the provider `onDrag` returned is no signal, held until the next one is
    /// made (the same). So a silence only cleans up: it clears the dim, the mark and the tint, it moves no board, since
    /// a finger may still stand on it, and the session survives, so that a release after it lands by the point it
    /// reads. The quiet is counted in ticks and not measured, so that a stall of the main thread counts as one.
    private func cleanUpOnSilence() async {
        var quietTicks = 0
        while !Task.isCancelled, quietTicks < 5 {
            try? await Task.sleep(for: .milliseconds(50))
            quietTicks = gestures.space.wasHeard ? 0 : quietTicks + 1
            gestures.space.wasHeard = false
        }
        if !Task.isCancelled { step(.cancelled, settling: false) }
    }

    /// A stage of the drag: the lift it leaves, the drop it reports, and, where it ended a lift, the board brought to
    /// rest on a column.
    private func step(_ phase: RowLift.Phase, settling: Bool = true) {
        let step = RowLift.after(phase, from: lift, among: blocks, frames: gestures.space.frames)
        let hasEnded = lift != nil && step.lift == nil
        if step.lift != nil { gestures.swipe.close() }
        if step.lift != lift { lift = step.lift }
        if let drop = step.drop { send(drop) }
        if hasEnded, settling, let settleInset {
            gestures.space.settle(among: blocks, inset: settleInset, animated: !reduceMotion)
        }
    }
    #endif
}
