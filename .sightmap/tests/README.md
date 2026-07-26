# Sightmap-driven UI smoke tests

Plane's web app has no automated UI coverage (the Django API has pytest; `apps/web` has nothing).
This suite covers the critical read paths using the checked-in `.sightmap/` corpus as a shared
page-object model: pages assert by `[View: …]` identity, elements by component annotation, and
interactions run by component query — no per-test CSS selectors.

## Running

```bash
# 1. App stack running, web on http://localhost:3000, session signed in
# 2. From the repo root, in another terminal:
sightmap browser start --headless --url http://localhost:3000/
# 3. Point the work-items test at a project and run:
export PLANE_PROJECT_ISSUES_PATH="/<workspace>/projects/<project-id>/issues/"
bash .sightmap/tests/run.sh
```

`PLANE_URL` and `PLANE_WORKSPACE` override the defaults (`http://localhost:3000`, `acme-corp`).

## Tests

| Test                    | What it guards                                                                                                                                                                     |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `test-navigation.sh`    | Sidebar navigation by component identity reaches the projects list; project cards annotate with their titles.                                                                      |
| `test-work-items.sh`    | Work-item rows annotate `key`/`state`/`title`; a row's key resolves to the detail view with the title input present.                                                               |
| `test-a11y-labels.sh`   | No accessible name anywhere on tested pages matches a raw i18n-key pattern (regression guard for the sidebar aria-label fix, and for the whole missing-translation-key bug class). |
| `test-corpus-health.sh` | `sightmap validate` passes and no mapped component reports `0 matches` on its view — CI fails when the app drifts out from under the map.                                          |

## Notes for CI

- Headless works; on Linux the sightmap CLI (v0.15.0) needs a Chrome shim on PATH and
  `--no-sandbox` when running as root — see `SIGHTMAP-EVALUATION.md` Phase 2.
- The app is a client-rendered SPA: every navigation must be followed by a content-specific wait
  (`wait_for_selector`) before snapshotting. Never assert against a freshly navigated page.
- Known state-dependent components (context-menu portals) are excluded from the drift gate — their
  menus only exist in the DOM while open.
