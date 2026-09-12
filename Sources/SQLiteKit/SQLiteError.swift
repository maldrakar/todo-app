import CSQLite

/// A failed SQLite call: the result code and the message SQLite attached to it.
public struct SQLiteError: Error, Equatable, Sendable {
    public let code: Int32
    public let message: String

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }

    /// Builds the error for the last failed call on a connection.
    init(handle: OpaquePointer?, code: Int32) {
        self.code = code
        self.message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite error \(code)"
    }
}
