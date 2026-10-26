// Sources/TodoCore/Storage/Store+DeviceState.swift
import SQLiteKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A device's own UI state: what a person made on this device's screen that no other device should repeat and
/// no link addresses, such as the branches of the sidebar they folded (ADR-0010). A key is a module's own,
/// named for the module and what it keeps, and its value is a value of a `Codable` type the module names,
/// kept in `device_state` as that value's JSON, so that a module's state can grow past a list of ids without
/// the module writing a format of its own (ADR-0010, amendment of 2026-10-26).
///
/// Outside the journal, so none of it is synced or pushed: a write is a statement on the table and not an
/// operation, which is also why it reports no change set. `ChangeSet` names the data every window shows, and a
/// key that one window writes is read by another at its next reread. The table is the file's all the same,
/// so `snapshot()` carries it and a restored copy starts with what the original kept, which is harmless.
extension Store {
    /// The value kept under the key on this device, or nil when nothing is. What is in the row was written by a
    /// version of the app that may be newer, older or wrong, or by the module before it changed its type, so a
    /// value that is not text, that nests deeper than the core reads, or that does not decode as `type` reads
    /// as nothing kept too, rather than as a failure the module would meet at every open (`docs/style.md`, "A
    /// trap is a bug"). A module that changes its type loses what it kept, once.
    public func deviceState<Value: Decodable>(_ key: String, as type: Value.Type) throws(StoreError) -> Value? {
        let stored = try sql { () throws(SQLiteError) in
            try db.rows("SELECT value FROM device_state WHERE key = ?", [.text(key)]).first?.first?.string
        }
        guard let json = stored, nestingDepth(of: json) <= maximumDepth else { return nil }
        return try? JSONDecoder().decode(type, from: Data(json.utf8))
    }

    /// Keeps the value under the key as its JSON, replacing what was there; the upsert is the one `setMeta`
    /// writes. A value the store could not read back is refused here with a sentence, where it is a message
    /// about the value the module just made rather than a state that reads as nothing kept at the next open:
    /// one the encoder refuses, such as a `Double` that is not a number, and one that nests deeper than
    /// `deviceState(_:as:)` reads, the bound `Filter` holds a view's filter to on its write.
    public func setDeviceState<Value: Encodable>(_ key: String, _ value: Value) throws(StoreError) {
        let json: String
        do { json = String(decoding: try makeEncoder().encode(value), as: UTF8.self) } catch {
            throw .invalid("the device state \"\(key)\" could not be written as JSON: \(String(describing: error))")
        }
        guard nestingDepth(of: json) <= maximumDepth else {
            throw .invalid("the device state \"\(key)\" nests deeper than \(maximumDepth) levels")
        }
        try sql { () throws(SQLiteError) in
            try db.run(
                "INSERT INTO device_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                [.text(key), .text(json)]
            )
        }
    }
}
