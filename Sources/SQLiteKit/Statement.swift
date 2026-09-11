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
    public func bind(_ values: [Value]) throws(SQLiteError) {
        sqlite3_clear_bindings(handle)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let rc: Int32
            switch value {
            case .null: rc = sqlite3_bind_null(handle, index)
            case .integer(let v): rc = sqlite3_bind_int64(handle, index, v)
            case .real(let v): rc = sqlite3_bind_double(handle, index, v)
            case .text(let v): rc = sqlite3_bind_text(handle, index, v, -1, sqliteTransient)
            case .blob(let v):
                rc = v.withUnsafeBytes { sqlite3_bind_blob(handle, index, $0.baseAddress, Int32(v.count), sqliteTransient) }
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

    public func reset() throws(SQLiteError) {
        let rc = sqlite3_reset(handle)
        if rc != SQLITE_OK { throw SQLiteError(handle: db, code: rc) }
    }

    public func value(at index: Int32) -> Value {
        switch sqlite3_column_type(handle, index) {
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(handle, index))
        case SQLITE_FLOAT: return .real(sqlite3_column_double(handle, index))
        case SQLITE_TEXT: return .text(String(cString: sqlite3_column_text(handle, index)))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(handle, index))
            guard count > 0, let base = sqlite3_column_blob(handle, index) else { return .blob([]) }
            return .blob([UInt8](UnsafeRawBufferPointer(start: base, count: count)))
        default: return .null
        }
    }

    public func row() -> [Value] { (0..<columnCount).map { value(at: $0) } }
}
