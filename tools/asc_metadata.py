#!/usr/bin/env python3
"""Fills in the App Store Connect product page from store/metadata.json through the App Store Connect API.

  asc_metadata.py inspect   only reads: prints the app, its editable version, build and what is filled in
  asc_metadata.py apply     writes texts, categories, review information, screenshots and selects the newest build

It never submits the version for review; that stays a manual step in App Store Connect.
Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (the .p8 contents); for apply also GEMINI_REVIEW_KEY and, optionally,
REVIEW_PHONE (the contact phone for App Review). Needs the `cryptography` package.
"""
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

BASE = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "com.nikikabadzhov.kalocalc"
ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "store"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token() -> str:
    key = serialization.load_pem_private_key(os.environ["ASC_KEY_P8"].encode(), password=None)
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    claims = {"iss": os.environ["ASC_ISSUER_ID"], "iat": int(time.time()), "exp": int(time.time()) + 15 * 60, "aud": "appstoreconnect-v1"}
    signing = b64(json.dumps(header).encode()) + "." + b64(json.dumps(claims).encode())
    r, s = decode_dss_signature(key.sign(signing.encode(), ec.ECDSA(hashes.SHA256())))
    return signing + "." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))


TOKEN = None


def call(method, path, body=None, allow=()):
    global TOKEN
    TOKEN = TOKEN or token()
    req = urllib.request.Request(path if path.startswith("http") else BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header("Authorization", "Bearer " + TOKEN)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        if e.code in allow:
            return {}
        detail = e.read().decode(errors="replace")
        sys.exit(f"{method} {path} failed: HTTP {e.code}\n{detail[:1500]}")


def data(method, path, body=None, allow=()):
    return call(method, path, body, allow).get("data")


def attrs(item):
    return (item or {}).get("attributes", {})


def say(text):
    print(text, flush=True)


def find_app():
    apps = data("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}") or []
    if not apps:
        sys.exit(f"No app with bundle id {BUNDLE_ID} in App Store Connect.")
    return apps[0]["id"], attrs(apps[0]).get("name")


def find_version(app_id):
    versions = data("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=10") or []
    for v in versions:
        a = attrs(v)
        say(f"  version {a.get('versionString')}: {a.get('appVersionState') or a.get('appStoreState')}")
    for v in versions:
        a = attrs(v)
        if (a.get("appVersionState") or a.get("appStoreState")) in EDITABLE:
            return v["id"], a.get("versionString")
    sys.exit("No editable iOS version found (it must be in 'Prepare for Submission').")


def newest_build(app_id):
    builds = data("GET", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10") or []
    for b in builds:
        a = attrs(b)
        say(f"  build {a.get('version')}: {a.get('processingState')}{' (expired)' if a.get('expired') else ''} uploaded {a.get('uploadedDate')}")
    for b in builds:
        a = attrs(b)
        if a.get("processingState") == "VALID" and not a.get("expired"):
            return b["id"], a.get("version")
    return None, None


def localizations(version_id):
    items = data("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50") or []
    return {attrs(i)["locale"]: i["id"] for i in items}


def info_localizations(app_id):
    infos = data("GET", f"/v1/apps/{app_id}/appInfos") or []
    info = next((i for i in infos if attrs(i).get("appStoreState") in EDITABLE or attrs(i).get("state") in EDITABLE), infos[0])
    items = data("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations?limit=50") or []
    return info["id"], {attrs(i)["locale"]: i["id"] for i in items}


def inspect(app_id, version_id):
    say("Version localizations:")
    for loc, lid in localizations(version_id).items():
        a = attrs(data("GET", f"/v1/appStoreVersionLocalizations/{lid}"))
        say(f"  {loc}: description {len(a.get('description') or '')} chars, keywords {len(a.get('keywords') or '')}, "
            f"supportUrl {a.get('supportUrl')}")
        for s in data("GET", f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets") or []:
            shots = data("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots") or []
            say(f"    screenshots {attrs(s).get('screenshotDisplayType')}: {len(shots)}")
    _, infos = info_localizations(app_id)
    for loc, iid in infos.items():
        a = attrs(data("GET", f"/v1/appInfoLocalizations/{iid}"))
        say(f"  info {loc}: name {a.get('name')!r}, subtitle {a.get('subtitle')!r}, privacy {a.get('privacyPolicyUrl')}")
    detail = data("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail", allow=(404,))
    a = attrs(detail)
    say(f"  review detail: contact {a.get('contactFirstName')} {a.get('contactLastName')}, phone set: {bool(a.get('contactPhone'))}, "
        f"notes {len(a.get('notes') or '')} chars")


def upsert(kind_path, kind_type, existing_id, attributes, parent=None):
    if existing_id:
        data("PATCH", f"{kind_path}/{existing_id}", {"data": {"type": kind_type, "id": existing_id, "attributes": attributes}})
        return existing_id
    body = {"data": {"type": kind_type, "attributes": attributes}}
    if parent:
        body["data"]["relationships"] = parent
    return data("POST", kind_path, body)["id"]


def upload_screenshots(loc_id, files):
    sets = data("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets") or []
    sset = next((s for s in sets if attrs(s).get("screenshotDisplayType") == "APP_IPHONE_67"), None)
    if sset:
        set_id = sset["id"]
        for old in data("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots") or []:
            data("DELETE", f"/v1/appScreenshots/{old['id']}")
    else:
        set_id = data("POST", "/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})["id"]
    for path in files:
        blob = path.read_bytes()
        shot = data("POST", "/v1/appScreenshots", {"data": {
            "type": "appScreenshots", "attributes": {"fileName": path.name, "fileSize": len(blob)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
        for op in attrs(shot)["uploadOperations"]:
            chunk = blob[op["offset"]: op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], method=op["method"], data=chunk)
            for h in op["requestHeaders"]:
                req.add_header(h["name"], h["value"])
            urllib.request.urlopen(req, timeout=120).read()
        data("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {
            "type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
        say(f"    uploaded {path.name}")


def apply(app_id, version_id):
    meta = json.loads((STORE / "metadata.json").read_text())
    locs = localizations(version_id)
    info_id, info_locs = info_localizations(app_id)

    for locale, m in meta["locales"].items():
        say(f"Locale {locale}")
        loc_id = upsert("/v1/appStoreVersionLocalizations", "appStoreVersionLocalizations", locs.get(locale),
                        {k: m[k] for k in ("description", "keywords", "promotionalText", "supportUrl")} | ({} if locs.get(locale) else {"locale": locale}),
                        {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}})
        upsert("/v1/appInfoLocalizations", "appInfoLocalizations", info_locs.get(locale),
               {k: m[k] for k in ("name", "subtitle", "privacyPolicyUrl")} | ({} if info_locs.get(locale) else {"locale": locale}),
               {"appInfo": {"data": {"type": "appInfos", "id": info_id}}})
        files = sorted((STORE / "screenshots" / locale).glob("*.png"))
        say(f"  {len(files)} screenshots")
        upload_screenshots(loc_id, files)

    say("Categories and copyright")
    data("PATCH", f"/v1/appInfos/{info_id}", {"data": {"type": "appInfos", "id": info_id, "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": meta["primaryCategory"]}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": meta["secondaryCategory"]}}}}})
    data("PATCH", f"/v1/appStoreVersions/{version_id}", {"data": {"type": "appStoreVersions", "id": version_id,
                                                                  "attributes": {"copyright": meta["copyright"]}}})

    say("App Review information")
    notes = (STORE / "review-notes.txt").read_text().replace("{GEMINI_KEY}", os.environ["GEMINI_REVIEW_KEY"])
    review = dict(meta["review"], demoAccountRequired=False, notes=notes)
    if os.environ.get("REVIEW_PHONE"):
        review["contactPhone"] = os.environ["REVIEW_PHONE"]
    else:
        say("  (no REVIEW_PHONE given: the contact phone is left as it is and must be filled in by hand)")
    detail = data("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail", allow=(404,))
    upsert("/v1/appStoreReviewDetails", "appStoreReviewDetails", (detail or {}).get("id"), review,
           {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}})

    build_id, build = newest_build(app_id)
    if build_id:
        say(f"Selecting build {build}")
        call("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build", {"data": {"type": "builds", "id": build_id}})
    else:
        say("No processed build to select yet.")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "inspect"
    app_id, name = find_app()
    say(f"App {name} ({app_id})")
    version_id, version = find_version(app_id)
    say(f"Editable version {version} ({version_id})")
    newest_build(app_id)
    if mode == "inspect":
        inspect(app_id, version_id)
    elif mode == "apply":
        apply(app_id, version_id)
        say("Done. Check the page in App Store Connect, fill in App Privacy and the age rating, then submit.")
    else:
        sys.exit("usage: asc_metadata.py inspect|apply")


main()
