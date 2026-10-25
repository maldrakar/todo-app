# ADR-0004: Model tasks, tags and views as flat trees, with views defined by filters instead of containers

- Status: Accepted
- Date: 2026-09-11
- Related: `docs/specs/core-storage-and-search.md` (approved 2026-09-11), `docs/specs/lists-screen.md` (approved 2026-10-25), #4, #138, ADR-0003
- Amended: 2026-10-25, after the approval of the Lists screen spec (see the end)

## Context

The brief points at Things 3, whose model has areas, projects and headings as fixed containers. The owner finds fixed containers inflexible and wants users to group tasks by any attribute, for example a tab "Today" that is nothing but a filter on the date. Every extra container type is another table, another set of operations to sync and another level of manual order to merge. The spec's "Data model" and "Filters, sorting, grouping" sections hold the discussion.

## Decision

The core has three entities and no containers. A task carries title, Markdown notes, status, `when` and `deadline` as calendar days, an optional parent task, an order key among siblings, tags, a trashed flag and a tombstone; a project is a task with children and a checklist is the same thing one level down. A tag has a title, an optional parent tag and an order key. A view has a title, an optional parent view, an order key among siblings, a filter stored as a tree of conditions, a sort and a group-by; views nest to any depth, a view with children renders as sections, a view without a filter is a folder, and a heading is a child view whose filter is "listed in this view's manual list". Manual order and manual membership share one table of (view, task, rank). The built-in lists Inbox, Today, Upcoming, Logbook and Trash are ordinary views with fixed ids. Days are counts of days since 1970-01-01 and the platform passes "today" with every query, so time zones never enter the core. Order keys are fractional-index strings, so a move never renumbers neighbours. Trash is inherited from ancestors at query time rather than pushed to children.

Alternatives. The Things hierarchy lost because it fixes the grouping and triples the ordering to sync. Project as a tag lost because a project needs notes, a deadline and completion. Project and headings as separate entities lost because a task with children and a child view already cover them. A "Someday" bucket and an "evening" flag were dropped because a tag or a view covers each and a migration can add a bucket later.

## Consequences

Easier: one ordering mechanism for tasks, tags and views; new groupings are data, not code; any list the UI needs is a view the user could also have created; sync merges three flat tables instead of a hierarchy.

Harder: manual order inside a filtered view is a separate layer rather than a property of the task; an older app cannot evaluate a condition kind it does not know and must show "view needs a newer app"; a cycle in a parent link after a merge has to be tolerated when reading.

Constrained: no container entity may be added without revisiting this record; every product list is expressed as a filter tree, so the condition set grows by migration; UI layers compose sections from child views rather than from their own structures. Reversing towards containers means new tables, a migration of parent links and views into them, and a second ordering model; the operation journal of ADR-0003 would carry the migration.

## Amendment, 2026-10-25

Made with the approval of `docs/specs/lists-screen.md` (#138). The owner wants areas in the sidebar, the lines that group lists as Things draws them, told apart from a folder in the model and without the container entity this record forbids; and a list wants a colour and an icon of its own. The spec's sections 2 and 3 hold the discussion. The decision holds: three entities and no containers. What changes is what a view carries and what one kind of view means.

1. **A view carries a kind, a colour and an icon.** Three nullable text fields beside the title, written when the view is created. The kind is `list` or `area`, and absent reads as `list`; it never changes afterwards. The colour is one of a short list of names the core owns, and the icon the name of a glyph in the app's own set; the shade a colour means and the glyph a name draws are the platform's. A value this app does not know reads as absent, the way a value the type cannot hold reads as absent everywhere (`docs/style.md`), and an older app journals the field and applies nothing, as it does for every field it does not know (ADR-0003).
2. **An area is a view of the root of kind `area`.** It has no rule, no colour, no icon and never opens; its children are lists, and the line it is drawn as defines the area: everything under it, down to the next line, belongs to it. The store refuses a write that would nest an area, and an area that arrives nested anyway, moved as a plain view by an app older than the field, reads as a list with no rule, a folder. That is a reading rule and not a repair, as the decision reads a circular parent as root. So "no container entity may be added without revisiting this record" stands: an area is a view, in the one tree, the one order and the one journal, told from a folder by one field.
3. **The built-in views stay ordinary views.** Inbox, Today, Upcoming, Logbook and Trash are the views a store starts with and nothing more: they move into areas, are renamed and deleted like any list, and nothing in the model or the UI pins them or names them, beyond the seed that writes them at clock zero (owner, 2026-10-25).

Consequences. Easier: an area is data the sidebar reads, and a new kind of view is one more value of one field; a list's look syncs with the list. Harder: the reading rules grow by three, for an unknown kind, colour or icon, and a nested area; the seed carries a colour and an icon per built-in, which a person's own choice outranks as a rename does. Constrained: an area is never nested and never holds tasks; a view's kind is written once; nothing pins a built-in. Reversing this amendment means a container entity after all, which is what the decision costs to reverse.
