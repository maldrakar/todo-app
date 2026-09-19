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
/// declared with one. The core exports `TaskView` and `TaskViewPage.Section` instead, and the `_ = ` lines
/// below fail to compile if either ever moves back to the top level under its plain name.
@Test func theNamesAViewConsumerNeedsAreLeftAlone() {
    _ = TaskView.self
    _ = TaskViewPage.Section.self
    _ = TaskViewPage.Group.self
    #expect(ObjectIdentifier(TaskGroup<Void>.self) == ObjectIdentifier(_Concurrency.TaskGroup<Void>.self))
}

/// The unit of the journal is `JournalOperation`, because `Operation` is Foundation's `NSOperation` and every
/// Apple consumer gets it through Foundation and through SwiftUI. The probe recorded in #49 — Swift 6.3.3
/// against the macOS SDK, a consumer importing SwiftUI and a core exporting `public struct Operation` — fails
/// at each use with "'Operation' is ambiguous for type lookup in this context" and names both candidates, so
/// the consumer cannot spell the type at all without qualifying it.
///
/// This file cannot prove that the way the `Task` line above proves its own: the core builds for wasm32 and
/// imports neither Foundation nor SwiftUI, and this file imports nothing but `Testing` and `TodoCore`. What it
/// holds instead is the spelling, the way it holds `TaskView`, and naming the type is what binds the import,
/// so a tidy pass cannot drop the one without the other. The `#expect` is not the tautology it looks like:
/// reflection prints the name a type was declared with, so a `typealias JournalOperation = Operation` that left
/// the ambiguous name exported would satisfy the spelling and fail here.
@Test func theNameOperationIsLeftToFoundation() {
    #expect(String(describing: JournalOperation.self) == "JournalOperation")
}
