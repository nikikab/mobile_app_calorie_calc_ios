#!/usr/bin/env python3
"""Converts the Android strings.xml files into one String Catalog (Localizable.xcstrings).

Keys are the Android resource names, so `String(localized: "tab_diary")` / `Text("tab_diary")` works.
Usage: strings_to_xcstrings.py <android res dir> <output .xcstrings>
"""
import json, re, sys
import xml.etree.ElementTree as ET
from pathlib import Path

LANGS = {"": "en", "bg": "bg", "de": "de", "es": "es", "fr": "fr"}

def convert(text):
    text = text.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n").replace("\\@", "@").replace("\\?", "?")
    text = re.sub(r"%(\d+)\$d", r"%\1$lld", text)
    text = re.sub(r"%(\d+)\$s", r"%\1$@", text)
    return text

def load(path):
    out = {}
    for el in ET.parse(path).getroot().iter("string"):
        out[el.get("name")] = (convert(el.text or ""), el.get("translatable") != "false")
    return out

def main(res, dest):
    res = Path(res)
    per_lang = {code: load(res / (f"values-{a}" if a else "values") / "strings.xml") for a, code in LANGS.items()}
    strings = {}
    for key, (_, translatable) in per_lang["en"].items():
        entry = {"extractionState": "manual", "localizations": {}}
        if not translatable:
            entry["shouldTranslate"] = False
        for code, table in per_lang.items():
            if key in table:
                entry["localizations"][code] = {"stringUnit": {"state": "translated", "value": table[key][0]}}
        strings[key] = entry
    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    Path(dest).write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{len(strings)} keys, languages: {', '.join(LANGS.values())}")

if __name__ == "__main__":
    main(*sys.argv[1:3])
