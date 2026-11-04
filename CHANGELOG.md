# Changelog

What changed in the app (P0) and the infrastructure, newest first.

## 2026-11-03 (price levels)

### Changed
- **$ to $$$$ now follows the top of each restaurant's price range per person**, which reflects a
  full meal better than Google's own level. Tosca Cafe ($30–90) shows as $$$ instead of Google's $$.

  | Shown | US (top of range) | Taiwan (top of range) |
  |---|---|---|
  | $ | up to $20 | up to NT$200 |
  | $$ | up to $30 | up to NT$500 |
  | $$$ | up to $100 | up to NT$1,500 |
  | $$$$ | more, or "$100+" | more, or "NT$1,000+" |

  Places without a range keep Google's level. The price filter uses the same rule (Google is asked
  for one level lower too, since its level can sit below this one). Limits are `LEVEL_LIMITS` in
  `app/sources/google_places.py`. Cached results from before aren't reused.

## 2026-11-03 (later)

### Added
- **Change a search from the results page.** The results page shows the search as a filled-in form
  (start point, how many, distance, cuisine, price, rating, order for nearby; restaurant and
  location for one restaurant). Change anything and press Update. The start point is reused as a
  map point, so no address lookup is repeated; editing the "Near" text searches from the new
  address instead. (`app/render.py`, `app/service.py`, `app/main.py`)
- `/v1/nearby` accepts `label`, a name for a `lat`/`lng` start point that's already known.

## 2026-11-03

### Fixed
- **Nearby results now match Google Maps much more closely.** The restaurants come from Google's
  nearby search (strictly inside the radius, nearest first). A text search of the same area, with
  Google applying the price and rating filters, tops up only when a cuisine is given or the filters
  leave too few. Before, a text search with distance as a mere hint returned a shortlist that missed
  close places (e.g. Tosca Cafe and China Live near Broadway & Columbus). (`app/service.py`,
  `app/sources/google_places.py`)
- **Top dishes:** a dish mentioned by only one reviewer is no longer shown (Bouche showed "crepe").
  Dishes named in Google's AI review summary come first. (`app/dishes.py`)
- **Last 3 months:** no average from fewer than 3 recent reviews; the cell says "too few recent
  reviews" instead of e.g. "5.0 from 1 review". Google's API shares only 5 reviews per place, chosen
  by relevance, not date. (`app/service.py`, `app/render.py`)
- **Tripadvisor matching:** an exact name ("Bouche") wins over a similar one ("Bouchon") from the same
  search; no-matches remembered under the old rules are checked again; a no-match now logs the
  candidates Tripadvisor returned. (`app/sources/tripadvisor.py`)
- **Tripadvisor locale:** names are requested as `en-US` (and `zh-TW`, `en-US` for Taiwan). Terra
  rejects plain `en` with a 400, which made every first search fail. Reviews are retried without
  the language setting if Terra rejects that too. (`app/sources/tripadvisor.py`)
- **Health check:** `deploy.sh` and `ship.sh` check `/health`. Cloud Run reserves some paths ending
  in "z", so `/healthz` gets Google's own 404 on the deployed site. (`app/main.py`)
- **`deploy.sh` keeps the map key:** if `GOOGLE_MAPS_BROWSER_KEY` / `GOOGLE_MAP_ID` aren't exported,
  the values already on the service are reused instead of being erased.
- **Cross streets that Google can't place as a corner** (e.g. "Broadway & Columbus" matching a
  street in Columbus, OH) now get a clear message asking for the city, instead of searching the
  wrong place. (`app/sources/google_places.py`, `app/main.py`)
- Cached results from before these changes aren't reused.

### Added
- Google's AI review summary under each restaurant (US English), with the required "Summarized with
  Gemini" note and a link to the Google reviews.

## 2026-11-02

### Changed
- **Home page opens on "Restaurants near an address".** It's now the first tab and the default;
  "One restaurant" is second. `/#single` opens it directly (the old `/#nearby` link still works).
  The results page's "new search" link returns to the tab you came from. (`app/render.py`)
- **Michelin is shown only for the listed restaurant at that location.** Same name within 250 m,
  or, for names in different scripts (鼎泰豐 / Din Tai Fung), the only listed restaurant within 60 m.
  Other branches and namesakes elsewhere show "–". The award links to the restaurant's own Guide
  page. (`app/sources/michelin.py`, `app/service.py`, `app/render.py`)

### Added
- Michelin lists for the US (~1,850) and Taiwan (~430) from the public michelin-my-maps dataset,
  with position and Guide page. Refresh with `python scripts/update_michelin.py`. (`data/`, `scripts/`)
- P1 Terraform setup in `infra/`, `ship.sh` for code-only deploys, and the P0–P7 roadmap in
  `docs/ROADMAP.md`.

### Fixed
- `deploy.sh`, `ship.sh` and `infra/bootstrap.sh` accept the project number as well as the
  project ID (Firestore commands reject the number).

### Removed
- The generic "Check Michelin Guide" search link on every row.
