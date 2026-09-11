import CSQLite

/// `SQLITE_TRANSIENT` is a macro the importer drops; SQLite copies the bound bytes when it sees this sentinel.
let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// One prepared statement, finalized when the last reference goes away.
public final class Statement {
    let handle: OpaquePointer
    /// Held so the connection outlives every statement prepared on it: `sqlite3_close_v2` on a connection with
    /// unfinalized statements leaves it alive as a zombie, and stepping a statement of a zombie is undefined.
    private let connection: Connection

    private var db: OpaquePointer { connection.handle }

    init(handle: OpaquePointer, connection: Connection) {
        self.handle = handle
        self.connection = connection
    }

    deinit { sqlite3_finalize(handle) }

    public var columnCount: Int32 { sqlite3_column_count(handle) }

    /// Binds parameters 1...n in order; a shorter array leaves the rest bound to null.
    ///
    /// The statement is rewound first. `sqlite3_clear_bindings` frees the parameter buffers without checking
    /// that the statement is idle, while a statement stopped on a row still has registers pointing into them,
    /// so clearing the bindings of a busy statement would leave it reading freed memory.
    public func bind(_ values: [Value]) throws(SQLiteError) {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let rc: Int32
            switch value {
            case .null: rc = sqlite3_bind_null(handle, index)
            case .integer(let v): rc = sqlite3_bind_int64(handle, index, v)
            case .real(let v): rc = sqlite3_bind_double(handle, index, v)
            case .text(let v):
                // The length is given explicitly: a -1 length makes SQLite measure the text with `strlen`,
                // which would cut a title or a note at its first interior NUL.
                rc = sqlite3_bind_text(handle, index, v, try Self.length(of: v.utf8.count), sqliteTransient)
            case .blob(let v):
                let count = try Self.length(of: v.count)
                rc = v.withUnsafeBytes { sqlite3_bind_blob(handle, index, $0.baseAddress, count, sqliteTransient) }
            }
            if rc != SQLITE_OK { throw SQLiteError(handle: db, code: rc) }
        }
    }

    /// Returns true when a row is available, false when the statement is done.
    public func step() throws(SQLiteError) -> Bool {
        let rc = sqlite3_step(handle)
        switch rc {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw SQLiteError(handle: db, code: rc)
        }
    }

    /// Rewinds the statement so it can be bound and stepped again.
    ///
    /// `sqlite3_reset` returns the error of the most recent `step` rather than an error of the reset, and the
    /// caller already received that error from `step`, so it is not raised a second time: resetting is how a
    /// statement is recovered after a failed step, and it must not look like a failure of its own.
    public func reset() throws(SQLiteError) {
        sqlite3_reset(handle)
    }

    /// A byte count as SQLite takes it, or `SQLITE_TOOBIG` when it does not fit.
    private static func length(of count: Int) throws(SQLiteError) -> Int32 {
        guard let length = Int32(exactly: count) else {
            throw SQLiteError(code: SQLITE_TOOBIG, message: "a value of \(count) bytes does not fit in one binding")
        }
        return length
    }

    public func value(at index: Int32) -> Value {
        switch sqlite3_column_type(handle, index) {
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(handle, index))
        case SQLITE_FLOAT: return .real(sqlite3_column_double(handle, index))
        case SQLITE_TEXT:
            // The pointer is taken before the length, as SQLite asks, and the length is used instead of
            // `strlen`, so text keeps every byte it was given.
            guard let base = sqlite3_column_text(handle, index) else { return .text("") }
            let count = Int(sqlite3_column_bytes(handle, index))
            return .text(String(decoding: UnsafeBufferPointer(start: base, count: count), as: UTF8.self))
        case SQLITE_BLOB:
            guard let base = sqlite3_column_blob(handle, index) else { return .blob([]) }
            let count = Int(sqlite3_column_bytes(handle, index))
            return .blob([UInt8](UnsafeRawBufferPointer(start: base, count: count)))
        default: return .null
        }
    }

    public func row() -> [Value] { (0..<columnCount).map { value(at: $0) } }
}
