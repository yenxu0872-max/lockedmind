#!/usr/bin/env python3
"""Search, sharing and crawler files for the two websites.

    python3 web/_build/seo.py           write everything (safe to run again)
    python3 web/_build/seo.py --check   only check; exit 1 on any problem

Writes, between <!-- seo --> markers in each page's <head>: the canonical address,
Open Graph and Twitter share cards, PNG favicons and structured data (JSON-LD),
with every FAQ answer copied word for word from the page. Adds a breadcrumb trail
to the sub-pages, links between the pages, a plain list of popular models in
models.html (for crawlers and readers without JavaScript), and the site files:
robots.txt, sitemap.xml, llms.txt and 404.html.

BASE is where the sites live. When a custom domain is connected, change it here
(and SITE_URL in ui/_build/build.py), run this, and rebuild the web app.
"""
import html
import json
import re
import sys
from datetime import date
from pathlib import Path

BASE = "https://yenxu0872-max.github.io/lockedmind/"
WEB = Path(__file__).resolve().parent.parent
CHECK = "--check" in sys.argv

# ------------------------------------------------------------------ the pages

ORG = {"@type": "Organization", "@id": BASE + "#lockedmind", "name": "Lockedmind", "url": BASE + "app/",
       "logo": BASE + "app/img/icon-512.png", "sameAs": ["https://github.com/yenxu0872-max/lockedmind"]}

PAGES = [
    {"file": "index.html", "url": BASE, "site": "Lockedmind Models", "icons": "",
     "image": BASE + "og.jpg", "image_alt": "Lockedmind Models: AI models you can run yourself",
     "crumbs": None, "faq": True, "kind": "models-home"},
    {"file": "models.html", "url": BASE + "models.html", "site": "Lockedmind Models", "icons": "",
     "image": BASE + "og.jpg", "image_alt": "Lockedmind Models: AI models you can run yourself",
     "crumbs": [("Lockedmind Models", BASE, "./"), ("Browse models", None, None)], "faq": False, "kind": "models-browse"},
    {"file": "app/index.html", "url": BASE + "app/", "site": "Lockedmind", "icons": "img/",
     "image": BASE + "app/img/og.jpg", "image_alt": "Do you know what happens to your personal data in cloud AI? — Lockedmind",
     "crumbs": None, "faq": True, "kind": "app-home"},
    {"file": "app/privacy.html", "url": BASE + "app/privacy.html", "site": "Lockedmind", "icons": "img/",
     "image": BASE + "app/img/og.jpg", "image_alt": "Lockedmind: private AI that never leaves your device",
     "crumbs": [("Lockedmind", BASE + "app/", "./"), ("Privacy Policy", None, None)], "faq": False, "kind": "doc"},
    {"file": "app/support.html", "url": BASE + "app/support.html", "site": "Lockedmind", "icons": "img/",
     "image": BASE + "app/img/og.jpg", "image_alt": "Lockedmind: private AI that never leaves your device",
     "crumbs": [("Lockedmind", BASE + "app/", "./"), ("Support", None, None)], "faq": True, "kind": "doc"},
]


def text(s):
    """Visible text of an HTML fragment, as one line."""
    s = re.sub(r"<[^>]+>", "", s)
    return re.sub(r"\s+", " ", html.unescape(s)).strip()


def meta(page_html, name):
    m = re.search(rf'<meta name="{name}" content="([^"]*)"', page_html)
    return html.unescape(m.group(1)) if m else ""


def faq_items(page_html):
    """Every <details><summary>Q</summary>A</details> on the page, as visible text."""
    out = []
    for q, a in re.findall(r"<details[^>]*>\s*<summary>(.*?)</summary>(.*?)</details>", page_html, re.S):
        out.append((text(q), text(a)))
    return out


