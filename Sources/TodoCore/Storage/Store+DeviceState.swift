// Sources/TodoCore/Storage/Store+DeviceState.swift
import SQLiteKit

/// A device's own UI state: what a person made on this device's screen that no other device should repeat and
/// no link addresses, such as the branches of the sidebar they folded (ADR-0010). It is a key and a text value
/// in `device_state`, and the store neither reads nor shapes the value: a key is a module's own, named for the
/// module and what it keeps, and the module encodes and decodes the text and keeps its format stable.
///
/// Outside the journal, so none of it is synced or pushed: a write is a statement on the table and not an
/// operation, which is also why it reports no change set. `ChangeSet` names the data every window shows, and a
/// key that one window writes is read by another at its next reread. The table is the file's all the same,
/// so `snapshot()` carries it and a restored copy starts with what the original kept, which is harmless.
extension Store {
    /// The value kept under the key on this device, or nil when nothing is. A value that is not text reads as
    /// nothing kept, since no version of this app wrote one and a module could not decode it.
    public func deviceState(_ key: String) throws(StoreError) -> String? {
        try sql { () throws(SQLiteError) in
            try db.rows("SELECT value FROM device_state WHERE key = ?", [.text(key)]).first?.first?.string
        }
    }

    /// Keeps the value under the key, replacing what was there, or takes the key away for nil: a key with no
    /// value is a row deleted, which is what the NOT NULL of the column holds the table to. The upsert is the
    /// one `setMeta` writes.
    public func setDeviceState(_ key: String, _ value: String?) throws(StoreError) {
        try sql { () throws(SQLiteError) in
            if let value {
                try db.run(
                    "INSERT INTO device_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                    [.text(key), .text(value)]
                )
            } else {
                try db.run("DELETE FROM device_state WHERE key = ?", [.text(key)])
            }
        }
    }
}
