# Sightmap evaluated against Plane

An outside-engineer evaluation of [Sightmap](https://sightmap.org) — the open YAML spec + CLI for
giving agents runtime context about a web app — performed end-to-end against a locally running
Plane instance (this repo, `1.3.1` dev stack: Django API in Docker, React Router 7 web app on
Vite). Nothing on the website was taken on faith; every claim below was exercised.

**Versions evaluated**

| Artifact                                      | Version                                                                           |
| --------------------------------------------- | --------------------------------------------------------------------------------- |
| `@sightmap/sightmap` (npm, dist-tag `latest`) | **0.15.0** (gitHead `918eb1a`)                                                    |
| Spec repo `github.com/sightmap/sightmap`      | `b04eab6` (HEAD of main, 2 commits past v0.15.0)                                  |
| Spec                                          | stream 1, project semver 0.1.0 (pre-1.0)                                          |
| sightmap.org / docs.sightmap.org              | fetched 2026-07-26                                                                |
| Test bed                                      | Plane @ `a8e53b6`, seeded workspace `acme-corp`, project ROCKET with 6 work items |

**Verdict in one paragraph.** The core loop is real: once a corpus exists and views actually match,
`[WorkItemRow key="ROCKET-5" state="In Progress" title="Rate limit the public API"]` is a genuinely
better substrate for an agent than a bare accessibility tree, and the checked-in `memory` notes
measurably shortened a fresh agent's path (−30% commands / −39% wall time on a navigation task).
But v0.15.0 ships with its single most important mechanism — view matching — silently broken for
any app that uses trailing-slash URLs (i.e., Plane, and most Django/Rails/RR apps), two of the
spec's headline pillars (`requests:`, `source:`) silently unimplemented, a JSON Schema that rejects
the YAML its own authoring skill mandates, and a validator that hangs forever on a circular `$ref`.
The dominant failure mode throughout is **silent**: wrong input degrades to "no annotations" or
"0 matches ✓" instead of an error. The consumption delta is positive but modest, because the real
bottleneck on a dropdown-heavy app like Plane is snapshot fidelity (portal menus invisible to the
a11y walk), which naming cannot fix.

---

## Phase 1 — Claims table

| #   | Claim (where stated)                                                                                  | Verdict                                                                                                                                                                 |
| --- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `npm i -g @sightmap/sightmap` installs a native binary, no Go (install docs)                          | ✅ 2.2 s, works                                                                                                                                                         |
| 2   | `sightmap skills install` → 2 skills in `~/.agents/skills` (quickstart)                               | ✅ exact output matches                                                                                                                                                 |
| 3   | `browser install` downloads managed Chrome for Testing (install docs)                                 | ✅ 8.5 s / 184 MB — but see D1                                                                                                                                          |
| 4   | `browser start` launches Chrome + corpus server; reloads YAML on change (quickstart)                  | ⚠️ works on macOS path only out of the box; on Linux see D1/D2; YAML hot-reload works                                                                                   |
| 5   | `snapshot --coverage` reports T1/T2/T3 + suggests selectors (quickstart)                              | ⚠️ coverage yes; selector suggestions produced **zero** hints on Plane (D8)                                                                                             |
| 6   | `sel-probe` verifies selectors before YAML (skill)                                                    | ✅ good UX — but live≠offline matcher (D6) makes “verified” misleading                                                                                                  |
| 7   | `validate` exits non-zero on structural errors (CLI ref)                                              | ⚠️ true for parse errors/empty routes; misses missing `version`/`name`/`selector`, unknown fields, unresolved `$ref` (D5, D11)                                          |
| 8   | Enriched snapshot: `[View:]` header, `[Guide]` memory, `[Comp prop="v"]`, `[src: path]` (docs index)  | ⚠️ first three yes (after D3 workaround); **`[src:]` cannot render — `source:` is dropped by the loader** (D4)                                                          |
| 9   | Route matching: `*`, `**`, `:param`→`*`, trailing slashes normalized, most-specific wins (schema ref) | ❌ trailing slashes **not** normalized (D3); precedence is first-declared, not most-specific (D10); `:param` not normalized in views                                    |
| 10  | All `*.yaml` under `.sightmap/` merged; dup views warn (schema ref)                                   | ⚠️ merge yes; duplicate views/components are silently shadowed, no warning (D12)                                                                                        |
| 11  | `$ref` expansion; `ref-unresolved`/`ref-circular` MUST error (SEP-0002)                               | ❌ unresolved: silently accepted; circular: **`validate` hangs forever** (D11)                                                                                          |
| 12  | Selector arrays: tried in order, first match wins (schema ref)                                        | ✅ (fixture-tested in repo; not contradicted live)                                                                                                                      |
| 13  | SDK MUST accept schema-valid files and reject invalid ones (conformance)                              | ❌ CLI accepts `properties`/`stability`/`url`/unknown keys the schema forbids; **5/7 files of a skill-authored corpus fail the published schema** (D5)                  |
| 14  | Component queries resolve atomically; 0 matches error (browser skill)                                 | ✅ loud, exit 1, candidates listed on ambiguity                                                                                                                         |
| 15  | Interaction by component identity (skill)                                                             | ✅ click/fill by query worked (sign-in flow scripted in 4 commands)                                                                                                     |
| 16  | Console/network collectors (skill)                                                                    | ✅ work; but network entries are never named (requests unimplemented, D4a) and v0.15.0’s own overlay floods the console log (reload loop, fixed only in unreleased #30) |
| 17  | Memory notes carry context to the next agent (landing)                                                | ✅ measurable but modest — see Phase 4                                                                                                                                  |
| 18  | Claude Code / Cursor / Codex plugins (landing)                                                        | ➖ manifests exist in repo; not exercised here                                                                                                                          |
| 19  | `browser status` detects stale sessions (skill)                                                       | ⚠️ session file yes; a stale Chrome `SingletonLock` still kills startup with an unrelated “CDP timeout” error                                                           |
| 20  | Drift: dead components reported (landing/CLI ref)                                                     | ✅ loud `[Warnings] X — 0 matches` after a real UI rename; but state-dependent components (empty portals) produce false drift positives                                 |
| 21  | Async pages need `--wait` (skill)                                                                     | ✅ documented and real — but see D7/D9 for the silent failure modes around it                                                                                           |
| 22  | `[class*=…]` never matches in Go matcher (skill “hard rule”)                                          | ✅ confirmed offline (0 vs 36 matches for the `.class` form)                                                                                                            |
| 23  | Novelty gate skips non-novel captures (skill)                                                         | ⚠️ gate works, but happily persists an **empty loading-screen capture** as a view’s baseline (D9)                                                                       |
| 24  | Exit codes: `lint` 1 on warnings, `--warn-only` 0; zero-match click 1 (CLI ref)                       | ✅ all confirmed                                                                                                                                                        |
| 25  | “installed 2 sightmap skill(s)” landing animation                                                     | ✅ verbatim                                                                                                                                                             |
| 26  | Concurrent sessions isolated per corpus                                                               | ✅ second corpus auto-allocated ports 7893/7894; first session unaffected (even pre-#31)                                                                                |

Untestable/marketing: “every agent gets the same context” (adoption-dependent), Subtext replay
enrichment (external SaaS).

---

## Phase 2 — Install and first run

Install per published instructions on Linux x64 (container, root):

```
npm install -g @sightmap/sightmap   # 2.2 s → sightmap version 0.15.0
sightmap skills install             # installed 2 sightmap skill(s) → /root/.agents/skills
sightmap browser install            # 8.5 s, Chrome for Testing 151.0.7922.47
sightmap browser start --headless --url http://localhost:3000/
# → sightmap browser: chrome: no Chrome binary found in PATH on Linux
```

- **D1 (bug, Linux-blocking).** `browser install` puts Chrome in `~/.sightmap/browsers/`, but
  `FindChrome()` consults that directory **on macOS only** (`go/browser/launcher.go:120` vs `:151`).
  On Linux it scans PATH for `google-chrome`/`chromium`/… and nothing else. The documented
  install→start flow cannot work on Linux. Workaround: shim the CfT binary into PATH.
- **D2 (gap).** No `--browser-path`, no env override, no Chrome-args passthrough, no `--no-sandbox`.
  As root (CI containers), Chrome exits instantly and sightmap reports only
  `chrome did not become ready: timed out waiting for CDP` — Chrome’s stderr is swallowed. Same
  swallowing later hid a stale-`SingletonLock` failure after a crash.
- **D-minor.** `● ready … tab=` prints an empty tab ID headless (docs show an ID).
- **D-silent.** `snapshot --coverage` with no corpus prints **nothing**, exit 0 — and quickstart
  step 3 tells you to run exactly that first.

Time to first useful output, excluding the test app’s own setup: **~32 s of tool time** — plus
roughly 20 minutes lost to D1/D2, which on a laptop Mac would not occur.

## Phase 3 — Generating a corpus for Plane

Authored as the quickstart intends (agent drives `snapshot --coverage` / `sel-probe` loop):
7 YAML files — 5 views (SignIn, WorkspaceHome, ProjectsList, ProjectWorkItems, WorkItemDetail),
global components (sidebar + children, header, command search, portals), 4 named requests.
All mapped pages reach `0 orphaned T3 ✓`; `validate`/`lint` clean. Net authoring time ~25 min,
most of it spent diagnosing tool defects, not describing Plane.

What the tool got right: `sel-probe`’s match-count+parent-chain output; `inspect -interactive`
with ★ marks on matched nodes; the final annotated rows
(`[WorkItemRow key="ROCKET-1" state="In Progress" title="Fix login redirect loop"]`); the
`[Warnings]` drift section; `multi-coverage`’s cross-page matrix; `capture-prune`.

Defects found while authoring (all verified against source at `b04eab6`):

- **D3 (critical, silent).** Views never match URLs with trailing slashes. The spec promises
  “trailing slashes are normalized away”; `routeToRegex()` (`go/sightmap/corpus.go:150`) anchors
  `^…$` with no normalization. Plane appends `/` to every route ⇒ **zero views matched — no
  `[View:]` header, no view memory, no view-scoped components — with no error anywhere.** The
  undocumented workaround is writing routes with trailing slashes (`/*/projects/*/issues/`).
- **D4 (major, silent).** `source:` on views and components and `dependencies:` are absent from the
  loader’s structs — parsed YAML fields are dropped. “Maps views, components, and API requests to
  source files” is the site’s one-line pitch; the `[src: …]` output in the landing demo cannot be
  produced by v0.15.0.
- **D4a (major, silent).** `requests:` — the spec’s third pillar — is entirely unimplemented
  (`rawFile` has no such field). A `requests.yaml` validates ✓ and does nothing. `network list`
  never names endpoints.
- **D5 (interop break).** The Go CLI accepts a superset of the schema (`properties:`, `stability:`,
  `access:`, `url:`, arbitrary typos — YAML strict mode off), while the published JSON Schema
  (`additionalProperties:false`) rejects `properties:` — which the bundled authoring skill
  **mandates** for every interactive child. Result, verified with ajv: **5 of 7 files in a
  skill-conformant corpus fail the published schema.** Any third-party consumer built “against the
  JSON Schema as contract” (docs’ own advice), and any editor using the recommended
  yaml-language-server directive, rejects what the reference implementation produces.
- **D6 (silent live/offline matcher divergences).** `sel-probe` (live DOM) and the Go tree matcher
  (snapshot/coverage/capture) disagree: `[id^="…"]` → 6 live / 0 offline (id is a dedicated field,
  not an attr — undocumented twin of the documented `[class*=]` rule); `placeholder` and most
  non-class attributes aren’t captured for form elements; svg `class` extraction is broken
  (SVGAnimatedString), killing `:has(svg.lucide-x)`. The skill’s own mandated discipline —
  “sel-probe before writing YAML” — therefore _creates_ false confidence.
- **D7 (metric integrity).** Coverage counts `opacity-0`/`translate-x(-100%)`/`pointer-events:none`
  nodes as visible interactive orphans (Plane’s off-canvas “Sidebar peek view” duplicates the whole
  sidebar; `#context-menu-portal` pre-renders menus) while the tree renderer _hides_ those same
  nodes — the agent is ordered to fix nodes it cannot see. Conversely a blank SPA loading screen
  scores `0 interactive · 0 orphaned ✓`: the done-gate passes on an unrendered page.
- **D8.** On a `data-testid`-free app, the promised guidance evaporates: `suggest` returned “No
  candidate selectors found” on a page with 136 orphans; every `gap` cluster read
  “(no stable ancestor)” with no `→` hints. Authoring degraded to raw-DOM spelunking via
  `inspect`/`eval`. (Plane’s only stable hooks: `#main-sidebar`, `#title-input`,
  `data-ph-element=…` analytics attrs, hrefs.)
- **D9 (silent).** `capture` persisted three 0-interactive loading-screen captures without protest.
- **D10.** View precedence is first-declared-wins (`ViewForURL` iterates in load order), not the
  documented segment-scoring. Duplicate-view definitions are silently shadowed (D12), spec’s SHOULD-warn
  unimplemented.
- **D-docs.** `report` demands a `url:` view field that the spec forbids; the landing demo’s child
  names (`date-input`) violate the CLI’s own PascalCase lint; the `[View:]` header prints
  `route:` on a second line, not the URL shown in docs.

What a human must still hand-edit after the loop: portability of href-based selectors (they embed
the workspace slug — every `href="/acme-corp/…"` needed rewriting to `href$=`-style suffix
matches), semantic `memory` notes (the tool has no mechanism to propose them), splitting
concatenated card text into properties, and deciding what _deserves_ a name — the T3=0 metric was
trivially satisfied by three broad containers (MainContent + two portals) that took 75 orphans to 0
while adding almost no semantics. Coverage measures containment, not meaning.

Bonus: the bare a11y tree surfaced a real Plane bug — raw i18n keys leak into aria-labels
(`aria_labels.app_sidebar.close_workspace_menu` / `open_extended_sidebar`).

## Phase 4 — Consumption A/B (the value-proposition test)

Fresh subagent contexts, identical prompts/toolsets; control had `.sightmap/` physically removed,
treatment had the corpus + the `sightmap-browser` skill. Ground truth checked via the REST API
afterwards. (n=1 per cell — directional, not statistical.)

**Task A (navigational):** find ROCKET-3, report title/state/priority.

| Arm           | Commands | Wrong turns | Tokens | Wall time | Correct |
| ------------- | -------- | ----------- | ------ | --------- | ------- |
| No sightmap   | 10       | 2           | 41,228 | 101.5 s   | ✅      |
| With sightmap | 7        | 2           | 41,148 | 61.5 s    | ✅      |

Delta: **−30% commands, −39% time, tokens a wash** (annotated snapshots are denser per call),
same success. The treatment agent read state/priority straight off `WorkItemTitleInput` and the
Properties-panel-order memory note instead of hunting.

**Task B (semantic/state mutation):** change “Add dark mode toggle” priority Medium → Urgent via UI,
verify persistence.

| Arm           | Commands | Wrong turns | Tokens | Wall time | Verified in DB |
| ------------- | -------- | ----------- | ------ | --------- | -------------- |
| No sightmap   | 23       | 2           | 52,607 | 170 s     | ✅ urgent      |
| With sightmap | 19       | 2           | 51,707 | 178 s     | ✅ urgent      |

Delta: **−17% commands, no token or time win.** Both arms independently hit the same wall: the
open priority dropdown renders in a portal that **never appears in any snapshot**, even with
`--include-hidden` — both fell back to reading option coordinates via eval and raw coordinate
clicks. Both arms also hit “clicking an SPA anchor by node id doesn’t navigate” (3 of 4 runs) and
recovered by extracting hrefs and calling `navigate`.

**Honest read:** the sightmap helps where its map is dense (navigation, identification, reading
state) and helps not at all where the bottleneck is snapshot fidelity (opened dropdowns, portals) —
which on Plane is exactly where the hard interactions live. The value proposition is real but
currently capped by the observation layer, not the vocabulary. A curator _can_ bank the
portal-workaround as a memory note for the next agent — that is the strongest version of the
memory story — but the authoring workflow (coverage over captured pages) never prompts one to
discover open-dropdown states at all. Where the corpus shone unambiguously: after a logout, the
sign-in flow was scripted blind in 4 component-query commands using the SignIn view’s memory.

## Phase 5 — Adversarial pass

| Case                                                                  | Result                                                                                                                                                  | Loud or silent                                                            |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Malformed YAML (bad indent)                                           | `validate`/`lint`/every loader path: parse error with file+line, exit 1                                                                                 | **Loud** ✅                                                               |
| View with empty route                                                 | caught, exit 1                                                                                                                                          | **Loud** ✅                                                               |
| Missing `version:` / component missing `name` or `selector`           | accepted, “✓ no validation errors”                                                                                                                      | **Silent** ❌ (schema requires all three)                                 |
| Unknown/typo’d fields (`memroy:` etc.)                                | accepted everywhere                                                                                                                                     | **Silent** ❌                                                             |
| `$ref` to nonexistent component                                       | accepted; spec MUST error `ref-unresolved`                                                                                                              | **Silent** ❌                                                             |
| Circular `$ref` (A→B→A)                                               | **`validate` hangs forever** (killed at 10 s; would hang every command incl. the corpus server)                                                         | **Hang** ❌❌                                                             |
| Duplicate view in two files                                           | first file silently wins; second’s memory vanishes; no warning (spec: SHOULD warn)                                                                      | **Silent** ❌                                                             |
| Duplicate global component names                                      | no `merge-collision-component` warning                                                                                                                  | **Silent** ❌                                                             |
| Corpus valid per CLI vs JSON Schema                                   | 5/7 files rejected by published schema (`properties:`)                                                                                                  | **Silent interop break** ❌                                               |
| Stale sightmap after real UI change (`#main-sidebar` renamed via HMR) | `[Warnings] AppSidebar — 0 matches` + all children; component-query click: “no component matches”, exit 1                                               | **Loud** ✅ (with false positives from state-dependent portal components) |
| SPA route not yet rendered                                            | tree: only a logo, or `extract: no component nodes found` error; coverage: `0 interactive · 0 orphaned ✓` **passes**; `capture` persists the empty snap | **Mixed → dangerous** ⚠️                                                  |
| Auth-gated page while logged out                                      | redirect lands on `/?next_path=…` → `[View: SignIn]` + its memory renders                                                                               | **Loud & genuinely useful** ✅                                            |
| Two corpora / concurrent sessions                                     | second `browser start` auto-allocates 7893/7894; first session untouched; commands resolve per-cwd corpus                                               | ✅                                                                        |
| `[class*=…]` skill claim                                              | 0 matches offline vs 36 for `.clickable` — as documented                                                                                                | ✅                                                                        |
| Crash recovery                                                        | stale Chrome `SingletonLock` → next `browser start` dies with unrelated “CDP timeout”; manual lock removal required                                     | **Misleading error** ⚠️                                                   |
| Released-version overlay                                              | console flooded with `[sightmap] version changed (X → {"version":"X"}), reloading` loop — the #30 fix exists only past v0.15.0                          | ⚠️ ship it                                                                |

## What I’d fix first, in order

1. **Trailing-slash normalization in `MatchRoute`** (D3) — one line; until then the product’s core
   feature silently does nothing on most real apps. Add an integration fixture whose URLs carry
   trailing slashes.
2. **Linux Chrome discovery + `--browser-path`/`--no-sandbox` passthrough, and surface Chrome’s
   stderr** (D1/D2) — this is the entire Linux/CI onboarding funnel.
3. **Make `validate` strict**: unknown fields, missing version/name/selector, unresolved `$ref`,
   and a cycle guard (D5/D11). Every silent case above becomes a 5-minute fix for users the moment
   it’s loud.
4. **Reconcile spec ↔ implementation**: either land SEP-0003 (`properties`) plus `stability`/`url`
   in the schema and implement `requests:`/`source:`, or strip them from the site until real.
   Today the landing page demos output the binary cannot produce.
5. **Fix the visibility model** (D7): `opacity:0`/`pointer-events:none`/off-viewport nodes should
   not be “visible orphans”, and whatever coverage counts, the tree must show. Consider failing
   coverage on `0 interactive` pages instead of passing them.
6. **Snapshot the open-dropdown/portal state** — both A/B arms needed coordinate-click hacks for
   Plane’s most common interaction. Until the observation layer sees portals, naming can’t help.
7. Unify live/offline matching (id/placeholder/svg-class extraction, D6) or make `sel-probe` warn
   when a selector can’t be represented offline.

## Reproduction inventory

- Corpus produced: `.sightmap/` in this branch (7 files, 4 captured view sets).
- Full command transcripts, adversarial fixtures, ajv harness, and raw A/B agent reports:
  session scratchpad (`claims-table.md`, `findings-log.md`, `adv/` fixtures).
- Plane test data: workspace `acme-corp`, project ROCKET (6 issues, 1 cycle), user
  `eval@example.com`.
