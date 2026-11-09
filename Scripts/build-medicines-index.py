#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""
Builds the offline medicines index bundled with the app from open data of the Czech SÚKL and the
Slovak ŠÚKL (specification, chapter 11). Standard library only. Run before a release:

    python3 Scripts/build-medicines-index.py            # downloads both sources (~110 MB)
    python3 Scripts/build-medicines-index.py --cache DIR  # keeps / reuses the downloads in DIR

Output: Vzato/Resources/Medicines.index, raw DEFLATE (Apple's NSData .zlib), UTF-8 lines:
    #vzato-medicines<TAB>1<TAB>cz=<yyyy-mm-dd><TAB>sk=<yyyy-mm-dd>
    <source><TAB><code><TAB><name><TAB><strength><TAB><form><TAB><pack><TAB><marketed>
source is cz or sk; marketed is 1 (supplied to pharmacies in the last 6 months), 0, or empty
(unknown, Slovakia has no such flag). Only medicines with a valid registration.

Sources and terms:
  CZ  https://opendata.sukl.gov.cz/katalog-otevrenych-dat/databaze-lecivych-pripravku-dlp
      terms https://opendata.sukl.gov.cz/podminky-uziti-otevrenych-dat (credit SÚKL)
  SK  https://api.sukl.sk/json/lieky_ui42.php  (CC0, Národný katalóg otvorených dát)
"""
import csv, datetime, io, json, os, re, sys, urllib.request, zipfile, zlib

CZ_PAGE = "https://opendata.sukl.gov.cz/katalog-otevrenych-dat/databaze-lecivych-pripravku-dlp"
SK_API = "https://api.sukl.sk/json/lieky_ui42.php"
OUT = os.path.join(os.path.dirname(__file__), "..", "Vzato", "Resources", "Medicines.index")
AGENT = {"User-Agent": "Vzato medicines index builder (https://vzato.app)"}


def fetch(url, cache, name):
    path = os.path.join(cache, name) if cache else None
    if path and os.path.exists(path):
        return open(path, "rb").read()
    print("downloading", url, file=sys.stderr)
    with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=300) as response:
        data = response.read()
    if path:
        open(path, "wb").write(data)
    return data


def clean(text):
    return re.sub(r"\s+", " ", (text or "").replace("\t", " ")).strip()


def czech(cache):
    page = fetch(CZ_PAGE, cache, "dlp.html").decode("utf-8", "replace")
    links = sorted(set(re.findall(r'https://opendata\.sukl\.gov\.cz/soubory/SOD\d{8}/DLP(\d{8})\.zip', page)))
    if not links:
        sys.exit("No DLP ZIP link on the SÚKL dataset page; check " + CZ_PAGE)
    stamp = links[-1]
    url = f"https://opendata.sukl.gov.cz/soubory/SOD{stamp}/DLP{stamp}.zip"
    archive = zipfile.ZipFile(io.BytesIO(fetch(url, cache, f"DLP{stamp}.zip")))

    def rows(name):
        text = archive.read(name).decode("cp1250")
        return csv.DictReader(io.StringIO(text), delimiter=";")

    forms = {r["FORMA"]: r["NAZEV"] for r in rows("dlp_formy.csv")}
    result = []
    for r in rows("dlp_lecivepripravky.csv"):
        if r.get("REG") not in ("R", "B"):
            continue
        result.append(("cz", clean(r["KOD_SUKL"]), clean(r["NAZEV"]), clean(r["SILA"]),
                       clean(forms.get(r["FORMA"], r["FORMA"])), clean(r["BALENI"]),
                       "1" if r.get("DODAVKY") == "1" else "0"))
    date = f"{stamp[:4]}-{stamp[4:6]}-{stamp[6:]}"
    return result, date


def slovak(cache):
    text = fetch(SK_API, cache, "lieky_ui42.html").decode("utf-8", "replace")
    start = text.index("<body>") + len("<body>") if "<body>" in text else 0
    data, _ = json.JSONDecoder().raw_decode(text[start:].lstrip())
    result = []
    for r in data:
        name = clean(r.get("lie_nazov"))
        code = clean(r.get("lie_kod"))
        if not name or not code:
            continue
        # Renamed forms carry the old name in brackets: "Granulát (… - platné do okt2020)".
        form = re.sub(r"\s*\([^()]*(platné|používané)[^()]*\)\s*$", "", clean(r.get("form_nazov")))
        result.append(("sk", code, name, clean(r.get("lie_sila")), form,
                       clean(r.get("lie_balenie")) or clean(r.get("lie_doplnok")), ""))
    return result, datetime.date.today().isoformat()


def main():
    cache = None
    if "--cache" in sys.argv:
        cache = sys.argv[sys.argv.index("--cache") + 1]
        os.makedirs(cache, exist_ok=True)
    cz, cz_date = czech(cache)
    sk, sk_date = slovak(cache)
    lines = [f"#vzato-medicines\t1\tcz={cz_date}\tsk={sk_date}"]
    lines += ["\t".join(row) for row in sorted(set(cz + sk), key=lambda r: (r[0], r[2].lower(), r[3], r[1]))]
    raw = ("\n".join(lines) + "\n").encode("utf-8")
    deflate = zlib.compressobj(9, zlib.DEFLATED, -15)
    packed = deflate.compress(raw) + deflate.flush()
    open(OUT, "wb").write(packed)
    print(f"cz {len(cz)} ({cz_date}), sk {len(sk)} ({sk_date}): {len(raw) // 1024} KB -> {len(packed) // 1024} KB "
          f"in {os.path.relpath(OUT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
