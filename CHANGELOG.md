# Changelog

What changed in the app (P0) and the infrastructure, newest first.

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
