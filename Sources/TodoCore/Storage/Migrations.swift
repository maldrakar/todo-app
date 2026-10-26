// Sources/TodoCore/Storage/Migrations.swift
import SQLiteKit

/// Ordered schema steps. A step runs once, inside one transaction with the user_version bump.
enum Migrations {
    static let steps: [(version: Int32, sql: String)] = [
        (1, Schema.version1),
        (2, Schema.version2),
        (3, Schema.version3),
        (4, Schema.version4),
        (5, Schema.version5),
    ]

    /// Applies every step above the current user_version. Returns the versions before and after.
    static func run(on db: Connection) throws(SQLiteError) -> (from: Int32, to: Int32) {
        let from = try db.userVersion()
        var current = from
        for step in steps where step.version > current {
            try db.transaction { () throws(SQLiteError) in
                try db.execute(step.sql)
                try db.setUserVersion(step.version)
            }
            current = step.version
        }
        return (from, current)
    }
}
