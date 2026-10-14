# CLAUDE.md

Digest of `docs/process.md`. When the two disagree, `docs/process.md` wins.
Only this file is in context by default, so read the full document before
architectural work, before a spec review and before closing a milestone, and
whenever a point here is thin or silent.

## Language

Everything in the repository and on GitHub is in English. Conversation with the owner is in Russian.

## Roles

- Owner: Artur, GitHub `maldrakar`. Reviews specs and PRs and has the final say on every merge.
- Engineer: Claude. Proposes designs, grooms the backlog, implements, opens PRs, keeps `CHANGELOG.md` and docs current.

## Rules that are never broken

- Never push to `main`. Every change goes through a PR.
- Never merge without an explicit OK from the owner in chat, unless the owner merges in GitHub.
- Create issues only after agreement in chat. Exception: a bug found mid-task is filed at once with `bug` and mentioned in chat.
- Remote operations go through `gh`.

## Backlog

- GitHub Issues. Milestones are increments: `M0 Process`, `M1 Core architecture`, `M2 Feature-module architecture`, `M3 Navigation`, `M4 Product functionality`.
- Issue body has four sections: Context, Goal, Acceptance criteria, Out of scope. Priority inside a milestone is the order of issues, not a label.
- Labels: type `feature` `bug` `arch` `infra` `docs` `spike` `epic`; area `core` `ui-apple` `ui-web`.
- Epic: an issue labeled `epic` that links the spec and plan. Children are attached as sub-issues through `gh api graphql`; a task list in the epic body is the fallback.

## Sizes of work

Say the classification out loud before starting; when in doubt go heavier, never downgrade mid-task.

- Spike: a feasibility question. The answer goes into the issue; any code is throwaway.
- Bounded: a small change to an existing flow. Short design in chat, owner OK, then code.
- Architectural: new subsystem or module. Brainstorm, spec in `docs/specs/`, Artifact review, plan in `docs/plans/` with its task table and interfaces reviewed by the owner. The same issue becomes the epic and the plan's tasks become its sub-issues.

## Task lifecycle

1. Take the top open issue of the current milestone and classify it.
2. Branch `<type>/<issue>-<slug>`, for example `feature/12-task-repository`. Test-first.
3. Before the PR: build, tests, self-review of the diff against the spec, the plan and `docs/style.md`, then a review pass by a second agent over the finished diff. Every finding is confirmed by a failing test before the code changes.
4. PR title in Conventional Commits with a scope from `core` `apple` `web` `docs` `infra` `ci`, for example `feat(core): add task repository`. Body follows the PR template and ends with `Closes #N`.
5. Squash merge, one commit per issue, branch deleted. The squash message is the PR title.

Working from a plan: read the task's section against what its dependencies actually shipped. A departure is made in the task's PR and stated in its body; the shipped section is not rewritten, the sections of later tasks that depend on it are.

Open questions go to chat before the PR or into a thread on it, never into the PR body: body text has no reaction and goes unanswered.

Review reactions (the reaction on a comment is left by its recipient and is the verdict):

- Owner on my comment: 👍 accepted, do it; 👀 discussing, do not implement; 👎 rejected, drop it.
- Me on the owner's comment: 👍 understood, implementing; 👀 counter-argument or question, into the thread and wait; 👎 the owner withdrew it after that discussion, never a refusal of my own.
- Every comment gets a reaction, 👀 resolves into 👍 or 👎, only 👍 threads are implemented, a thread is resolved after the change is pushed. Pull requests and issues only; Artifact spec review has no reactions.

Definition of Done: acceptance criteria met, tests green, CI green, diff holds to `docs/style.md`, spec or ADR updated if architecture changed, no `TODO` without a linked issue.

## Code rules

`docs/style.md` holds the rules the owner's reviews established: tightest visibility, no member without a caller, no client policy in a lower layer, immutable values, one shape everywhere it fits, no trap on data from outside. Give it to every implementing and reviewing agent. A rule a review sets twice is added there in the same PR; the owner edits it directly.

## Specs and ADRs

- Spec (`docs/specs/`, copy `TEMPLATE.md`) is written for the owner. Every type defined outside the document gets a one-line reminder at first mention and an entry in the glossary.
- Review: publish the spec as an Artifact rendered from the markdown; the owner comments in threads; update the markdown, republish with a Revision notes block on top, reply and resolve. Approval is an explicit "approved" in chat; then the spec merges through a `docs` PR. Markdown is the source of truth, HTML is never committed.
- Plan (`docs/plans/`, copy `TEMPLATE.md`) is written for the engineer: global constraints and a file map, then per task 50 to 100 lines with goal, files, interface as signatures, rules in prose, a test list and verified facts. Code only where it already ran. The owner reviews the task table and each task's interface.
- ADR (`docs/adr/`, copy `0000-adr-template.md`): written after a spec is approved for decisions that constrain future work, and mid-implementation for unplanned decisions that are expensive to reverse. Proposed through an `arch` PR.

## Closing a milestone

All issues closed, CI green, `CHANGELOG.md` moves Unreleased into `[0.N.0]`, tag `v0.N.0`, `gh release create`, something runnable on at least one platform.

## Toolchain notes

- Toolchain: Swift 6.4.0 from swift.org, pinned in `.swift-version` and installed through swiftly; Xcode 27.1 supplies the Apple SDKs, and its own toolchain is the same Swift 6.4.0. The core is full Swift restricted to the standard library and FoundationEssentials (ADR-0001), built and tested with SwiftPM alone, and compiles for iOS, macOS, iPadOS, watchOS and WASM through the Swift SDK of the same version.
- CI: the Linux job (build, tests, wasm32 tests, wasm size budget in `scripts/wasm-size.sh`) runs on every PR; the macOS job on the `xcode-27` image (iOS and watchOS SDK compile checks, the Apple package's build and tests, and builds with Xcode's toolchain that fail unless it is the pinned version) runs only on `main` and on demand, because macOS minutes cost tenfold.
