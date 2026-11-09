// Sources/Features/TaskList/TaskList+Drop.swift
import TodoCore

/// A row let go (spec section 6; the controller's ruling on #176, 2026-11-05): in the block it was dragged from it
/// takes that place by the manual list, and in another block it takes what that block's rule asks. The writes of a move
/// are several transactions, each a change a window rereads for; a task's writes are skipped where they change nothing,
/// which is what keeps the rereads few.
extension TaskList {
    /// Checks a drop against the model: both blocks drawn, the task a row of the one it was dragged from, the other
    /// taking a drop, a drop within one block only where it keeps the place, and `anchor` a row of it other than the
    /// task. Anything else writes nothing.
    func drop(_ id: TaskID, from source: Model.BlockID, in target: Model.BlockID, after anchor: TaskID?) {
        let drawn = TaskList.blocks(in: model.layout)
        guard let drawnSource = drawn.first(where: { $0.id == source }),
              let drawnTarget = drawn.first(where: { $0.id == target }),
              drawnSource.rows.contains(where: { $0.id == id }), drawnTarget.takesDrop,
              source != target || drawnTarget.keepsDroppedPlace,
              anchor != id, anchor.map({ anchor in drawnTarget.rows.contains { $0.id == anchor } }) != false
        else { return }
        let blocks = state.pageBlocks
        guard let from = blocks.first(where: { $0.id == source }), let to = blocks.first(where: { $0.id == target }),
              let task = from.tasks.first(where: { $0.id == id })
        else { return }
        let landed = source == target ? reorder(id, in: to, after: anchor) : move(task, from: from, to: to)
        if landed { state.fresh = id }
    }

    /// Takes its place in its own block: the task and the unpinned tasks that stand above the place, in their order,
    /// are pinned in one transaction, after the last pinned task above it or first, so that it lands where it was let
    /// go and keeps it, the manual list being the view's and applied within a group (spec section 6). The order read is
    /// the page's block's, before the tag bar's filter, so that the tasks a pick hides keep their places (the
    /// controller's ruling on #176, 2026-11-05). Answers whether it landed: a drop where the task already stood moves
    /// nothing, and so lands nothing fresh.
    private func reorder(_ id: TaskID, in block: PageBlock, after anchor: TaskID?) -> Bool {
        let order = block.tasks.map(\.id)
        let others = order.filter { $0 != id }
        let place = anchor.flatMap { others.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        guard order.firstIndex(of: id) != place else { return false }
        // The list's own manual list for its own blocks and on a group's screen, and the list inside's for its block.
        let view = switch block.id {
        case .own: state.head.view
        case .list(let view): view
        }
        return writeAndReread { () throws(StoreError) in
            let pinned = Set(try store.manualList(of: view))
            let above = others[..<place]
            let unpinned = above.filter { !pinned.contains($0) }
            let placement = above.last { pinned.contains($0) }.map(Placement.after) ?? .start
            try store.pin(tasks: unpinned + [id], in: view, at: placement)
        }
    }

    /// Takes what the target's rule asks, its day through `update(task:)`, its tags, its pin last in its manual list
    /// (spec section 6's table), and gives back the tags and the pins of the lists it was dragged out of: a list
    /// inside's, and a folder's every list's, so that it leaves the block it came from whichever of them held it. An
    /// own block gives nothing back, a day block's task leaving by its new day and an own block's by being claimed; a
    /// list whose rule reads as no edit gives nothing back; and what the target asks is not given back. A task two
    /// blocks draw leaves only the one it was dragged from, and the target's fold stays (the controller's ruling on
    /// #176, 2026-11-05). Answers whether the writes held and the page was read back.
    private func move(_ task: TodoTask, from source: PageBlock, to target: PageBlock) -> Bool {
        guard let edit = target.edit else { return false }
        let view = state.snapshot.page.view
        let ownDay: GroupBy? = if case .own(.day?) = target.id { view.groupBy } else { nil }
        let changes = edit.dayChanges(of: task, rule: target.rule, ownDay: ownDay, today: state.day.day)
        let givenBack = source.listRules.compactMap { TaskEdit.of($0, today: state.day.day, day: nil) }
        let leaving = edit.removeTags.union(givenBack.flatMap(\.addTags)).subtracting(edit.addTags)
        var unpinning = edit.unpinFrom.union(givenBack.compactMap(\.pinIn))
        if let list = edit.pinIn { unpinning.remove(list) }
        return writeAndReread(refusal: .couldNotMove) { () throws(StoreError) in
            try store.update(task: task.id, changes)
            for tag in edit.addTags.subtracting(task.tags) { try store.add(tag: tag, to: task.id) }
            for tag in leaving.intersection(task.tags) { try store.remove(tag: tag, from: task.id) }
            if let list = edit.pinIn { try store.pin(task: task.id, in: list, at: .end) }
            for list in unpinning where try store.manualList(of: list).contains(task.id) {
                try store.unpin(task: task.id, from: list)
            }
        }
    }
}
