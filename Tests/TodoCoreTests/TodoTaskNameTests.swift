import Testing
import TodoCore

/// What a module that imports `TodoCore` sees, without `@testable`: the entity is `TodoTask` so that
/// a consumer can still spell `Task<Success, Failure>` unqualified. With an entity named `Task` the
/// `#expect` line does not compile: "cannot specialize non-generic type 'Task'".
@Test func theNameTaskStillMeansStructuredConcurrencyForAConsumer() {
    _ = TodoTask.self  // binds the import: without a `TodoCore` symbol here, dropping the import would drop the guard
    #expect(ObjectIdentifier(Task<Void, Never>.self) == ObjectIdentifier(_Concurrency.Task<Void, Never>.self))
}
