// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListRuns.swift
import TaskListFeature

/// The list's blocks cut into runs (`ListSurface`), each run a lazy stack of its own. Every part that holds a field, a
/// row that holds one or a block's header whose list's name is being typed, starts a run and stands at its head,
/// outside the lazy stacks, laid out wherever it is, so that its field is never taken out of the window and keeps its
/// focus out of sight (spike #145); the parts after it, up to the next start, stand in the run's lazy stack. A run's
/// start, once made, is kept (`ListCuts`): the field closed, its part, a plain row or header now, starts the same run
/// as the first child of its lazy stack, and no row changes runs, where the rows of a run that ended with its field
/// joined the run before, at the far end of a stack that had measured few of its rows, and stood by estimate, a dozen
/// rows from where they were (#196). A start whose part the list no longer draws, its task deleted, checked away or
/// dropped into another block, its block folded or gone, moves to the part that followed it, its run known as before,
/// so that no row changes runs then either: an empty task the "+" made at the list's top and a tap on the background
/// deleted left its rows to the first run, which held nothing above them. It is dropped only where that part is gone
/// too, and its rows then join the run before, or starts a run already, and nothing moves. The first run has no part
/// at its head and holds the parts before the first start; until a field has opened the blocks stand whole in it. A
/// task two blocks draw is open in both, so there may be more than one field. The Done strip's rows leave their lazy
/// stack while one of them holds a field, the open card standing where its row stood there too.
struct ListRuns {
    /// A block and what of it a run holds, by the block.
    struct Piece: Identifiable {
        let block: TaskList.Model.Block
        let parts: BlockView.Parts

        var id: TaskList.Model.BlockID { block.id }
    }

    /// The part that holds a field at the run's head, which stands outside the lazy stacks, none for the first run and
    /// for a run whose field has closed, and the parts a lazy stack holds: those after the field, or from the run's
    /// start on where it has none.
    struct Run: Identifiable {
        /// What a run is known by: the part it starts at, a list's header by its block and a row by its block and its
        /// task, and the first run, which starts at none, by being first. So a field keeps its view whatever opens or
        /// closes above or below it, where a run known by its place among the runs moved it to another and made it
        /// anew, and the name being typed lost what it held to the next letter; and a card that opens leaves the run
        /// above it as it was, its lazy stack measured, where a run known by the field at its end made a new one, its
        /// rows in sight at its far end and placed by estimate, which jumped the list to its top (#196).
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

    /// A run's start as a pass drew it, which the screen keeps for the next pass (`ListCuts`): the run's id, the part
    /// it stands at, which is the part its id names until that part goes, and the part drawn after that one, a header
    /// or a row and none at the list's end, where the start moves if its own part is gone by the next pass.
    struct Start: Equatable {
        let id: Run.ID
        let part: Run.ID
        let next: Run.ID?
    }

    /// The starts of every run but the first, as this pass drew them.
    let cuts: [Start]

    /// Whether a row of the Done strip holds a field, which takes the strip's rows out of their lazy stack.
    let doneRowsHoldField: Bool

    /// The runs of the blocks drawn: a run starts at every part that holds a field, decided here, in the pass that
    /// draws it, so that a field is never first made inside a lazy stack, and wherever a start of `cuts`, those the
    /// pass before this one drew, stands now.
    init(_ blocks: [TaskList.Model.Block], doneRows: [TaskList.Model.Row], cuts: [Start]) {
        var parts: [(part: Run.ID, holdsField: Bool)] = []
        for block in blocks {
            if let header = block.header { parts.append((.header(block.id), header.field != nil)) }
            for row in block.rows {
                parts.append((.row(BlockRowID(block: block.id, task: row.id)), Self.holdsField(row)))
            }
        }
        let ids = Self.ids(of: cuts, among: parts)
        var runs: [Run] = []
        var head: (id: Run.ID, field: Piece?) = (.start, nil)
        var lazy: [Piece] = []
        func begin(_ id: Run.ID, with field: Piece?) {
            runs.append(Run(id: head.id, field: head.field, lazy: lazy))
            head = (id, field)
            lazy = []
        }
        for block in blocks {
            var header = true
            var topMark = true
            var from = 0
            if let itsHeader = block.header, let id = ids[.header(block.id)] {
                if itsHeader.field != nil {
                    let itself = BlockView.Parts(header: true, topMark: false, rows: 0..<0, add: false)
                    begin(id, with: Piece(block: block, parts: itself))
                    header = false
                } else {
                    begin(id, with: nil)
                }
            }
            for row in block.rows.indices {
                guard let id = ids[.row(BlockRowID(block: block.id, task: block.rows[row].id))] else { continue }
                let above = BlockView.Parts(header: header, topMark: topMark, rows: from..<row, add: false)
                lazy.append(Piece(block: block, parts: above))
                header = false
                topMark = false
                if Self.holdsField(block.rows[row]) {
                    let itself = BlockView.Parts(header: false, topMark: false, rows: row..<row + 1, add: false)
                    begin(id, with: Piece(block: block, parts: itself))
                    from = row + 1
                } else {
                    begin(id, with: nil)
                    from = row
                }
            }
            let rest = BlockView.Parts(header: header, topMark: topMark, rows: from..<block.rows.endIndex, add: true)
            lazy.append(Piece(block: block, parts: rest))
        }
        runs.append(Run(id: head.id, field: head.field, lazy: lazy))
        self.runs = runs
        self.cuts = parts.indices.compactMap { index in
            ids[parts[index].part].map { id in
                Start(id: id, part: parts[index].part, next: index + 1 < parts.count ? parts[index + 1].part : nil)
            }
        }
        doneRowsHoldField = doneRows.contains(where: Self.holdsField)
    }

    /// The id of the run that starts at each part, among the headers and rows drawn, in their order: a start kept
    /// stands at its part while that is drawn, and else at the part that followed it, where that is drawn and no start
    /// stands there; and a part that holds a field starts a run known by the part, or by the start that stands there
    /// already. A start that had moved, and whose id names a part that has come back and holds a field, gives the id
    /// up, so that no two runs are known alike.
    private static func ids(
        of cuts: [Start], among parts: [(part: Run.ID, holdsField: Bool)]
    ) -> [Run.ID: Run.ID] {
        let drawn = Set(parts.map(\.part))
        var ids: [Run.ID: Run.ID] = [:]
        for cut in cuts where drawn.contains(cut.part) {
            ids[cut.part] = cut.id
        }
        for cut in cuts where !drawn.contains(cut.part) {
            if let next = cut.next, drawn.contains(next), ids[next] == nil { ids[next] = cut.id }
        }
        for (part, holdsField) in parts where holdsField && ids[part] == nil {
            if let moved = ids.first(where: { $0.value == part })?.key { ids[moved] = nil }
            ids[part] = part
        }
        return ids
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

/// The parts at which a run of the list has started (`ListRuns`), which the list's view keeps from pass to pass for as
/// long as it shows the list: view state of the platform's kind, as its scroll is (`docs/style.md`, "Views"), since
/// only the view knows which lazy stack has measured which rows, and nothing of the model's. Each pass draws the runs
/// of the starts kept and of its own fields, among the parts drawn, and what it drew is kept after it, each start with
/// the part it stands at and the part after it, where it moves if its own is gone by the next pass. In a class that
/// nothing observes, as the drag's frames are (`RowDragState`), so that keeping them draws nothing again.
///
/// `ListCuts` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and Observation
/// for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-10).
@MainActor
final class ListCuts {
    var kept: [ListRuns.Start] = []
}
