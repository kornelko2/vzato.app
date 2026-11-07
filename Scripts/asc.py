#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""
App Store Connect API helper for Vzato. Standard library + the openssl CLI, no packages.

    export ASC_ISSUER_ID=…            # App Store Connect › Users and Access › Integrations
    export ASC_KEY_ID=<your key id>
    python3 Scripts/asc.py check      # sign in, find the app by bundle ID, show its state
    python3 Scripts/asc.py metadata   # names, subtitles, texts, categories in all languages
    python3 Scripts/asc.py beta       # TestFlight description, what to test, feedback email

The key is read from ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 and never printed.
The app record itself must exist already: Apple's API cannot create apps.
"""
import base64, json, os, re, subprocess, sys, tempfile, time, urllib.error, urllib.request

BUNDLE_ID = "app.vzato"
KEY_ID = os.environ.get("ASC_KEY_ID", "")
ISSUER = os.environ.get("ASC_ISSUER_ID", "")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
API = "https://api.appstoreconnect.apple.com/v1"
METADATA = os.path.join(os.path.dirname(__file__), "..", "Docs", "app-store", "metadata.md")

# metadata.md section heading -> App Store locale
LOCALES = {"Čeština": "cs", "Slovenčina": "sk", "English": "en-US", "Magyar": "hu"}
SITE = "https://vzato.app"


def support_url(locale: str) -> str:
    """The help pages in the store language."""
    return f"{SITE}/{locale.split('-')[0]}/help/"

PRIVACY_URL = os.environ.get("VZATO_PRIVACY_URL", "https://vzato.app/privacy")


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """ECDSA signature from openssl (DER) to the 64-byte r||s form JWT wants."""
    i = 2
    parts = []
    for _ in range(2):
        assert der[i] == 0x02
        length = der[i + 1]
        value = der[i + 2:i + 2 + length].lstrip(b"\x00")
        parts.append(value.rjust(32, b"\x00"))
        i += 2 + length
    return b"".join(parts)


def token() -> str:
    if not ISSUER:
        sys.exit("Set ASC_ISSUER_ID (App Store Connect › Users and Access › Integrations › App Store Connect API).")
    if not KEY_ID:
        sys.exit("Set ASC_KEY_ID to the ID of your App Store Connect API key.")
    if not os.path.exists(KEY_PATH):
        sys.exit(f"Key not found: {KEY_PATH}")
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": ISSUER, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}".encode()
    with tempfile.NamedTemporaryFile() as f:
        f.write(signing_input)
        f.flush()
        der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH, f.name],
                             check=True, capture_output=True).stdout
    return f"{signing_input.decode()}.{b64url(der_to_raw(der))}"


TOKEN = None


def call(method: str, path: str, body=None):
    global TOKEN
    TOKEN = TOKEN or token()
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method,
                                     headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        try:
            detail = "; ".join(e.get("detail", e.get("title", "")) for e in json.loads(detail).get("errors", []))
        except Exception:
            pass
        raise SystemExit(f"{method} {path} -> HTTP {error.code}: {detail}")


def find_app():
    apps = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    if not apps:
        sys.exit(f"No app with bundle ID {BUNDLE_ID}. Create it in App Store Connect first (the API cannot).")
    return apps[0]


def parse_metadata():
    text = open(METADATA, encoding="utf-8").read()
    result = {}
    for section in re.split(r"\n## ", text)[1:]:
        heading = section.split("\n", 1)[0]
        locale = next((code for name, code in LOCALES.items() if heading.startswith(name)), None)
        if not locale:
            continue
        def field(label, multiline=False):
            if multiline:
                m = re.search(rf"\*\*{label}\*\*\n(.+?)(?:\n---|\Z)", section, re.S)
            else:
                m = re.search(rf"\*\*{label}:\*\* (.+)", section) or re.search(rf"\*\*{label}\*\*\n(.+)", section)
            return m.group(1).strip() if m else ""
        result[locale] = {
            "name": field("Name"),
            "subtitle": field("Subtitle"),
            "promotionalText": field("Promotional text"),
            "keywords": field("Keywords"),
            "description": field("Description", multiline=True),
        }
    return result


def upsert(collection_path, existing, locale, attributes, create_type, relation, relation_type, relation_id):
    current = next((item for item in existing if item["attributes"]["locale"] == locale), None)
    if current:
        call("PATCH", f"/{create_type}/{current['id']}",
             {"data": {"type": create_type, "id": current["id"], "attributes": attributes}})
        return "updated"
    call("POST", f"/{create_type}", {"data": {
        "type": create_type,
        "attributes": {"locale": locale, **attributes},
        "relationships": {relation: {"data": {"type": relation_type, "id": relation_id}}},
    }})
    return "created"


def cmd_check():
    app = find_app()
    attrs = app["attributes"]
    print(f"Signed in. App: {attrs.get('name')} ({attrs.get('bundleId')}), primary locale {attrs.get('primaryLocale')}, id {app['id']}")
    for info in call("GET", f"/apps/{app['id']}/appInfos")["data"]:
        print(f"  app info {info['id']}: {info['attributes'].get('appStoreState') or info['attributes'].get('state')}")
    for version in call("GET", f"/apps/{app['id']}/appStoreVersions")["data"]:
        a = version["attributes"]
        print(f"  version {a.get('versionString')} {a.get('platform')}: {a.get('appStoreState') or a.get('appVersionState')}")


def cmd_metadata():
    app = find_app()
    texts = parse_metadata()
    infos = call("GET", f"/apps/{app['id']}/appInfos")["data"]
    editable = [i for i in infos if (i["attributes"].get("appStoreState") or i["attributes"].get("state")) not in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION")]
    info = (editable or infos)[0]

    call("PATCH", f"/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": "MEDICAL"}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": "HEALTH_AND_FITNESS"}},
    }}})
    print("Categories: Medical, Health & Fitness")

    existing = call("GET", f"/appInfos/{info['id']}/appInfoLocalizations")["data"]
    for locale, t in texts.items():
        attributes = {"name": t["name"], "subtitle": t["subtitle"]}
        if PRIVACY_URL:
            attributes["privacyPolicyUrl"] = PRIVACY_URL
        state = upsert("", existing, locale, attributes, "appInfoLocalizations", "appInfo", "appInfos", info["id"])
        print(f"App information {locale}: {state} ({t['name']} / {t['subtitle']})")

    versions = call("GET", f"/apps/{app['id']}/appStoreVersions")["data"]
    for version in versions:
        a = version["attributes"]
        if (a.get("appStoreState") or a.get("appVersionState")) in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION"):
            continue
        existing = call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
        for locale, t in texts.items():
            attributes = {"description": t["description"], "keywords": t["keywords"],
                          "promotionalText": t["promotionalText"], "supportUrl": support_url(locale)}
            state = upsert("", existing, locale, attributes, "appStoreVersionLocalizations",
                           "appStoreVersion", "appStoreVersions", version["id"])
            print(f"Version {a.get('versionString')} {a.get('platform')} {locale}: {state}")


BETA_LOCALES = {"cs": ("cs – Popis bety", "cs – Co testovat"), "en-US": ("en – Beta description", "en – What to test")}
FEEDBACK_EMAIL = "info@vzato.app"


def beta_section(title: str) -> str:
    text = open(METADATA, encoding="utf-8").read()
    match = re.search(rf"^### {re.escape(title)}\n(.*?)(?=^#)", text, re.S | re.M)
    if not match:
        sys.exit(f"Missing section '### {title}' in metadata.md")
    return " ".join(match.group(1).split())


def cmd_beta():
    app = find_app()
    existing = call("GET", f"/apps/{app['id']}/betaAppLocalizations")["data"]
    for locale, (description_title, test_title) in BETA_LOCALES.items():
        attributes = {"description": beta_section(description_title), "feedbackEmail": FEEDBACK_EMAIL,
                      "marketingUrl": SITE, "privacyPolicyUrl": PRIVACY_URL}
        match = next((e for e in existing if e["attributes"]["locale"] == locale), None)
        if match:
            call("PATCH", f"/betaAppLocalizations/{match['id']}",
                 {"data": {"type": "betaAppLocalizations", "id": match["id"], "attributes": attributes}})
            print(f"Beta {locale}: updated")
        else:
            call("POST", "/betaAppLocalizations", {"data": {"type": "betaAppLocalizations",
                 "attributes": {**attributes, "locale": locale},
                 "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})
            print(f"Beta {locale}: created")
    # "What to test" belongs to each build; set it on the newest builds of every platform.
    builds = call("GET", f"/builds?filter[app]={app['id']}&sort=-uploadedDate&limit=2")["data"]
    for build in builds:
        notes = call("GET", f"/builds/{build['id']}/betaBuildLocalizations")["data"]
        for locale, (_, test_title) in BETA_LOCALES.items():
            what = beta_section(test_title)
            match = next((n for n in notes if n["attributes"]["locale"] == locale), None)
            if match:
                call("PATCH", f"/betaBuildLocalizations/{match['id']}",
                     {"data": {"type": "betaBuildLocalizations", "id": match["id"], "attributes": {"whatsNew": what}}})
            else:
                call("POST", "/betaBuildLocalizations", {"data": {"type": "betaBuildLocalizations",
                     "attributes": {"locale": locale, "whatsNew": what},
                     "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}}}})
        print(f"What to test: build {build['attributes']['version']} ({build['id'][:8]})")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    {"check": cmd_check, "metadata": cmd_metadata, "beta": cmd_beta}.get(command, lambda: sys.exit(__doc__))()
