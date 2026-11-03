"""Michelin Guide status, from lists kept in data/ (Michelin has no public API).

One file per market: data/michelin_us.csv and data/michelin_tw.csv, refreshed with
scripts/update_michelin.py. Columns:
    name, name_zh, city, distinction, year, lat, lng, url
Only name and distinction are required. With lat/lng, a restaurant matches only at that exact spot,
so another branch of the same chain never gets the label. Without them, the city must appear in the
address (city may list aliases separated by "|", e.g. "Taipei|台北|臺北").
distinction is one of: 3 Stars, 2 Stars, 1 Star, Bib Gourmand, Selected
"""
import csv
import logging
import re
from dataclasses import dataclass
from pathlib import Path

from app.matching import has_cjk, km_between, normalize, similarity

log = logging.getLogger(__name__)

NAME_MATCH = 0.85
# A Google pin and the Guide's pin for the same restaurant are usually within a few dozen metres.
SAME_PLACE_KM = 0.25
# Different scripts ("鼎泰豐" vs "Din Tai Fung") can't be compared by name, so the position must
# be very close and no other listed restaurant may be near.
SAME_SPOT_KM = 0.06
BRANCH = re.compile(r"\s*[(（][^)）]*[)）]\s*$")  # "Din Tai Fung (Xinyi Road)" -> "Din Tai Fung"


@dataclass
class MichelinEntry:
    name: str
    name_zh: str = ""
    city: str = ""
    distinction: str = ""
    year: str = ""
    lat: float | None = None
    lng: float | None = None
    url: str = ""

    @property
    def label(self) -> str:
        return f"{self.distinction} ({self.year})" if self.year else self.distinction


def _float(text: str | None) -> float | None:
    try:
        return float(text) if text not in (None, "") else None
    except ValueError:
        return None


class Michelin:
    name = "michelin"

    def __init__(self, csv_path: str):
        self.entries: list[MichelinEntry] = []
        path = Path(csv_path)
        if not path.is_absolute():
            # Relative paths are relative to the project folder, not wherever the server was started.
            path = Path(__file__).resolve().parents[2] / path
        if path.exists():
            with path.open(encoding="utf-8") as f:
                for row in csv.DictReader(f):
                    row = {k: (v or "").strip() for k, v in row.items() if k}
                    if not (row.get("name") or row.get("name_zh")) or not row.get("distinction"):
                        continue
                    self.entries.append(MichelinEntry(
                        name=row.get("name", ""), name_zh=row.get("name_zh", ""), city=row.get("city", ""),
                        distinction=row["distinction"], year=row.get("year", ""),
                        lat=_float(row.get("lat")), lng=_float(row.get("lng")), url=row.get("url", ""),
                    ))
        log.info("michelin list loaded", extra={"entries": len(self.entries), "path": str(path)})

    @property
    def enabled(self) -> bool:
        return bool(self.entries)

    def _name_score(self, name: str, e: MichelinEntry) -> float:
        names = [n for n in (e.name, BRANCH.sub("", e.name), e.name_zh) if n]
        return max((similarity(name, n) for n in names), default=0.0)

    def lookup(self, name: str, address: str = "", lat: float | None = None,
               lng: float | None = None) -> MichelinEntry | None:
        """The listed restaurant at this place, or None. Never a namesake somewhere else."""
        have_pos = lat is not None and lng is not None
        addr = normalize(address)
        best, best_score = None, 0.0
        close: list[MichelinEntry] = []
        for e in self.entries:
            located = have_pos and e.lat is not None and e.lng is not None
            dist = km_between(lat, lng, e.lat, e.lng) if located else None
            if dist is not None and dist <= SAME_SPOT_KM:
                close.append(e)
            score = self._name_score(name, e)
            if score < NAME_MATCH:
                continue
            if dist is not None:
                if dist > SAME_PLACE_KM:
                    continue  # same name, different branch or city
            elif e.city and addr:
                # No coordinates: the city must appear in the address, so a starred "Joe's" in
                # Chicago doesn't label every "Joe's" in the country.
                aliases = [normalize(c) for c in e.city.split("|") if c.strip()]
                if not any(a and a in addr for a in aliases):
                    continue
            elif e.city or e.lat is not None:
                continue  # can't confirm the location, so don't claim it
            if score > best_score:
                best, best_score = e, score
        if best:
            return best
        # "鼎泰豐 信義店" vs "Din Tai Fung (Xinyi Road)": names in different scripts, matched by position.
        if len(close) == 1 and has_cjk(name) != has_cjk(close[0].name or close[0].name_zh):
            return close[0]
        return None
