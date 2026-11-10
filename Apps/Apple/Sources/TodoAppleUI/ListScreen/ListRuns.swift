// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListRuns.swift
import TaskListFeature

/// The list's blocks cut at every part that holds a field, a row that holds one or a block's header whose list's name
/// is being typed, into runs (`ListSurface`): the parts up to such a part, which stand in a lazy stack, and the part
/// itself, which stands outside the lazy stacks, laid out wherever it is, so that its field is never taken out of the
/// window and keeps its focus out of sight (spike #145). A task two blocks draw is open in both, so there may be more
/// than one. The last run ends with no field, and with no field open the blocks stand whole in one run. The Done
/// strip's rows leave their lazy stack while one of them holds a field, the open card standing where its row stood
/// there too. Internal and not private for its tests alone (`ListRunsTests`).
struct ListRuns {
    /// A block and what of it a run holds, by the block.
    struct Piece: Identifiable {
        let block: TaskList.Model.Block
        let parts: BlockView.Parts

        var id: TaskList.Model.BlockID { block.id }
    }

    /// The parts a lazy stack holds, and the part that holds a field after them, which stands outside it, none for the
    /// last run.
    struct Run: Identifiable {
        /// Its place among the runs.
        let id: Int
        let lazy: [Piece]
        let field: Piece?
    }

    let runs: [Run]

    /// Whether a row of the Done strip holds a field, which takes the strip's rows out of their lazy stack.
    let doneRowsHoldField: Bool

    init(_ blocks: [TaskList.Model.Block], doneRows: [TaskList.Model.Row]) {
        var runs: [Run] = []
        var lazy: [Piece] = []
        func standAlone(_ field: Piece) {
            runs.append(Run(id: runs.count, lazy: lazy, field: field))
            lazy = []
        }
        for block in blocks {
            var header = true
            var topMark = true
            var from = 0
            if block.header?.field != nil {
                standAlone(Piece(block: block, parts: .init(header: true, topMark: false, rows: 0..<0, add: false)))
                header = false
            }
            for row in block.rows.indices where Self.holdsField(block.rows[row]) {
                let above = BlockView.Parts(header: header, topMark: topMark, rows: from..<row, add: false)
                lazy.append(Piece(block: block, parts: above))
                let itself = BlockView.Parts(header: false, topMark: false, rows: row..<row + 1, add: false)
                standAlone(Piece(block: block, parts: itself))
                header = false
                topMark = false
                from = row + 1
            }
            let rest = BlockView.Parts(header: header, topMark: topMark, rows: from..<block.rows.endIndex, add: true)
            lazy.append(Piece(block: block, parts: rest))
        }
        runs.append(Run(id: runs.count, lazy: lazy, field: nil))
        self.runs = runs
        doneRowsHoldField = doneRows.contains(where: Self.holdsField)
    }

    /// Whether a row holds a field, by its kind, every kind deciding with no `default`, so that a kind added later
    /// decides too (`docs/style.md`, "Views").
    private static func holdsField(_ row: TaskList.Model.Row) -> Bool {
        switch row {
        case .task: false
        case .card: true
        }
    }
}
