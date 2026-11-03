"""Refresh data/michelin_us.csv and data/michelin_tw.csv from the public michelin-my-maps dataset.

The dataset (github.com/ngshiheng/michelin-my-maps, MIT) collects every restaurant in the Michelin
Guide with its award, coordinates and Guide page. Run after a new guide comes out, then redeploy:

    python scripts/update_michelin.py
    python scripts/update_michelin.py --source path/to/michelin_my_maps.csv   # a file you downloaded
"""
import argparse
import csv
import io
import sys
import urllib.request
from pathlib import Path

SOURCE = "https://raw.githubusercontent.com/ngshiheng/michelin-my-maps/main/data/michelin_my_maps.csv"
DATA = Path(__file__).resolve().parents[1] / "data"
COLUMNS = ["name", "name_zh", "city", "distinction", "year", "lat", "lng", "url"]
AWARDS = {"3 Stars": "3 Stars", "2 Stars": "2 Stars", "1 Star": "1 Star",
          "Bib Gourmand": "Bib Gourmand", "Selected Restaurants": "Selected"}
MARKETS = {
    "us": lambda loc: loc.endswith(", USA"),
    "tw": lambda loc: "Taiwan" in loc,
}


def load(source: str) -> list[dict]:
    if source.startswith("http"):
        with urllib.request.urlopen(source, timeout=60) as resp:
            text = resp.read().decode("utf-8")
    else:
        text = Path(source).read_text(encoding="utf-8")
    return list(csv.DictReader(io.StringIO(text)))


def convert(row: dict) -> dict | None:
    award = AWARDS.get((row.get("Award") or "").strip())
    if not award or not row.get("Name"):
        return None
    return {
        "name": row["Name"].strip(),
        "name_zh": "",
        "city": (row.get("Location") or "").split(",")[0].strip(),
        "distinction": award,
        "year": "",
        "lat": row.get("Latitude", "").strip(),
        "lng": row.get("Longitude", "").strip(),
        "url": row.get("Url", "").strip(),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=SOURCE)
    args = ap.parse_args()
    rows = load(args.source)
    if len(rows) < 1000:
        print(f"Only {len(rows)} rows downloaded; keeping the current files.", file=sys.stderr)
        return 1
    for market, wanted in MARKETS.items():
        out = [c for r in rows if wanted((r.get("Location") or "").strip()) and (c := convert(r))]
        out.sort(key=lambda r: (r["city"], r["name"]))
        path = DATA / f"michelin_{market}.csv"
        with path.open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=COLUMNS)
            w.writeheader()
            w.writerows(out)
        print(f"{path.name}: {len(out)} restaurants")
    return 0


if __name__ == "__main__":
    sys.exit(main())
