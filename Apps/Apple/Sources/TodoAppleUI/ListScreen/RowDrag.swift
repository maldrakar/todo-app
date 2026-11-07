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

    /// How wide the row stands, which the drag's copy is drawn at: alone, it would stand as wide as its title on one
    /// line.
    @State private var width: CGFloat = 0

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
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .onDrag {
                    gestures.space.carried = row
                    return itemProvider(of: row.task)
                } preview: {
                    TaskRowView(task) { _ in }
                        .frame(width: width)
                        .background(
                            Color(lift.background), in: .rect(cornerRadius: lift.cornerRadius, style: .circular)
                        )
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

/// The drag's item: the task's id in the private type, seen by this process alone. The drop reads what `onDrag` said
/// and not this; the system asks for an item with something to give.
private func itemProvider(of task: TaskID) -> NSItemProvider {
    let provider = NSItemProvider()
    let type = UTType.todoTask.identifier
    provider.registerDataRepresentation(forTypeIdentifier: type, visibility: .ownProcess) { done in
        done(Data(task.rawValue.utf8), nil)
        return nil
    }
    return provider
}

/// The drop's side of the system's drag, which stands on the screen's `ScrollView`s, hands each stage to `RowLift` in
/// the content's space and sends what it reports. Leaving the scroll view clears the lift, and a drag that comes back
/// lifts again (spike #174).
private struct RowDropDelegate: DropDelegate {
    let space: RowDragSpace
    let lift: () -> RowLift?
    let step: (RowLift.Phase) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.todoTask])
    }

    func dropEntered(info: DropInfo) {
        moved(to: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        moved(to: info.location)
        // Never `.forbidden`, over a block that takes no drop either: a release under it calls nothing here, not even
        // `dropExited`, and the lift would stay, the row dimmed (the iOS 26.3 simulator, 2026-11-07). The release reports
        // no drop there by itself, having no slot.
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        step(.cancelled)
    }

    func performDrop(info: DropInfo) -> Bool {
        moved(to: info.location)
        let drops = lift()?.slot != nil
        step(.ended)
        space.carried = nil
        return drops
    }

    private func moved(to location: CGPoint) {
        space.lastHeard = .now
        let point = space.contentPoint(fromDrop: location)
        guard let carried = space.carried else { return }
        if let lift = lift(), lift.task == carried.task, lift.source == carried.block {
            step(.changed(point))
        } else {
            step(.began(task: carried.task, block: carried.block, at: point))
        }
    }
}
#endif

/// A `ScrollView` of the list or the board as the target of the system's drag (spike #174, y1): on the scroll view, its
/// margins included, and not on its content, and with the screen's content going down under the home indicator
/// (`ListScreen`), since a release in that inset cancelled. The system scrolls the scroll views under the drag, so it has
/// no display link. A board that snaps comes to rest on a column when the lift ends. iOS alone: the Mac's pointer drag is
/// another task's, and the watch has neither.
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
                delegate: RowDropDelegate(space: gestures.space, lift: { lift }, step: step)
            )
            .task(id: lift != nil) {
                if lift != nil { await cancelOnSilence() }
            }
        #else
        content
        #endif
    }

    #if os(iOS)
    /// Ends a lift no call ends. The system calls the delegate every frame for as long as a drag stands over the target,
    /// moving or not, and a drag can end with no call at all: let go at the very edge of the screen, neither
    /// `performDrop` nor `dropExited` came, and the card stayed dimmed (the iOS 26.3 simulator, 2026-11-07). SwiftUI has
    /// no end of a drag before iOS 26. A silence that was only a slow frame costs nothing: the next call lifts again.
    private func cancelOnSilence() async {
        let silence = Duration.milliseconds(250)
        while !Task.isCancelled {
            try? await Task.sleep(for: silence)
            if !Task.isCancelled, ContinuousClock.now - gestures.space.lastHeard >= silence {
                step(.cancelled)
                return
            }
        }
    }

    private func step(_ phase: RowLift.Phase) {
        let step = RowLift.after(phase, from: lift, among: blocks, frames: gestures.space.frames)
        if case .began = phase { gestures.swipe.current = nil }
        if step.lift != lift { lift = step.lift }
        if let drop = step.drop { send(drop) }
        if step.lift == nil, let settleInset {
            gestures.space.settle(inset: settleInset, animated: !reduceMotion)
        }
    }
    #endif
}
