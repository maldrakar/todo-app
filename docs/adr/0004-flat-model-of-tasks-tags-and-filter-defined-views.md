# ADR-0004: Model tasks, tags and views as flat trees, with views defined by filters instead of containers

- Status: Proposed
- Date: 2026-09-11
- Related: `docs/specs/core-storage-and-search.md` (approved 2026-09-11), #4, ADR-0003

## Context

The brief points at Things 3, whose model has areas, projects and headings as fixed containers. The owner finds fixed containers inflexible and wants users to group tasks by any attribute, for example a tab "Today" that is nothing but a filter on the date. Every extra container type is another table, another set of operations to sync and another level of manual order to merge. The spec's "Data model" and "Filters, sorting, grouping" sections hold the discussion.

## Decision

The core has three entities and no containers. A task carries title, Markdown notes, status, `when` and `deadline` as calendar days, an optional parent task, an order key among siblings, tags, a trashed flag and a tombstone; a project is a task with children and a checklist is the same thing one level down. A tag has a title, an optional parent tag and an order key. A view has a title, an optional parent view, an order key among siblings, a filter stored as a tree of conditions, a sort and a group-by; views nest to any depth, a view with children renders as sections, a view without a filter is a folder, and a heading is a child view whose filter is "listed in this view's manual list". Manual order and manual membership share one table of (view, task, rank). The built-in lists Inbox, Today, Upcoming, Logbook and Trash are ordinary views with fixed ids. Days are counts of days since 1970-01-01 and the platform passes "today" with every query, so time zones never enter the core. Order keys are fractional-index strings, so a move never renumbers neighbours. Trash is inherited from ancestors at query time rather than pushed to children.

Alternatives. The Things hierarchy lost because it fixes the grouping and triples the ordering to sync. Project as a tag lost because a project needs notes, a deadline and completion. Project and headings as separate entities lost because a task with children and a child view already cover them. A "Someday" bucket and an "evening" flag were dropped because a tag or a view covers each and a migration can add a bucket later.

## Consequences

Easier: one ordering mechanism for tasks, tags and views; new groupings are data, not code; any list the UI needs is a view the user could also have created; sync merges three flat tables instead of a hierarchy.

Harder: manual order inside a filtered view is a separate layer rather than a property of the task; an older app cannot evaluate a condition kind it does not know and must show "view needs a newer app"; a cycle in a parent link after a merge has to be tolerated when reading.

Constrained: no container entity may be added without revisiting this record; every product list is expressed as a filter tree, so the condition set grows by migration; UI layers compose sections from child views rather than from their own structures. Reversing towards containers means new tables, a migration of parent links and views into them, and a second ordering model; the operation journal of ADR-0003 would carry the migration.
