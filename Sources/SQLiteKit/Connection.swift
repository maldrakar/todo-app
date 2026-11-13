import CSQLite

/// Some of SQLite's state belongs to the process and not to a connection: the random-number generator FTS5
/// draws from at every open, the status counters, the unix VFS's list of open files. SQLite is compiled in
/// multi-thread mode (`SQLITE_THREADSAFE=2`, ADR-0002), whose mutexes guard that state, so connections may be
/// open and in use on several threads at once, as the parallel test runner has them. What the mutexes do not
/// guard is a connection and what was prepared on it, so neither `Connection` nor `Statement` is `Sendable`:
/// the compiler lets each be used from one isolation domain at a time.
///
/// Upstream leaves two first checks outside every mutex, harmless by its account and races to ThreadSanitizer
/// all the same (#98). `sqlite3_initialize` reads whether the library is initialized before it takes a mutex,
/// so it runs here, once. And at every file open `unixOpen` reads the process id the unix VFS keeps to notice a
/// fork, and while it differs from the current one rewrites it and resets the generator; seeding the generator
/// sets it, so the generator is seeded here too, and every later access is a read. Swift initializes a global
/// `let` exactly once and blocks every other thread until it is done, and every `open` reads it first.
private let libraryInitialization: Int32 = {
    let rc = sqlite3_initialize()
    guard rc == SQLITE_OK else { return rc }
    var byte: UInt8 = 0
    sqlite3_randomness(1, &byte)
    return SQLITE_OK
}()

/// One open SQLite database, closed when the last reference goes away.
public final class Connection {
    private let handle: OpaquePointer

    private init(handle: OpaquePointer) { self.handle = handle }

    deinit { sqlite3_close_v2(handle) }

    /// Opens the database at `path`, creating it when it is not there yet.
    ///
    /// `pragmas` are the bodies of `PRAGMA` statements — `"journal_mode = WAL"` — run in order the moment the
    /// database is open. The wrapper holds no opinion about them: journal mode, synchrony and foreign keys are
    /// the client's policy, so they arrive from the client and change there, not here.
    ///
    /// They are run one statement at a time and outside any transaction, which is the only way that works:
    /// `journal_mode = WAL` fails inside a transaction and `foreign_keys` is a silent no-op there. SQLite also
    /// ignores a pragma it does not know and a value it cannot use without saying so, so a setting that has to
    /// hold is worth reading back.
    public static func open(path: String, pragmas: [String] = []) throws(SQLiteError) -> Connection {
        try open(name: path, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, pragmas: pragmas)
    }

    /// Opens a private in-memory database. `pragmas` are applied as in `open(path:pragmas:)`.
    public static func openInMemory(pragmas: [String] = []) throws(SQLiteError) -> Connection {
        try open(name: ":memory:", flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_MEMORY, pragmas: pragmas)
    }

    private static func open(name: String, flags: Int32, pragmas: [String]) throws(SQLiteError) -> Connection {
        guard libraryInitialization == SQLITE_OK else {
            throw SQLiteError(code: libraryInitialization, message: "sqlite3_initialize failed")
        }
        var raw: OpaquePointer?
        let rc = sqlite3_open_v2(name, &raw, flags, nil)
        guard rc == SQLITE_OK, let raw else {
            let error = SQLiteError(handle: raw, code: rc)
            sqlite3_close_v2(raw)
            throw error
        }
        let connection = Connection(handle: raw)
        for pragma in pragmas {
            do { try connection.execute("PRAGMA \(pragma);") }
            catch { throw SQLiteError(code: error.code, message: "PRAGMA \(pragma): \(error.message)") }
        }
        return connection
    }

