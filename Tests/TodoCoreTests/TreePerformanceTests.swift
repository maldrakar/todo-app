import Testing
@testable import TodoCore
@testable import SQLiteKit

/// Tasks straight into the state table, which is how a store that has been synced into arrives: `apply` is
/// what the tests below measure, so seeding through it would hide the thing being measured in its own setup.
private func seedTasks(_ store: Store, count: Int, chain: Bool) throws(StoreError) {
    try store.sql { () throws(SQLiteError) in
        try store.db.transaction { () throws(SQLiteError) in
            let insert = try store.db.prepare("INSERT INTO tasks (id, parent, trashed, deleted) VALUES (?, ?, 0, 0)")
            for i in 0..<count {
                let parent: Value = i == 0 ? .null : .text("t\(chain ? i - 1 : (i - 1) / 2)")
                try insert.bind([.text("t\(i)"), parent])
                _ = try insert.step()
            }
        }
    }
}

/// Counts every row written to `task_tree`, in SQLite rather than in Swift, so the count is the same on every
/// machine and in every build. Nothing in the module knows these triggers exist.
private func countTreeWrites(_ store: Store) throws(StoreError) {
    try store.sql { () throws(SQLiteError) in
        try store.db.execute("""
            CREATE TABLE tree_writes (n INTEGER NOT NULL);
            INSERT INTO tree_writes (n) VALUES (0);
            CREATE TRIGGER tree_wi AFTER INSERT ON task_tree BEGIN UPDATE tree_writes SET n = n + 1; END;
            CREATE TRIGGER tree_wu AFTER UPDATE ON task_tree BEGIN UPDATE tree_writes SET n = n + 1; END;
            CREATE TRIGGER tree_wd AFTER DELETE ON task_tree BEGIN UPDATE tree_writes SET n = n + 1; END;
            """)
    }
}

private func treeWrites(_ store: Store) throws(StoreError) -> Int64 {
    try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT n FROM tree_writes").first?.first?.int64 ?? -1
    }
}

private func resetTreeWrites(_ store: Store) throws(StoreError) {
    try store.sql { () throws(SQLiteError) in try store.db.run("UPDATE tree_writes SET n = 0") }
}

@Test func movingOneTaskAmongTenThousandWritesOnlyTheRowsThatMoved() throws {
    let store = try makeStore()
    try seedTasks(store, count: 10_000, chain: false)
    try store.rebuildTree()
    try countTreeWrites(store)
    try resetTreeWrites(store)

    try store.apply([store.op(.task, "t9999", "parent", .text("t0"), HLC(millis: 9_000_000, counter: 0))])

    // One row moved, so one row is written. Emptying the table and writing it back would be 20,000.
    #expect(try treeWrites(store) == 1)
}

@Test func trashingOneTaskAmongTenThousandWritesItsSubtreeAndNothingElse() throws {
    let store = try makeStore()
    try seedTasks(store, count: 10_000, chain: false)
    try store.rebuildTree()
    try countTreeWrites(store)
    try resetTreeWrites(store)

    // t1 heads one half of the tree, so trashing it flips a large subtree \u2014 the case the difference cannot
    // make cheap, and the one that has to stay correct rather than cheap.
    try store.apply([store.op(.task, "t1", "trashed", Value(true), HLC(millis: 9_000_001, counter: 0))])

    let trashed = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT count(*) FROM task_tree WHERE trashed = 1").first?.first?.int64 ?? -1
    }
    #expect(trashed > 1_000 && trashed < 10_000, "a subtree, not the whole table and not a handful")
    #expect(try treeWrites(store) == trashed, "every row that flipped is written, and no row that did not")
}

/// A wall clock says nothing under an interpreter, so this one is the host's. It is not a budget for the
/// rebuild \u2014 it is two orders of magnitude above what the rebuild costs \u2014 but a chain this deep is the shape
/// that separates a linear pass from one that walks the ancestors of every node, which took seconds here.
#if !arch(wasm32)
@Test func rebuildingATenThousandDeepChainStaysLinear() throws {
    let store = try makeStore()
    try seedTasks(store, count: 10_000, chain: true)
    let clock = ContinuousClock()
    let start = clock.now
    try store.rebuildTree()
    let elapsed = start.duration(to: clock.now)
    #expect(elapsed < .seconds(5), "a rebuild of the worst shape took \(elapsed)")
}
#endif
