# Changelog

What changed in the app (P0) and the infrastructure, newest first.

## 2026-11-04 (P1 Terraform, ready to run)

### Changed
- `infra/`: brought in line with the live service: container name `restaurant-review-1` (as gcloud
  named it), Terraform 1.6+ (secret imports written out instead of a loop), and a "Before you start"
  checklist in `infra/README.md` (map key, existing budget).

## 2026-11-04 (city first)

### Changed
- **Cross streets: City comes first**, then Street and Cross street, since the street suggestions
  are based on the city. Find checks the city first too. (`app/render.py`)
- A suggestion list no longer pops open after you've moved on to another box (a slow answer for the
  box you left is now ignored).

## 2026-11-04 (open filter)

### Added
- **Open filter** on "Restaurants near an address" (search page and the results page's edit form):
  Any time, Open now, or Open at a day (Today, Mon–Sun) and time. Checked against each restaurant's
  Google opening hours in its own time zone, so "Fri 7:30 PM" means 7:30 PM where the restaurant is,
  and a late opening that runs past midnight counts for the next morning. Places whose hours Google
  doesn't list are left out while the filter is on. API: `open=now`, or `open=at&open_day=fri&open_time=19:30`.
  Results for "now" or "today" are reused for 15 minutes at most. (`app/hours.py`, `app/service.py`,
  `app/main.py`, `app/render.py`, `app/sources/google_places.py`)

## 2026-11-04

### Added
- **Street suggestions for cross streets.** The Street and Cross street boxes suggest street names
  as you type (favouring the City box's city once it's filled in); picking the first street also
  fills in the city. (`app/render.py`, `app/main.py`, `app/sources/google_places.py`: autocomplete
  kind `street`)
- **Suggestions on the results page's edit form:** "Near" suggests addresses and places; for one
  restaurant, Restaurant and Location suggest as on the search page.

### Fixed
- **Cross streets without "St"** ("Howard" & "Fremont", San Francisco): Google sometimes answers
  with just one of the streets. The corner is now looked up once more as "Howard St & Fremont St"
  (names that already say Ave, Blvd, Broadway… are left as they are), and any corner among Google's
  answers is used, not only the first. When there's still no corner, the message suggests picking
  the streets from the suggestions. (`app/sources/google_places.py`)

## 2026-11-03 (Tripadvisor matching)

### Fixed
- **Tripadvisor found nothing for any restaurant.** Terra wraps each search result as
  `{"location": {...}, "matched_value": {...}}`; the app read the name, ID and position from the outer
  level, where they don't exist, so every result looked empty (seen in the log as
  `id: null, names: []`). Results are now unwrapped, names can also be a locale map
  (`{"en-US": "..."}`), and the ID can be `id` or `location_id`. Details and reviews accept the same
  wrapping. (`app/sources/tripadvisor.py`)
- **Wrong postal code on Google:** if a name search narrowed to Google's postal code finds nothing
  (Mona Lisa: Google 94123, Tripadvisor 94133), it's tried once more without it; the result must then
  be near Google's pin. An empty answer isn't billed.
- Remembered "not found" results are checked again, and a no-match log now also lists each
  candidate's field names, so a format change is easy to spot.

## 2026-11-03 (summary placement)

### Changed
- **Google's review summary moved under Top dishes**, in a column now called "Top dishes & what
  diners say": the dishes as chips, then the summary with its "Summarized with Gemini" note and link.
  The restaurant column is back to name, address, price, hours and links. (`app/render.py`)

## 2026-11-03 (start point)

### Changed
- **Cross streets is the default starting point** on the "Restaurants near an address" tab, and
  the first option (then Map or my location, then Address). After the browser's Back button, the
  fields for whichever option is selected are shown. (`app/render.py`)

## 2026-11-03 (price levels)

### Changed
- **$ to $$$$ now follows the top of each restaurant's price range per person**, which reflects a
  full meal better than Google's own level. Tosca Cafe ($30–90) shows as $$$ instead of Google's $$.
  The rule: one base amount ("$") per currency; $$ is up to 2x the base, $$$ up to 5x, $$$$ above.

  | Shown | Rule | US (base $20) | Taiwan (base NT$300) |
  |---|---|---|---|
  | $ | up to 1x base | up to $20 | up to NT$300 |
  | $$ | up to 2x | up to $40 | up to NT$600 |
  | $$$ | up to 5x | up to $100 | up to NT$1,500 |
  | $$$$ | more than 5x, or open-ended ("$100+") | over $100 | over NT$1,500 |

  Places without a range keep Google's level. The price filter uses the same rule (Google is asked
  for one level lower too, since its level can sit below this one). The base amounts and multiples
  are `PRICE_BASE` and `PRICE_MULTIPLES` in `app/sources/google_places.py`. Cached results from
  before aren't reused.

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