    /// Runs one or more statements without parameters.
    public func execute(_ sql: String) throws(SQLiteError) {
        var message: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &message)
        if rc != SQLITE_OK {
            let text = message.map { String(cString: $0) } ?? "sqlite error \(rc)"
            sqlite3_free(message)
            throw SQLiteError(code: rc, message: text)
        }
    }

    /// Defines `name(text)` in this connection's SQL as `body`, for every statement prepared on it from now on.
    ///
    /// The function takes one argument. A text goes through `body` and its answer comes back as text, every byte of
    /// it; any other value, a number, a blob or a null, comes back as it went in, since there is no text in it for
    /// `body` to read. An `ORDER BY` over the function computes it once per row, as the row enters the sort, and not
    /// once per comparison.
    ///
    /// Two things are asked of `body`. It answers the same for the same text: SQLite is told so
    /// (`SQLITE_DETERMINISTIC`) and may compute a call over a constant once per statement, so a body that does not
    /// would be answered wrongly and in silence. And it does not hold this connection: SQLite keeps `body` until the
    /// connection closes, so a body that held it would keep it open for good.
    ///
    /// The function lives on the connection and not in the file, so the schema may not call it: SQLite refuses it to
    /// a view, a trigger, an index and a generated column (`SQLITE_DIRECTONLY`). A file that called it would fail in
    /// every program that has not defined it, the `sqlite3` shell and an older version of the app among them. That is
    /// a consequence of where the function lives and not a choice of the client's, which is why it is not a parameter.
    ///
    /// `package` and not `public`: the core is its one caller, and this target is in no product.
    package func defineFunction(_ name: String, _ body: @escaping (String) -> String) throws(SQLiteError) {
        let function = Unmanaged.passRetained(TextFunction(body)).toOpaque()
        // SQLite releases the body through the last argument when the connection closes, when the name is defined
        // again, and when this call fails, so nothing here releases it a second time.
        let rc = sqlite3_create_function_v2(
            handle, name, 1, SQLITE_UTF8 | SQLITE_DETERMINISTIC | SQLITE_DIRECTONLY, function,
            { context, _, arguments in TextFunction.call(context, arguments?[0]) }, nil, nil,
            { function in function.map { Unmanaged<TextFunction>.fromOpaque($0).release() } }
        )
        if rc != SQLITE_OK { throw lastError(code: rc) }
    }

    /// Prepares exactly one statement.
    ///
    /// `sqlite3_prepare_v2` compiles the first statement of the text and hands back the rest, so anything
    /// after the first would be dropped without a word by `run` and `rows`. It is refused instead; text with
    /// several statements belongs in `execute`.
    public func prepare(_ sql: String) throws(SQLiteError) -> Statement {
        var raw: OpaquePointer?
        var rc = SQLITE_OK
        var hasMoreStatements = false
        sql.withCString { start in
            var tail: UnsafePointer<CChar>?
            rc = sqlite3_prepare_v2(handle, start, -1, &raw, &tail)
            guard rc == SQLITE_OK, var cursor = tail else { return }
            while cursor.pointee != 0 {
                let byte = cursor.pointee
                let isBlank = byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0B || byte == 0x0C || byte == 0x0D
                if !isBlank && byte != 0x3B {  // a semicolon or blank space is a separator, not a statement
                    hasMoreStatements = true
                    return
                }
                cursor += 1
            }
        }
        guard rc == SQLITE_OK else { throw lastError(code: rc) }
        guard let raw else { throw SQLiteError(code: SQLITE_MISUSE, message: "no statement to prepare in: \(sql)") }
        guard !hasMoreStatements else {
            sqlite3_finalize(raw)
            throw SQLiteError(code: SQLITE_MISUSE, message: "more than one statement in: \(sql)")
        }
        return Statement(handle: raw, connection: self)
    }

    /// Runs one statement with parameters and discards rows.
    public func run(_ sql: String, _ params: [Value] = []) throws(SQLiteError) {
        let statement = try prepare(sql)
        try statement.bind(params)
        while try statement.step() {}
    }

    /// Runs one statement with parameters and returns every row.
    public func rows(_ sql: String, _ params: [Value] = []) throws(SQLiteError) -> [[Value]] {
        let statement = try prepare(sql)
        try statement.bind(params)
        var result: [[Value]] = []
        while try statement.step() { result.append(statement.row()) }
        return result
    }

    /// BEGIN IMMEDIATE ... COMMIT, with ROLLBACK if the body or the commit throws.
    public func transaction<T>(_ body: () throws(SQLiteError) -> T) throws(SQLiteError) -> T {
        try execute("BEGIN IMMEDIATE")
        let result: T
        do {
            result = try body()
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
        do {
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
        return result
    }

    public func userVersion() throws(SQLiteError) -> Int32 {
        Int32(try rows("PRAGMA user_version").first?.first?.int64 ?? 0)
    }

    public func setUserVersion(_ version: Int32) throws(SQLiteError) {
        try execute("PRAGMA user_version = \(version)")
    }

    /// The error SQLite reports for the last failed call on this connection, for the statements it prepared.
    func lastError(code: Int32) -> SQLiteError { SQLiteError(handle: handle, code: code) }

    public var lastInsertRowID: Int64 { sqlite3_last_insert_rowid(handle) }
    public var changes: Int64 { Int64(sqlite3_changes64(handle)) }

    /// A copy of the whole database as bytes (`sqlite3_serialize`).
    public func serialize() throws(SQLiteError) -> [UInt8] {
        var size: sqlite3_int64 = 0
        guard let bytes = sqlite3_serialize(handle, "main", &size, 0) else {
            throw SQLiteError(code: SQLITE_NOMEM, message: "sqlite3_serialize returned NULL")
        }
        defer { sqlite3_free(bytes) }
        return [UInt8](UnsafeBufferPointer(start: bytes, count: Int(size)))
    }

    /// Replaces the contents of this connection with a serialized database (`sqlite3_deserialize`).
    public func deserialize(_ bytes: [UInt8]) throws(SQLiteError) {
        let count = bytes.count
        guard let buffer = sqlite3_malloc64(sqlite3_uint64(max(count, 1))) else {
            throw SQLiteError(code: SQLITE_NOMEM, message: "sqlite3_malloc64 failed")
        }
        bytes.withUnsafeBytes { source in
            if let base = source.baseAddress { buffer.copyMemory(from: base, byteCount: count) }
        }
        let flags = UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
        let rc = sqlite3_deserialize(handle, "main", buffer.assumingMemoryBound(to: UInt8.self), sqlite3_int64(count), sqlite3_int64(count), flags)
        if rc != SQLITE_OK { throw lastError(code: rc) }
        // `sqlite3_deserialize` takes the bytes without looking at them: bytes that are not a database are
        // only noticed by the first query, far from the restore that caused it. Ask one question now, while
        // the caller still knows a snapshot was being restored. A connection that throws here is spent and
        // has to be replaced, not retried.
        _ = try rows("SELECT count(*) FROM sqlite_schema")
    }
}

/// The body of a function `Connection.defineFunction` defined, which SQLite holds as the function's user data for as
/// long as the connection keeps the function.
private final class TextFunction {
    private let body: (String) -> String

    init(_ body: @escaping (String) -> String) { self.body = body }

    /// One call of the function from SQLite, with its one argument. A text is read whole, interior NULs included,
    /// because its length is asked for rather than measured with `strlen`, and bytes that are not UTF-8 are repaired
    /// rather than trusted; the answer is measured the same way and copied by SQLite, in a 64-bit length that no
    /// answer can overflow.
    static func call(_ context: OpaquePointer?, _ argument: OpaquePointer?) {
        guard let context, let argument else { return }
        guard sqlite3_value_type(argument) == SQLITE_TEXT else { return sqlite3_result_value(context, argument) }
        // The text before its length: asking for the text can convert it, and the length SQLite then gives is the
        // length of what was converted.
        guard let start = sqlite3_value_text(argument) else { return sqlite3_result_error_nomem(context) }
        let text = String(decoding: UnsafeBufferPointer(start: start, count: Int(sqlite3_value_bytes(argument))), as: UTF8.self)
        var answer = Unmanaged<TextFunction>.fromOpaque(sqlite3_user_data(context)).takeUnretainedValue().body(text)
        answer.withUTF8 { bytes in
            // An empty buffer may have no address, and SQLite reads a null address as a null result, not as "".
            guard let address = bytes.baseAddress else {
                return sqlite3_result_text64(context, "", 0, Statement.transient, UInt8(SQLITE_UTF8))
            }
            address.withMemoryRebound(to: CChar.self, capacity: bytes.count) {
                sqlite3_result_text64(context, $0, UInt64(bytes.count), Statement.transient, UInt8(SQLITE_UTF8))
            }
        }
    }
}
