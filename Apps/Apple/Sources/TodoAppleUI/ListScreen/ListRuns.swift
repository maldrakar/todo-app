// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListRuns.swift
import TaskListFeature

/// The list's blocks cut at every part that holds a field, a row that holds one or a block's header whose list's name
/// is being typed, into runs (`ListSurface`): the part itself, which stands outside the lazy stacks, laid out wherever
/// it is, so that its field is never taken out of the window and keeps its focus out of sight (spike #145), and the
/// parts after it, up to the next, which stand in a lazy stack. The first run has no such part at its head and holds
/// the parts before the first; with no field open the blocks stand whole in it. A task two blocks draw is open in both,
/// so there may be more than one. The Done strip's rows leave their lazy stack while one of them holds a field, the
/// open card standing where its row stood there too. Internal and not private for its tests alone (`ListRunsTests`).
struct ListRuns {
    /// A block and what of it a run holds, by the block.
    struct Piece: Identifiable {
        let block: TaskList.Model.Block
        let parts: BlockView.Parts

        var id: TaskList.Model.BlockID { block.id }
    }

    /// The part that holds a field at the run's head, which stands outside the lazy stacks, none for the first run, and
    /// the parts after it that a lazy stack holds.
    struct Run: Identifiable {
        /// What a run is known by: the part that holds the field at its head, a list's header by its block and a row by
        /// its block and its task, and the first run, which has none, by being first. So a field keeps its view
        /// whatever opens or closes above or below it, where a run known by its place among the runs moved it to
        /// another and made it anew, and the name being typed lost what it held to the next letter; and a card that
        /// opens leaves the run above it as it was, its lazy stack measured, where a run known by the field at its end
        /// made a new one, its rows in sight at its far end and placed by estimate, which jumped the list to its top
        /// (#196).
        enum ID: Hashable {
            case start
            case header(TaskList.Model.BlockID)
            case row(BlockRowID)
        }

        let id: ID
        let field: Piece?
        let lazy: [Piece]
    }

    let runs: [Run]

    /// Whether a row of the Done strip holds a field, which takes the strip's rows out of their lazy stack.
    let doneRowsHoldField: Bool

    init(_ blocks: [TaskList.Model.Block], doneRows: [TaskList.Model.Row]) {
        var runs: [Run] = []
        var head: (id: Run.ID, field: Piece?) = (.start, nil)
        var lazy: [Piece] = []
        func standAlone(_ field: Piece, as id: Run.ID) {
            runs.append(Run(id: head.id, field: head.field, lazy: lazy))
            head = (id, field)
            lazy = []
        }
        for block in blocks {
            var header = true
            var topMark = true
            var from = 0
            if block.header?.field != nil {
                let itself = BlockView.Parts(header: true, topMark: false, rows: 0..<0, add: false)
                standAlone(Piece(block: block, parts: itself), as: .header(block.id))
                header = false
            }
            for row in block.rows.indices where Self.holdsField(block.rows[row]) {
                let above = BlockView.Parts(header: header, topMark: topMark, rows: from..<row, add: false)
                lazy.append(Piece(block: block, parts: above))
                let itself = BlockView.Parts(header: false, topMark: false, rows: row..<row + 1, add: false)
                standAlone(
                    Piece(block: block, parts: itself), as: .row(BlockRowID(block: block.id, task: block.rows[row].id))
                )
                header = false
                topMark = false
                from = row + 1
            }
            let rest = BlockView.Parts(header: header, topMark: topMark, rows: from..<block.rows.endIndex, add: true)
            lazy.append(Piece(block: block, parts: rest))
        }
        runs.append(Run(id: head.id, field: head.field, lazy: lazy))
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
