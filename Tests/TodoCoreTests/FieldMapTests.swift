import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

/// Columns that exist in a state table but are never written by an operation: the row id, the entity id, the
/// two halves of a pair key, and the stamp `applyToState` derives rather than journals.
private let notJournalFields: Set<String> = ["rid", "id", "task_id", "tag_id", "view_id", "updated_at"]

/// `FieldMap` restates what the DDL in `Schema` says, and the two drift apart expensively in both directions: a
/// column the schema leaves nullable but the map calls NOT NULL drops every operation for it, and one the
/// schema keeps NOT NULL but the map calls nullable fails the statement and rolls back the batch it arrived in.
/// This is the test that keeps them honest, so that the second list can stay a list.
@Test func everyColumnOfEveryStateTableIsTheJournalFieldTheMapClaimsItIs() throws {
    let store = try makeStore()
    for kind in EntityKind.allCases {
        let table = FieldMap.table(kind)
        let columns = try store.sql { () throws(SQLiteError) in try store.db.rows("PRAGMA table_info(\(table))") }
        #expect(!columns.isEmpty, "\(table) has no columns, so the table name in FieldMap is wrong")
        var seen: Set<String> = []
        for column in columns {
            guard let name = column[1].string, !notJournalFields.contains(name) else { continue }
            seen.insert(name)
            let acceptsNull = (column[3].int64 ?? 0) == 0
            #expect(FieldMap.isKnown(kind, name), "\(table).\(name) is a column that no operation can write")
            #expect(FieldMap.acceptsNull(kind, name) == acceptsNull, "\(table).\(name): FieldMap and the schema disagree about null")
        }
        #expect(FieldMap.known[kind] == seen, "\(table): FieldMap claims fields the schema does not have")
        #expect(FieldMap.nullable[kind]?.isSubset(of: seen) == true, "\(table): FieldMap allows a null in a column that is not there")
    }
}
