# Spec review page

Renders a spec from `docs/specs/` into the HTML page published as the Artifact the owner reviews (`docs/process.md`, section 7). The markdown stays the source of truth; the HTML is never committed.

- `build.py <spec.md> <out.html> <notes.md> <kicker> <title>` renders the body with `npx --yes marked@15 --gfm`, turns the h1 and the meta list into the masthead, gives h2 and h3 ids and a contents rail, unescapes mermaid fences into `<pre class="mermaid">` for the viewer's own renderer, wraps tables so they scroll sideways, and puts the Revision notes on top. The kicker is the small line over the title, for example `todo-app · lists · spec for review`; the title is the page's name in the viewer, for example `Lists Screen Spec`, and stays the same across revisions so that the page keeps its address.
- The notes file is a markdown `## Revision notes` heading followed by one blockquote per revision, newest first. It is not committed: the published page keeps every revision's block, so it can be rebuilt from there.
- `snap.swift`, compiled with `xcrun swiftc -O -o snap snap.swift` (the binary is ignored by git), renders a page 1180 points wide in the light and the dark appearance into `light.png` and `dark.png`: `./snap <page.html> <out dir>`. Look at both before publishing; the owner reads in dark mode. `wrap.sh <body.html> <page.html>` puts the publish skeleton around the body first, since the Artifact tool adds it at publish time and the snapshot needs it.

A revision: edit the markdown, add its block to the notes, build, wrap, snapshot, publish to the same artifact, then answer and resolve the threads it came from.
