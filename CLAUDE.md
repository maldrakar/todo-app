# CLAUDE.md

Digest of `docs/process.md`. When the two disagree, `docs/process.md` wins.

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

- GitHub Issues. Milestones are increments: `M0 Process`, `M1 Core architecture`, `M2 Feature-module architecture`, `M3 Product functionality`.
- Issue body has four sections: Context, Goal, Acceptance criteria, Out of scope. Priority inside a milestone is the order of issues, not a label.
- Labels: type `feature` `bug` `arch` `infra` `docs` `spike` `epic`; area `core` `ui-apple` `ui-web`.
- Epic: an issue labeled `epic` that links the spec and plan. Children are attached as sub-issues through `gh api graphql`; a task list in the epic body is the fallback.

## Sizes of work

Say the classification out loud before starting; when in doubt go heavier, never downgrade mid-task.

- Spike: a feasibility question. The answer goes into the issue; any code is throwaway.
- Bounded: a small change to an existing flow. Short design in chat, owner OK, then code.
- Architectural: new subsystem or module. Brainstorm, spec in `docs/specs/`, Artifact review, plan in `docs/plans/`. The same issue becomes the epic and the plan's tasks become its sub-issues.

## Task lifecycle

1. Take the top open issue of the current milestone and classify it.
2. Branch `<type>/<issue>-<slug>`, for example `feature/12-task-repository`. Test-first.
3. Before the PR: build, tests, self-review of the diff.
4. PR title in Conventional Commits with a scope from `core` `apple` `web` `docs` `infra` `ci`, for example `feat(core): add task repository`. Body follows the PR template and ends with `Closes #N`.
5. Squash merge, one commit per issue, branch deleted. The squash message is the PR title.

Definition of Done: acceptance criteria met, tests green, CI green, spec or ADR updated if architecture changed, no `TODO` without a linked issue.

## Specs and ADRs

- Spec (`docs/specs/`, copy `TEMPLATE.md`) is written for the owner. Every type defined outside the document gets a one-line reminder at first mention and an entry in the glossary.
- Review: publish the spec as an Artifact rendered from the markdown; the owner comments in threads; update the markdown, republish with a Revision notes block on top, reply and resolve. Approval is an explicit "approved" in chat; then the spec merges through a `docs` PR. Markdown is the source of truth, HTML is never committed.
- ADR (`docs/adr/`, copy `0000-adr-template.md`): written after a spec is approved for decisions that constrain future work, and mid-implementation for unplanned decisions that are expensive to reverse. Proposed through an `arch` PR.

## Closing a milestone

All issues closed, CI green, `CHANGELOG.md` moves Unreleased into `[0.N.0]`, tag `v0.N.0`, `gh release create`, something runnable on at least one platform.

## Toolchain notes

- Swift 6.2 and Xcode 26.3 locally. The core is full Swift restricted to the standard library and FoundationEssentials (ADR-0001) and compiles for iOS, macOS, iPadOS, watchOS and WASM. Apple targets build with the Xcode toolchain; the WASM target uses the swift.org toolchain through swiftly and its Swift SDK.
- CI runs on macOS runners, which cost 10x minutes on a private repository. Keep CI lean.
