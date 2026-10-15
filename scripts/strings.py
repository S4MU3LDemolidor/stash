#!/usr/bin/env python3
"""Stash's string tables (Support/Localization/<lang>.lproj/Localizable.strings).

The keys are the English text. The compiler lists every key the app uses (in .stringsdata
files, see scripts/check-strings.sh), so the tables can be checked against the code:

    strings.py check   DATA_DIR TABLES_DIR   missing or unused keys in any language → exit 1
    strings.py sync-en DATA_DIR TABLES_DIR   rewrite en.lproj from the code (key = value)
    strings.py missing DATA_DIR TABLES_DIR LANG   print the keys LANG still needs
"""
import json
import os
import re
import sys

ENTRY = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
HEADER = """/* Stash: English. Generated from the code by scripts/check-strings.sh sync-en; don't edit.
   Every other language translates these keys (the English text). */
"""


def unescape(text):
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), text)


def escape(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def code_keys(data_dir, sources="Sources/Stash/"):
    """Keys of the app's own sources (dependencies emit stringsdata too)."""
    keys = set()
    for name in os.listdir(data_dir):
        if not name.endswith(".stringsdata"):
            continue
        with open(os.path.join(data_dir, name), encoding="utf-8") as f:
            data = json.load(f)
        source = data.get("source", "")
        if sources not in source or not os.path.exists(source):
            continue
        for entry in data.get("tables", {}).get("Localizable", []):
            keys.add(entry["key"])
    return keys


def read_table(path):
    table = {}
    if not os.path.exists(path):
        return table
    in_comment = False
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            stripped = line.strip()
            if in_comment:
                in_comment = "*/" not in stripped
                continue
            if not stripped or stripped.startswith("//"):
                continue
            if stripped.startswith("/*"):
                in_comment = "*/" not in stripped
                continue
            match = ENTRY.match(stripped)
            if not match:
                sys.exit(f"{path}:{number}: can't read this line: {stripped}")
            key = unescape(match.group(1))
            if key in table:
                sys.exit(f"{path}:{number}: duplicate key {key!r}")
            table[key] = unescape(match.group(2))
    return table


def table_path(tables_dir, language):
    return os.path.join(tables_dir, f"{language}.lproj", "Localizable.strings")


def languages(tables_dir):
    return sorted(name[:-6] for name in os.listdir(tables_dir) if name.endswith(".lproj"))


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    command, data_dir, tables_dir = sys.argv[1:4]
    keys = code_keys(data_dir)
    if not keys:
        sys.exit(f"No strings found in {data_dir}; was the build run with -emit-localized-strings?")

    if command == "sync-en":
        with open(table_path(tables_dir, "en"), "w", encoding="utf-8") as f:
            f.write(HEADER)
            for key in sorted(keys, key=lambda k: (k.lower(), k)):
                f.write(f'"{escape(key)}" = "{escape(key)}";\n')
        print(f"en: {len(keys)} strings")
        return

    if command == "missing":
        table = read_table(table_path(tables_dir, sys.argv[4]))
        for key in sorted(keys - table.keys(), key=str.lower):
            print(key)
        return

    if command != "check":
        sys.exit(__doc__)
    problems = 0
    for language in languages(tables_dir):
        table = read_table(table_path(tables_dir, language))
        missing = sorted(keys - table.keys(), key=str.lower)
        unused = sorted(table.keys() - keys, key=str.lower)
        for key in missing:
            print(f"{language}: missing {key!r}")
        for key in unused:
            print(f"{language}: not used by the code {key!r}")
        problems += len(missing) + len(unused)
        print(f"{language}: {len(table)} strings" + (f", {len(missing)} missing, {len(unused)} unused" if missing or unused else ""))
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
