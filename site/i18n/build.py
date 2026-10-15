#!/usr/bin/env python3
"""Writes the website in every language: site/<lang>/index.html from site/index.html (English).

Translatable parts of index.html are marked:
  data-i18n="key"                    the element's inner HTML
  data-i18n-attr="attr:key;attr:key" attribute values
  data-i18n-url / data-i18n-locale   canonical URL, og:url and og:locale
Translations live in site/i18n/<lang>.json: "html" (keys above), "script" (strings the page's
scripts ask for: the demo panel, the copy buttons; English text as key) and a few page settings.

    python3 site/i18n/build.py           build every language
    python3 site/i18n/build.py --check   only report missing or unused keys (exit 1 if any)

Standard library only, so it runs anywhere (GitHub Pages' workflow, any Mac).
"""
import html
import json
import re
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent
I18N = SITE / "i18n"
BASE_URL = "https://s4mu3ldemolidor.github.io/stash/"
LANGUAGES = ["pt-br", "es", "fr"]
SCRIPTS = ["scripts/demo.js", "scripts/main.js"]
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}

START_TAG = re.compile(r"<([a-zA-Z][a-zA-Z0-9]*)\b([^>]*)>")
I18N_ATTR = re.compile(r'\sdata-i18n="([^"]+)"')
I18N_ATTRS = re.compile(r'\sdata-i18n-attr="([^"]+)"')
SCRIPT_STRING = re.compile(r'\btr\("((?:[^"\\]|\\.)*)"')


def inner_end(page, tag, start):
    """Where the element whose content starts at `start` closes (same-name nesting counted)."""
    depth = 1
    pattern = re.compile(rf"<(/?){tag}\b[^>]*>", re.IGNORECASE)
    for match in pattern.finditer(page, start):
        if match.group(1):
            depth -= 1
            if depth == 0:
                return match.start(), match.end()
        elif not match.group(0).endswith("/>"):
            depth += 1
    raise ValueError(f"<{tag}> at {start} never closes")


def html_keys(page):
    keys = set()
    for match in START_TAG.finditer(page):
        attributes = match.group(2)
        if key := I18N_ATTR.search(attributes):
            keys.add(key.group(1))
        if spec := I18N_ATTRS.search(attributes):
            keys.update(part.split(":", 1)[1] for part in spec.group(1).split(";"))
    return keys


def script_keys():
    keys = set()
    for name in SCRIPTS:
        keys.update(json.loads(f'"{s}"') for s in SCRIPT_STRING.findall((SITE / name).read_text()))
    return keys


def translate(page, strings, language):
    """Replaces marked content and attributes, innermost-last so offsets stay valid."""
    edits = []
    for match in START_TAG.finditer(page):
        tag, attributes = match.group(1).lower(), match.group(2)
        new_attributes = attributes
        if spec := I18N_ATTRS.search(attributes):
            for part in spec.group(1).split(";"):
                name, key = part.split(":", 1)
                value = html.escape(strings[key], quote=True)
                new_attributes, count = re.subn(rf'(\s{name}=")[^"]*(")', lambda m: m.group(1) + value + m.group(2), new_attributes)
                if not count:
                    raise ValueError(f"{key}: <{tag}> has no {name} attribute")
        if new_attributes != attributes:
            edits.append((match.start(2), match.end(2), new_attributes))
        if key := I18N_ATTR.search(attributes):
            if tag in VOID:
                raise ValueError(f"{key.group(1)}: <{tag}> has no content")
            end, _ = inner_end(page, tag, match.end())
            edits.append((match.end(), end, strings[key.group(1)]))
    # Content edits contain no other edits' ranges except attributes of nested elements, so
    # apply from the end and skip edits inside a replaced range.
    edits.sort(key=lambda e: (e[0], -e[1]))
    result, cursor = [], 0
    for start, end, text in edits:
        if start < cursor:
            continue
        result.append(page[cursor:start])
        result.append(text)
        cursor = end
    result.append(page[cursor:])
    return "".join(result)


def localize_page(page, language, data):
    page = translate(page, data["html"], language)
    page = page.replace('<html lang="en">', f'<html lang="{data["lang"]}">', 1)
    url = f"{BASE_URL}{language}/"
    page = re.sub(r'(<[^>]*\s(?:href|content)=")' + re.escape(BASE_URL) + r'("[^>]*\sdata-i18n-url)', rf"\g<1>{url}\g<2>", page)
    page = re.sub(r'(content=")en_US("[^>]*data-i18n-locale)', rf'\g<1>{data["locale"]}\g<2>', page)

    # Language menu: links one level up, the current language marked.
    page = page.replace(' aria-current="page">English', ">English", 1)
    page = re.sub(r'href="\./"( hreflang="en")', r'href="../"\1', page)
    page = re.sub(r'href="(pt-br|es|fr)/"', r'href="../\1/"', page)
    page = re.sub(rf'(data-lang="{language}")>', r'\1 aria-current="page">', page)
    page = page.replace("<span data-lang-code>EN</span>", f'<span data-lang-code>{data["code"]}</span>', 1)

    # Everything else relative lives one level up.
    page = re.sub(r'((?:src|href|poster)=")(?!https?:|#|\.\./|mailto:|data:)', r"\1../", page)

    # Strings for the scripts (the demo panel, the copy buttons), before the first script.
    script = json.dumps(data["script"], ensure_ascii=False, separators=(",", ":"))
    page = page.replace('<script src="../scripts/demo.js"', f"<script>window.STASH_I18N={script}</script>\n  <script src=\"../scripts/demo.js\"", 1)
    return page


def main():
    check_only = "--check" in sys.argv
    source = (SITE / "index.html").read_text()
    needed_html, needed_script = html_keys(source), script_keys()
    problems = 0
    for language in LANGUAGES:
        data = json.loads((I18N / f"{language}.json").read_text())
        for section, needed in (("html", needed_html), ("script", needed_script)):
            have = set(data[section])
            for key in sorted(needed - have):
                print(f"{language}: missing {section} key {key!r}")
            # Script strings may also be asked for indirectly (tr(label)); only html can be unused.
            for key in sorted(have - needed) if section == "html" else []:
                print(f"{language}: unused html key {key!r}")
            problems += len(needed - have) + (len(have - needed) if section == "html" else 0)
        if check_only or problems:
            continue
        out = SITE / language
        out.mkdir(exist_ok=True)
        (out / "index.html").write_text(localize_page(source, language, data))
        print(f"{language}: {len(data['html'])} + {len(data['script'])} strings → site/{language}/index.html")
    if problems:
        sys.exit(1)
    if check_only:
        print(f"OK: {len(needed_html)} page strings, {len(needed_script)} script strings, {len(LANGUAGES)} languages")


if __name__ == "__main__":
    main()
