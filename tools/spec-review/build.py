import html, re, subprocess, sys, pathlib

src = pathlib.Path(sys.argv[1])          # the spec markdown
out = pathlib.Path(sys.argv[2])          # the html to write
notes_path = pathlib.Path(sys.argv[3])   # revision notes, markdown
kicker = sys.argv[4]                     # e.g. "todo-app · lists · spec for review"
title = sys.argv[5]                      # the <title>

md = src.read_text(encoding="utf-8")

# Masthead: the h1 and the meta list at the top.
m = re.match(r"# (.+)\n\n((?:- .+\n)+)\n", md)
h1 = m.group(1)
meta = [line[2:] for line in m.group(2).strip().split("\n")]
body_md = md[m.end():]

def render(markdown):
    return subprocess.run(["npx", "--yes", "marked@15", "--gfm"], input=markdown, capture_output=True, text=True, check=True).stdout

body = render(body_md)
notes = render(notes_path.read_text(encoding="utf-8"))

# Mermaid fences: marked wraps them as <pre><code class="language-mermaid">…</code></pre>, entities escaped.
def mermaid(mm):
    return '<pre class="mermaid">' + html.unescape(mm.group(1)) + "</pre>"
body = re.sub(r'<pre><code class="language-mermaid">([\s\S]*?)</code></pre>', mermaid, body)

# Ids on h2 and h3, and the contents rail.
toc = []
def slug(text):
    t = html.unescape(re.sub(r"<[^>]+>", "", text)).lower()
    t = re.sub(r"[^\w\s-]", "", t)
    return re.sub(r"[\s]+", "-", t).strip("-")
def heading(mm):
    level, inner = mm.group(1), mm.group(2)
    sid = slug(inner)
    toc.append((level, sid, inner))
    return f'<h{level} id="{sid}">{inner}</h{level}>'
notes = re.sub(r"<h(2|3)>(.*?)</h\1>", heading, notes)
body = re.sub(r"<h(2|3)>(.*?)</h\1>", heading, body)

# Tables scroll sideways inside their own box.
body = body.replace("<table>", '<div class="table"><table>').replace("</table>", "</table></div>")

# Meta items: escaped text with bare URLs turned into links.
def meta_item(text):
    t = html.escape(text, quote=False)
    return re.sub(r"(https?://[^\s<]+)", r'<a href="\1">\1</a>', t)
meta_html = "".join(f"<li>{meta_item(x)}</li>" for x in meta)
toc_html = "".join(f'<li class="l{level}"><a href="#{sid}">{inner}</a></li>' for level, sid, inner in toc)

