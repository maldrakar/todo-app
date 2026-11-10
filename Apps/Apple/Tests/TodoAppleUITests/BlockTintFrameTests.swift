import CoreGraphics
import Observation
import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// The frame the tint of the block a drag would land in is drawn at, `BlockTintFrame`: the union of that block's parts
// as the lazy stack lays them out during the drag, the auto-scroll's among them, which the tints alone observe, and
// which changes only where that union does (#196). The blocks are the ones a real `TaskList` draws (`LiftedList`).

/// Whether a change reached a reading of the tint's frame of the block, as the tints read it.
@MainActor private func invalidates(
    _ tint: BlockTintFrame, of block: TaskList.Model.BlockID, by change: () -> Void
) -> Bool {
    let flag = Flag()
    withObservationTracking { _ = tint.frame(of: block) } onChange: { flag.isSet = true }
    change()
    return flag.isSet
}

/// The tint stands at the union of the block the slot names, and follows it as its parts are laid out during the lift
/// and as the block forgets those it no longer draws; a place in the block, or no lift, has no tint.
@MainActor @Test func theTintFollowsTheBlockTheSlotNamesAsItsPartsAreLaidOut() throws {
    let list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let header = CGRect(x: 0, y: 100, width: 400, height: 44)
    let dragState = RowDragState()
    dragState.report(.header, of: house, header)
    dragState.watch(nil)
    #expect(dragState.tint.frame(of: house) == nil, "no lift")

    dragState.watch(.into(house))
    #expect(dragState.tint.frame(of: house) == header)
    #expect(dragState.tint.frame(of: office) == nil, "another block")
    dragState.report(.row(list.h1), of: house, CGRect(x: 0, y: 900, width: 400, height: 44))
    #expect(dragState.tint.frame(of: house) == CGRect(x: 0, y: 100, width: 400, height: 844), "a row laid out")
    list.toggleFold(of: house)
    dragState.forgetParts(notDrawnBy: list.blocks)
    #expect(dragState.tint.frame(of: house) == header, "its rows folded away")

    dragState.watch(.place(house, after: nil))
    #expect(dragState.tint.frame(of: house) == nil, "a place in it")
}

/// Only a change of the union of the block the slot names reaches the tints: a part reported again where it stood,
/// another block's part, and any part while the slot names no block to tint, reach nothing.
@MainActor @Test func onlyAChangeOfTheTintedBlocksUnionReachesTheTints() throws {
    let list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let row = CGRect(x: 0, y: 144, width: 400, height: 44)
    let dragState = RowDragState()
    let tint = dragState.tint
    dragState.report(.header, of: house, CGRect(x: 0, y: 100, width: 400, height: 44))
    dragState.report(.row(list.h1), of: house, row)
    dragState.watch(.into(house))

    #expect(!invalidates(tint, of: house) { dragState.report(.row(list.h1), of: house, row) }, "where it stood")
    #expect(!invalidates(tint, of: house) {
        dragState.report(.header, of: office, CGRect(x: 0, y: 228, width: 400, height: 44))
    }, "another block's")
    #expect(invalidates(tint, of: house) {
        dragState.report(.row(list.h2), of: house, CGRect(x: 0, y: 188, width: 400, height: 44))
    }, "a row laid out")

    dragState.watch(.place(house, after: nil))
    #expect(!invalidates(tint, of: house) {
        dragState.report(.add, of: house, CGRect(x: 0, y: 232, width: 400, height: 40))
    }, "no tint drawn")
}