def jsonld(page, page_html, title, desc):
    graph = [ORG]
    if page["kind"] in ("models-home", "models-browse"):
        graph.append({"@type": "WebSite", "@id": BASE + "#site", "name": "Lockedmind Models", "url": BASE,
                      "description": meta((WEB / "index.html").read_text(), "description"), "publisher": {"@id": ORG["@id"]}})
    if page["kind"] == "models-browse":
        graph.append({"@type": "CollectionPage", "name": title, "url": page["url"], "description": desc,
                      "isPartOf": {"@id": BASE + "#site"}})
    if page["kind"] == "app-home":
        graph.append({"@type": "WebApplication", "name": "Lockedmind", "url": BASE + "app/chat.html",
                      "description": desc, "applicationCategory": "UtilitiesApplication",
                      "operatingSystem": "Any operating system with Chrome, Edge or Safari 26",
                      "browserRequirements": "Requires a browser with WebGPU, such as Chrome, Edge or Safari 26",
                      "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
                      "image": page["image"], "publisher": {"@id": ORG["@id"]}})
    if page["kind"] == "doc":
        graph.append({"@type": "WebPage", "name": title, "url": page["url"], "description": desc,
                      "publisher": {"@id": ORG["@id"]}})
    if page["crumbs"]:
        graph.append({"@type": "BreadcrumbList", "itemListElement": [
            {"@type": "ListItem", "position": i + 1, "name": name, **({"item": url} if url else {"item": page["url"]})}
            for i, (name, url, _) in enumerate(page["crumbs"])]})
    if page["faq"]:
        items = faq_items(page_html)
        if items:
            graph.append({"@type": "FAQPage", "mainEntity": [
                {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in items]})
    body = json.dumps({"@context": "https://schema.org", "@graph": graph}, ensure_ascii=False, indent=None)
    return body.replace("</", "<\\/")


def head_block(page, page_html):
    title = text(re.search(r"<title>(.*?)</title>", page_html, re.S).group(1))
    desc = meta(page_html, "description")
    e = lambda s: html.escape(s, quote=True)
    icons = page["icons"]
    lines = [
        "<!-- seo: written by web/_build/seo.py -->",
        f'<link rel="canonical" href="{e(page["url"])}">',
        f'<link rel="icon" type="image/png" sizes="32x32" href="{icons}favicon-32.png">',
        f'<link rel="apple-touch-icon" href="{icons}apple-touch-icon.png">',
        '<meta property="og:type" content="website">',
        f'<meta property="og:site_name" content="{e(page["site"])}">',
        f'<meta property="og:title" content="{e(title)}">',
        f'<meta property="og:description" content="{e(desc)}">',
        f'<meta property="og:url" content="{e(page["url"])}">',
        f'<meta property="og:image" content="{e(page["image"])}">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        f'<meta property="og:image:alt" content="{e(page["image_alt"])}">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{e(title)}">',
        f'<meta name="twitter:description" content="{e(desc)}">',
        f'<meta name="twitter:image" content="{e(page["image"])}">',
        f'<script type="application/ld+json">{jsonld(page, page_html, title, desc)}</script>',
        "<!-- /seo -->",
    ]
    return "\n".join(lines)


def crumbs_nav(page):
    items = []
    for name, _, href in page["crumbs"]:
        items.append(f'<li><a href="{href}">{html.escape(name)}</a></li>' if href
                     else f'<li aria-current="page">{html.escape(name)}</li>')
    return f'<!-- crumbs --><nav class="crumbs" aria-label="Breadcrumb"><ol>{"".join(items)}</ol></nav><!-- /crumbs -->'


def replace_block(s, start, end, new, anchor_before=None, anchor_after=None):
    """Swap the text between two markers, or put it in place the first time."""
    a, b = s.find(start), s.find(end)
    if a != -1 and b != -1:
        return s[:a] + new + s[b + len(end):]
    if anchor_before:
        i = s.index(anchor_before)
        return s[:i] + new + "\n" + s[i:]
    i = s.index(anchor_after) + len(anchor_after)
    return s[:i] + new + s[i:]


# ------------------------------------------------------------ links between pages

MODELS_LINKS = ('<!-- links --><nav class="foot-links" aria-label="More from Lockedmind">'
                '<a href="./">Lockedmind Models</a><a href="models.html">Browse models</a>'
                '<a href="./#how">How it works</a><a href="./#faq">Questions</a>'
                '<a href="app/">Lockedmind app</a><a href="app/chat.html">Open Lockedmind in your browser</a>'
                '</nav><!-- /links -->')
APP_LINKS = ('<!-- links --><p class="foot-links"><a href="chat.html">Open Lockedmind in your browser</a> · '
             '<a href="../models.html">Browse models</a></p><!-- /links -->')
DOC_LINKS = ('<!-- links --><footer class="doc-foot"><nav aria-label="More from Lockedmind">'
             '<a href="./">Lockedmind</a><a href="chat.html">Open Lockedmind in your browser</a>'
             '<a href="../">Lockedmind Models</a><a href="privacy.html">Privacy Policy</a><a href="support.html">Support</a>'
             '</nav></footer><!-- /links -->')


# ------------------------------------------------- the model list, without JavaScript

def prerender(models_html):
    data = json.loads((WEB / "catalog.json").read_text())
    makers = data["makers"]
    top = sorted(data["models"], key=lambda m: -(m.get("score") or 0))[:60]
    kinds = {"chat": "chat", "code": "code", "vision": "photos", "image": "pictures", "reason": "reasoning", "audio": "audio"}
    rows = []
    for m in top:
        maker = m.get("maker") or makers.get(m.get("org"), {}).get("name") or m.get("org", "")
        size = f'{m["b"]:g}B' if m.get("b") else ""
        uses = ", ".join(kinds.get(k, k) for k in m.get("kinds", []))
        bits = " · ".join(x for x in (maker, size, uses) if x)
        about = f' — {html.escape(m["about"])}' if m.get("about") else ""
        rows.append(f'<li><a href="models.html?q={html.escape(m["name"], quote=True).replace(" ", "+")}">'
                    f'{html.escape(m["name"])}</a> <span>({html.escape(bits)})</span>{about}</li>')
    # In <noscript>: browsers that run site.js never draw it (and site.js replaces it), while
    # crawlers and readers without JavaScript get a real list instead of an empty page.
    block = ('<!-- prerender: popular models as plain HTML --><noscript><section class="prerendered">'
             '<h2 class="row-title">Popular models</h2><p>Searching and filtering need JavaScript; here are the most popular models.</p>'
             '<ul>' + "".join(rows) + "</ul></section></noscript><!-- /prerender -->")
    return replace_block(models_html, "<!-- prerender", "<!-- /prerender -->", block, anchor_after='<div id="groups">')


# ------------------------------------------------------------------ site files

def sitemap():
    urls = []
    for p in PAGES:
        f = WEB / p["file"]
        mod = date.fromtimestamp(f.stat().st_mtime).isoformat()
        urls.append(f"  <url><loc>{p['url']}</loc><lastmod>{mod}</lastmod></url>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
            + "\n".join(urls) + "\n</urlset>\n")


ROBOTS = f"""# Lockedmind: search engines and AI crawlers are all welcome.
# (Crawlers only read this file at the root of a domain, so it takes effect once
# the sites have their own domain; until then, submit the sitemap directly.)
User-agent: *
Allow: /

Sitemap: {BASE}sitemap.xml
"""

LLMS = f"""# Lockedmind

> Lockedmind is private AI that runs on your own device. The Lockedmind app chats, writes code and makes pictures inside your web browser, on your own computer: nothing you type is sent to a server, it needs no account, and it is free. Lockedmind Models is a guide to AI models you can download and run yourself, in plain words.

Lockedmind isn't affiliated with any AI company or model maker. Models download straight from where their makers publish them (Hugging Face, Ollama or LM Studio), never through Lockedmind.

## Lockedmind
- [Lockedmind]({BASE}app/): what happens to your data in cloud AI, with cited sources, and how on-device AI avoids it
- [Open Lockedmind in your browser]({BASE}app/chat.html): the app itself; it downloads a model once, then works offline
- [Privacy policy]({BASE}app/privacy.html): for Lockedmind for iPhone, which is not yet on the App Store
- [Support]({BASE}app/support.html): for Lockedmind for iPhone

## Lockedmind Models
- [Lockedmind Models]({BASE}): AI models you can run yourself, and how to get started
- [Browse models]({BASE}models.html): search by name or use, filter by what fits your computer and who made it; each model shows its licence in plain words
- [Model catalogue (JSON)]({BASE}catalog.json): every model listed, with its maker, size, licence and where to download it

## Optional
- [Source code](https://github.com/yenxu0872-max/lockedmind): the websites and apps
"""

NOT_FOUND = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Page not found — Lockedmind</title>
<meta name="description" content="This page doesn't exist. Find your way to Lockedmind or Lockedmind Models.">
<meta name="robots" content="noindex">
<link rel="icon" type="image/png" sizes="32x32" href="{BASE}favicon-32.png">
<link rel="stylesheet" href="{BASE}bits.css?v=1">
<style>
@font-face{{font-family:'Geist';src:url('{BASE}fonts/Geist-Variable.woff2') format('woff2');font-weight:100 900;font-display:swap}}
:root{{--bg:#fff;--text:#1d1d1f;--muted:#6e6e73;--line:#e5e5ea;--card:#f5f5f7;--link:#5b3fd9;color-scheme:light dark}}
@media (prefers-color-scheme:dark){{:root{{--bg:#050507;--text:#f5f5f7;--muted:#8e8e93;--line:#26262b;--card:#111114;--link:#b49bff}}}}
*{{box-sizing:border-box}}
body{{margin:0;min-height:100vh;display:grid;place-items:center;background:var(--bg);color:var(--text);font:17px/1.6 'Geist',system-ui,-apple-system,sans-serif;-webkit-font-smoothing:antialiased;padding:32px 20px}}
main{{max-width:520px;text-align:center}}
.fuzzy{{font:800 clamp(110px,24vw,190px)/1 'Geist',system-ui,sans-serif;letter-spacing:-.04em;color:var(--text);margin:0 auto 18px}}
h1{{font-size:clamp(30px,6vw,40px);line-height:1.1;letter-spacing:-.025em;margin:0 0 12px;font-weight:650}}
p{{color:var(--muted);margin:0 0 28px}}
nav{{display:flex;flex-wrap:wrap;gap:10px;justify-content:center}}
nav a{{text-decoration:none;color:var(--text);background:var(--card);border:1px solid var(--line);border-radius:999px;padding:10px 18px;font-weight:550;font-size:15px}}
nav a:first-child{{background:linear-gradient(120deg,#ac77fa,#00aee9);border-color:transparent;color:#fff}}
</style>
</head>
<body>
<main>
  <div class="fuzzy" data-fuzzy aria-hidden="true">404</div>
  <h1>This page isn't here</h1>
  <p>The address may be mistyped, or the page has moved. These will get you back on track.</p>
  <nav aria-label="Where to go">
    <a href="{BASE}app/">Lockedmind</a>
    <a href="{BASE}app/chat.html">Open Lockedmind in your browser</a>
    <a href="{BASE}">Lockedmind Models</a>
    <a href="{BASE}models.html">Browse models</a>
  </nav>
</main>
<script src="{BASE}bits.js?v=1" defer></script>
</body>
</html>
"""


# ------------------------------------------------------------------ run

def write(path, content):
    path = WEB / path
    old = path.read_text() if path.exists() else None
    if old == content:
        return False
    if CHECK:
        print(f"  ✗ {path.relative_to(WEB)} is out of date — run web/_build/seo.py")
        return True
    path.write_text(content)
    print(f"  wrote {path.relative_to(WEB)}")
    return True


def main():
    stale = False
    for page in PAGES:
        f = WEB / page["file"]
        s = f.read_text()
        # tags this script now owns, once written by hand
        s = re.sub(r'\n?<link rel="canonical" href="[^"]*">(?![^\n]*seo)', "", s) if "<!-- seo" not in s else s
        if "<!-- seo" not in s:
            s = re.sub(r'\n<meta (?:property="og:[^"]+"|name="twitter:[^"]+") content="[^"]*">', "", s)
            s = re.sub(r'\n<link rel="apple-touch-icon" href="[^"]*">', "", s)
        s = replace_block(s, "<!-- seo", "<!-- /seo -->", head_block(page, s), anchor_before="</head>")
        if page["crumbs"]:
            if page["kind"] == "models-browse":
                s = replace_block(s, "<!-- crumbs -->", "<!-- /crumbs -->", crumbs_nav(page), anchor_before="<h1>Find any AI model</h1>")
            else:
                s = replace_block(s, "<!-- crumbs -->", "<!-- /crumbs -->", crumbs_nav(page), anchor_before='<p class="kicker">')
        if page["kind"] in ("models-home", "models-browse"):
            s = replace_block(s, "<!-- links -->", "<!-- /links -->", MODELS_LINKS,
                              anchor_after='<p>Private AI you run yourself.</p>')
        if page["kind"] == "app-home":
            s = replace_block(s, "<!-- links -->", "<!-- /links -->", APP_LINKS,
                              anchor_after='<p><a href="../">Lockedmind Models</a> — every model worth trying, and how to get it.</p>')
        if page["kind"] == "doc":
            s = replace_block(s, "<!-- links -->", "<!-- /links -->", DOC_LINKS, anchor_after="</main>")
        if page["kind"] == "models-browse":
            s = prerender(s)
        # the head block depends on the page text, so build it once more from the settled page
        s = replace_block(s, "<!-- seo", "<!-- /seo -->", head_block(page, s))
        stale |= write(page["file"], s)
    stale |= write("robots.txt", ROBOTS)
    stale |= write("sitemap.xml", sitemap())
    stale |= write("llms.txt", LLMS)
    stale |= write("404.html", NOT_FOUND)
    # the app keeps its own copy of the motion bits (the sites can be published apart)
    for name in ("bits.js", "bits.css"):
        stale |= write("app/" + name, (WEB / name).read_text())
    if CHECK and stale:
        sys.exit(1)
    if not stale:
        print("  everything up to date")


if __name__ == "__main__":
    main()
