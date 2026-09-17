import Testing
import TodoCore

/// What a module that imports `TodoCore` sees, without `@testable`: the entity is `TodoTask` so that
/// a consumer can still spell `Task<Success, Failure>` unqualified. With an entity named `Task` the
/// `#expect` line does not compile: "cannot specialize non-generic type 'Task'".
@Test func theNameTaskStillMeansStructuredConcurrencyForAConsumer() {
    _ = TodoTask.self  // binds the import: without a `TodoCore` symbol here, dropping the import would drop the guard
    #expect(ObjectIdentifier(Task<Void, Never>.self) == ObjectIdentifier(_Concurrency.Task<Void, Never>.self))
}

/// The same guard for the names Task 9 would otherwise have taken. `TaskGroup` is the one this file can
/// prove, because the standard library is imported into every module: a `TaskGroup` exported by the core
/// shadows `_Concurrency.TaskGroup` and this line fails with "cannot specialize non-generic type".
///
/// `View` and `Section` are SwiftUI's, which the core cannot import — it builds for wasm32 too — so they
/// are settled by the compiler probe recorded in the pull request for #19: an unqualified `View` in a file
/// that imports both is "ambiguous for type lookup in this context", and every SwiftUI type in M2 is
/// declared with one. The core exports `TodoView` and `ViewPage.Section` instead, and the `_ = ` lines
/// below fail to compile if either ever moves back to the top level under its plain name.
@Test func theNamesAViewConsumerNeedsAreLeftAlone() {
    _ = TodoView.self
    _ = ViewPage.Section.self
    _ = ViewPage.Group.self
    #expect(ObjectIdentifier(TaskGroup<Void>.self) == ObjectIdentifier(_Concurrency.TaskGroup<Void>.self))
}
