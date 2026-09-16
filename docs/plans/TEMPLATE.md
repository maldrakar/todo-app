# Plan: Topic

- Status: Draft | Approved
- Spec: `docs/specs/<topic>.md`, approved YYYY-MM-DD
- Epic: #N

Written for the engineer and derived from the approved spec. The plan
fixes what the tasks are, in what order, and what each one promises to
the next. It does not carry the implementation: code appears only where
it already ran. A task section is 50 to 100 lines. Once a task ships its
section is history; a departure is stated in the task's pull request and
fixed forward into the sections that depend on it, never back into the
shipped one (`docs/process.md`, sections 6 and 7).

> Executed task by task, one sub-issue per branch and pull request, with
> superpowers:subagent-driven-development or superpowers:executing-plans.

## Global constraints

The rules every task obeys, each with the spec section or ADR it comes
from.

-

## File map

| File | Task | Holds |
| ---- | ---- | ----- |
|      |      |       |

## Tasks

| # | Issue | Title | Labels | Depends on |
| - | ----- | ----- | ------ | ---------- |
| 1 |       |       |        |            |

The owner reviews this table and the interface of every task below.

### Task 1: Title

**Goal.** What exists when the task is done that did not before.

**Files.** Created or changed, with the target each belongs to.

**Interface.** Signatures only: the types, methods, errors and their
visibility that later tasks or the outside call. Nothing without a
caller in this task or in a named later one.

```swift
public struct Example {
    public init()
    public func run() throws(ExampleError)
}
```

**Rules.** The invariants in prose, the "why" a signature cannot say,
each with the spec section or ADR it comes from.

-

**Tests.** One line per test: its name and what it proves. The issue's
acceptance criteria map onto these.

- `aTestName`:

**Verified facts and traps.** What was run or measured by hand, with the
date, and the failure modes already known on the way. Code here only if
it was executed.

-

## Self-review against the spec

Section by section of the spec, which task covers it. Deviations from
the spec, each stated where it happens.
