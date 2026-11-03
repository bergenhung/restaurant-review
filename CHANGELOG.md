# Changelog

What changed in the app (P0) and the infrastructure, newest first.

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

### Removed
- The generic "Check Michelin Guide" search link on every row.