CSS = '''/* Layout: a reading column of 68ch beside a sticky contents rail; the rail folds above the text at phone width. */
:root {
  --bg: #f6f7f3; --fg: #1d221d; --muted: #5a645a; --rule: #d6dcd3; --panel: #eef1ea;
  --accent: #2f6b3f; --accent-ink: #245432; --code-bg: #e9ede5; --note: #e2ead9;
  --display: "IBM Plex Sans", "Helvetica Neue", Arial, sans-serif;
  --body: "Source Serif 4", Georgia, "Times New Roman", serif;
  --mono: "IBM Plex Mono", "SF Mono", Menlo, Consolas, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #151916; --fg: #e4e8e0; --muted: #9aa597; --rule: #2d352e; --panel: #1b211c;
  --accent: #7fbf8f; --accent-ink: #9bd0a8; --code-bg: #1e2520; --note: #1f2a21; color-scheme: dark;
} }
:root[data-theme="dark"] {
  --bg: #151916; --fg: #e4e8e0; --muted: #9aa597; --rule: #2d352e; --panel: #1b211c;
  --accent: #7fbf8f; --accent-ink: #9bd0a8; --code-bg: #1e2520; --note: #1f2a21; color-scheme: dark;
}
body {
  background: var(--bg); color: var(--fg); font-family: var(--body); font-size: 17px; line-height: 1.55;
  -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  padding-block: 0 4rem;
}
.wrap { max-width: 1120px; margin: 0 auto; display: grid; grid-template-columns: 15rem minmax(0, 1fr); gap: 3rem; }
header.mast { grid-column: 1 / -1; padding-block: 2.5rem 1.5rem; border-bottom: 1px solid var(--rule); }
header.mast .kicker { font-family: var(--display); font-weight: 500; text-transform: uppercase; letter-spacing: .08em; font-size: .75rem; color: var(--accent-ink); }
header.mast h1 { font-family: var(--display); font-weight: 600; font-size: clamp(1.7rem, 3.5vw, 2.4rem); line-height: 1.15; margin: .4rem 0 1rem; text-wrap: balance; }
header.mast ul { list-style: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: .4rem 1.75rem; font-family: var(--display); font-size: .9rem; color: var(--muted); }
header.mast a { color: var(--accent-ink); }
nav.rail { position: sticky; top: 1.5rem; align-self: start; font-family: var(--display); font-size: .85rem; }
nav.rail .label { text-transform: uppercase; letter-spacing: .08em; font-size: .7rem; color: var(--muted); margin-bottom: .6rem; }
ol.toc { list-style: none; padding: 0; margin: 0; border-left: 2px solid var(--rule); }
ol.toc li { margin: 0; }
ol.toc li a { display: block; padding: .25rem .75rem; color: var(--fg); text-decoration: none; border-left: 2px solid transparent; margin-left: -2px; }
ol.toc li.l3 a { padding-left: 1.5rem; color: var(--muted); font-size: .8rem; }
ol.toc li a:hover, ol.toc li a:focus-visible { border-left-color: var(--accent); color: var(--accent-ink); outline: none; }
main { min-width: 0; max-width: 68ch; }
main h2 { font-family: var(--display); font-weight: 600; font-size: 1.45rem; line-height: 1.2; margin: 2.75rem 0 .9rem; text-wrap: balance; padding-top: 1.25rem; border-top: 1px solid var(--rule); }
main h3 { font-family: var(--display); font-weight: 600; font-size: 1.05rem; margin: 2rem 0 .6rem; text-wrap: balance; }
main p, main li { margin: 0 0 .9rem; }
main ul, main ol { padding-left: 1.4rem; }
main li { margin-bottom: .5rem; }
main a { color: var(--accent-ink); }
main strong { font-weight: 600; }
code { font-family: var(--mono); font-size: .86em; background: var(--code-bg); padding: .08em .3em; border-radius: 3px; }
pre { font-family: var(--mono); font-size: .8rem; line-height: 1.5; background: var(--code-bg); padding: 1rem 1.1rem; border-radius: 6px; overflow-x: auto; margin: 0 0 1.2rem; }
pre code { background: none; padding: 0; font-size: inherit; }
pre.mermaid { background: var(--panel); border: 1px solid var(--rule); text-align: center; }
.table { overflow-x: auto; margin: 0 0 1.2rem; }
table { border-collapse: collapse; width: 100%; font-family: var(--display); font-size: .88rem; }
th, td { text-align: left; vertical-align: top; padding: .5rem .7rem; border-bottom: 1px solid var(--rule); }
th { font-weight: 600; color: var(--muted); font-size: .78rem; text-transform: uppercase; letter-spacing: .06em; }
td code { white-space: nowrap; }
blockquote { margin: 0 0 1.2rem; padding: .8rem 1rem; background: var(--note); border-left: 3px solid var(--accent); }
blockquote p:last-child { margin-bottom: 0; }
@media (max-width: 760px) {
  .wrap { grid-template-columns: minmax(0, 1fr); gap: 1.5rem; }
  nav.rail { position: static; }
  main { max-width: none; }
  body { font-size: 16px; }
}
@media (prefers-reduced-motion: no-preference) { html { scroll-behavior: smooth; } }
'''

page = (
    f"<title>{html.escape(title)}</title>\n"
    '<meta name="claude:viewport-fit-sides" content="cover">\n'
    '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
    '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@500;600&family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,600;1,8..60,400&display=swap">\n'
    "<style>\n" + CSS + "</style>\n"
    '<div class="wrap">\n'
    '  <header class="mast">\n'
    f'    <div class="kicker">{html.escape(kicker)}</div>\n'
    f"    <h1>{html.escape(h1)}</h1>\n"
    f"    <ul>{meta_html}</ul>\n"
    "  </header>\n"
    '  <nav class="rail" aria-label="Contents">\n'
    '    <div class="label">Contents</div>\n'
    f'    <ol class="toc">{toc_html}</ol>\n'
    "  </nav>\n"
    "  <main>\n"
    + notes + "\n\n" + body +
    "  </main>\n"
    "</div>\n"
)
out.write_text(page, encoding="utf-8")
print("wrote", out, len(page.encode("utf-8")))
