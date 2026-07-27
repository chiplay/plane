# Sightmap 0.15.5 evaluated against Plane

Skeptical outside-engineer evaluation. Every claim below was tested by running something
against this repo's app; nothing was taken on faith from sightmap.org. Audience: the
Sightmap authors, so the emphasis is on specific failures.

## What was evaluated

| Artifact         | Version / provenance                                                                                                                                                                                                                                                 |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CLI (npm)        | `@sightmap/sightmap` **0.15.5**, published 2026-07-26T19:06Z, evaluated 2026-07-26/27                                                                                                                                                                                |
| Native binary    | `@sightmap/sightmap-linux-x64` 0.15.5, ELF static, BuildID `1291560973280ba53c7c2648a12862eea0fc958b`                                                                                                                                                                |
| Spec             | v1 stream; JSON Schema fetched from the stable `$id` URL (`.../spec/v1/sightmap.schema.json`) on 2026-07-26                                                                                                                                                          |
| Docs             | sightmap.org landing (rendered from its Vite bundle) + all 31 pages of docs.sightmap.org (llms.txt crawl), fetched 2026-07-26                                                                                                                                        |
| Skills           | `sightmap-authoring`, `sightmap-browser` as shipped in the npm tarball                                                                                                                                                                                               |
| Spec repo commit | **Not recorded** — GitHub repo access was blocked by this session's repository-scope policy (`add_repo` needs interactive approval). Everything was evaluated from published artifacts (npm, docs site, schema `$id` URL).                                           |
| Test bed         | Plane @ `a8e53b6` (React Router v7 + Vite web app, Django API), run locally: Docker backend (postgres/valkey/rabbitmq/minio/api/worker/beat) + `pnpm dev` web/admin/live. Seeded: workspace _Acme Rockets_, project _FALCON_, 8 issues, 2 labels, 1 cycle, 1 module. |

Environment caveat: everything ran headless as root in a sandboxed container behind a
TLS-intercepting egress proxy. Defects attributable to that environment are marked (env).

---

## Phase 1 — Claims table

| #   | Claim                                                                                                                       | Where stated                 | Testable | Verdict                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| --- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C1  | npm install = prebuilt binary, no Go, no postinstall download                                                               | npm README, install docs     | yes      | **TRUE.** 2.5 s install; `version` runs in 0.07 s.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| C2  | `sightmap skills install` → 2 skills in `~/.agents/skills`                                                                  | landing, install docs        | yes      | **TRUE.** 0.07 s.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| C3  | No Chrome? `sightmap browser install` provides one the CLI can launch                                                       | install docs                 | yes      | **FALSE as composed.** Install works (9.5 s, 184 MB), but `browser start` still fails with `no Chrome binary found in PATH` — start never looks in `~/.sightmap/browsers/`, and there is no `--chrome-path` flag. Also no `--no-sandbox` passthrough, so even a PATH shim must add it when running as root (env). See D1.                                                                                                                                                                                                                                                                         |
| C4  | `sightmap iterate 'URL'` is the coverage loop                                                                               | sightmap.org §Get started    | yes      | **FALSE.** `unknown command "iterate"` (exit 1). The real command is `snapshot --coverage`. Landing page documents a command that does not exist.                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| C5  | Landing-page snapshot format (`uid=1_3 DepartureDatePicker [src: …] visible interactive`, `[View: X "/search"]`, `[Guide]`) | landing hero + spec sections | yes      | **PARTIAL / aspirational.** Real output is `42 [Name prop="v"]` lines; there is a `[View:]`/`memory:` header, but no `[src: …]` inline, no `visible interactive` flags, and the guide section renders as `memory:` under the view, not the hero's `[Guide]` block. The hero mock-up is a different product than the CLI ships.                                                                                                                                                                                                                                                                    |
| C6  | Views/components/requests + memory, recursively merged from `.sightmap/`                                                    | spec docs                    | yes      | **TRUE** for views/components/memory. Requests: see C17.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| C7  | Route globs + specificity (most-specific wins; `:param` scores 2)                                                           | spec/views                   | partly   | View matching worked for all authored views incl. `:param` routes. Same-score conflicts resolve by _file path order_, silently (see P5-3).                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| C8  | `sightmap validate` spec-validates the corpus                                                                               | everywhere                   | yes      | **MISLEADING.** The Go validator accepts a dialect the published schema rejects: `properties:`/`extract:`/`transform:` (which the bundled skill _requires_ and the component-query DSL depends on) and `url:` (which `report` demands) are schema violations (`additionalProperties: false`). It also accepts a component with **no `selector`** (schema says required) with zero complaint. A CI/editor pipeline configured exactly per the JSON-schema docs will reject corpora produced exactly per the authoring skill. This is the single most damaging finding for "open spec" credibility. |
| C9  | `sel-probe` cross-checks live vs offline matcher, warns on divergence                                                       | authoring skill              | yes      | **TRUE, excellent.** Caught `placeholder` attr not in offline model, `[id^=…]` unsupported offline — with correct, actionable explanations.                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| C10 | `:has()` agrees live/offline                                                                                                | authoring skill              | yes      | **PARTIAL.** Positive `:has()` agrees. `:not(:has(…))` matched 8 live / 0 offline (sel-probe did warn).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| C11 | Coverage T1/T2/T3, cluster hints with `→` selector suggestions                                                              | skill, quickstart            | yes      | **PARTIAL.** Coverage line and clusters work. Against Plane, the hint engine produced `inside: (no stable ancestor)` for **every** cluster and never emitted a single `→` suggestion — the app has no `data-testid` discipline, so the flagship "agent closes gaps from hints" loop degenerates to manual DOM spelunking (`inspect` + `eval`).                                                                                                                                                                                                                                                    |
| C12 | Memory notes surface at runtime                                                                                             | landing, spec/memory         | yes      | **TRUE.** View memory renders in every snapshot header; genuinely the most valuable artifact feature.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| C13 | Component queries (`Name[prop="v"]`) resolve atomically for click/fill                                                      | browser skill                | yes      | **TRUE.** `SidebarProjectLink[projectName="Falcon Heavy"]` clicked first try in the A/B runs; ambiguity errors list candidates.                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| C14 | `capture` view sets + novelty gate + union coverage                                                                         | skill, cli docs              | partly   | Captures + `.tree.json` written; offline `coverage`/`multi-coverage` consumed them. Novelty gate not exercised (single captures per view).                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| C15 | `report` = per-view health table                                                                                            | cli/coverage docs            | yes      | **BROKEN.** Demands `url:` fields, then still prints `no views with URLs found` when every view has `url:`. Dead-end loop; and `url:` isn't in the published schema anyway.                                                                                                                                                                                                                                                                                                                                                                                                                       |
| C16 | Session console/network collector                                                                                           | browser skill, devtools docs | yes      | **TRUE.** Captured the Vite module storm and API XHRs; `network get` returns bodies. Ring buffer honestly reports overflow. Genuinely useful — it's how I debugged Plane's slow first render.                                                                                                                                                                                                                                                                                                                                                                                                     |
| C17 | Requests: named endpoints shown in `network list`/detail with schema fields                                                 | landing §Requests            | yes      | **FALSE at runtime.** Declared `ListProjectIssues` matching `/api/workspaces/:slug/projects/:projectId/issues`, then a `/api/**` catch-all: zero annotation in `network list`, zero `### Sightmap:` block in `network get`. `validate` accepts request YAML; nothing consumes it. One third of the spec triad is currently decorative, silently.                                                                                                                                                                                                                                                  |
| C18 | `browser start` writes `.sightmap/.session`                                                                                 | authoring skill              | yes      | **PARTIAL/BUGGY.** With no `.sightmap/` it writes `/tmp/sightmap-session`; if you then create `.sightmap/` (the exact bootstrap order the landing page recommends), every subsequent command looks in the new place, falls back to default port 7892, and `status` calls the live session an **orphan**. Restarting the session is the only fix. See P5-7.                                                                                                                                                                                                                                        |
| C19 | Missing corpus → snapshot still renders raw tree, not an error                                                              | cli overview                 | yes      | **TRUE**, with a loud warning line.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| C20 | 0 interactive nodes → `∅` + nonzero exit                                                                                    | cli docs                     | yes      | **TRUE.** Fired on every Vite cold load; message suggests the right remedies.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |

---

## Phase 2 — Install and first run (published instructions only)

Timeline (Node 22.22, clean container):

| Step                                                     | Result                                                                         | Time   |
| -------------------------------------------------------- | ------------------------------------------------------------------------------ | ------ |
| `npm install -g @sightmap/sightmap`                      | ok                                                                             | 2.5 s  |
| `sightmap version`                                       | `sightmap version 0.15.5`                                                      | 0.07 s |
| `sightmap skills install`                                | 2 skills → `/root/.agents/skills`                                              | 0.07 s |
| `sightmap browser start --headless`                      | FAIL: `no Chrome binary found in PATH`                                         | —      |
| `sightmap browser install`                               | Chrome-for-Testing 151 → `~/.sightmap/browsers/...`                            | 9.5 s  |
| `sightmap browser start --headless` (again)              | **FAIL: same PATH error**                                                      | —      |
| _(off-docs workaround: PATH shim adding `--no-sandbox`)_ | start works; foreground daemon                                                 | —      |
| `browser navigate` with zero tabs                        | FAIL: “Start a session first” (session was running; real remedy is `tabs new`) | —      |
| `tabs new` + `snapshot`                                  | first useful output (raw tree of a live page)                                  | ~0.5 s |

**Documentation defects logged**

- **D1 (blocker on a bare box):** `browser install` → `browser start` don't compose. Exact error after a successful install: `sightmap browser: chrome: no Chrome binary found in PATH on Linux`. Docs (`start/install`: "If you don't have one available, install a managed Chrome for Testing") imply start will use it. It doesn't; there's also no flag to point start at a binary, and no sandbox-flag passthrough (env: required as root).
- **D2:** With a live session and zero tabs, page commands say `Start a session first: sightmap browser start` — the wrong remedy. Cost me a retry loop; would cost a new user more.
- **D3:** Landing page teaches `sightmap iterate` (C4) and a snapshot output format the CLI doesn't produce (C5).

Time-to-first-useful-output: **~15 s of tool time** when you know the workarounds; a doc-following user on a headless/root machine stalls at D1 with no documented recovery.

## Phase 3 — Generating a sightmap for Plane

Full command log lives in the session transcript; representative loop:

```
sightmap browser start --headless --url http://localhost:3000/   # foreground; auth via profile
sightmap snapshot --coverage           # [Coverage] 145 interactive · 4 T1 · 47 T2 · 94 T3 ✗
sightmap sel-probe -- '#main-sidebar a[data-discover]'           # 5 live / 5 offline
# edit .sightmap/*.yaml, re-run, repeat
sightmap capture                       # persists view set + .tree.json
sightmap validate && sightmap lint     # ✓ / ✓
```

Result committed on this branch: 6 views (WorkspaceHome, ProjectIssues, WorkItemDetail,
ProjectCycles, CycleDetail, ProjectsList), global sidebar/header/portal components,
3 captured view sets. Coverage reached: home 145→8 orphans (94%; a later load rendered
150 nodes → 0 orphans purely from page nondeterminism), issues 663→16 (97.6%),
detail 220→73 (67%, deliberately stopped).

**Does the YAML accurately describe the app?** What it says is accurate — because the
tool made me verify every selector before writing it (this discipline is real and works).
The problems are in what it _can't_ say and what a human must hand-fix:

- **Plane gives the tool almost nothing to hold onto.** No `data-testid`/`data-component`;
  36 files with `data-ph-element`; everything else is Tailwind soup and headlessui
  generated ids. Consequences: `suggest` returned nothing; `gap` said
  `(no stable ancestor)` for all 145 home orphans; issue rows are keyed by dynamic
  `id="issue_<uuid>_…"` which the offline matcher cannot address at all (`[id^=]`
  unsupported); the page header had to be keyed on `div.z-\[27\]` — a z-index utility
  class. The "agent names components until coverage is clean" story collapses to manual
  `inspect`/`eval` archaeology on any app without test-id discipline, and produces
  a corpus whose hardest-won selectors are the most fragile.
- **Extraction artifacts needed hand-editing:** `workspaceName="AAcme Rockets"` (avatar
  letter + name), `projectName="👇Acme Rockets"` (emoji bleed) — fixed by switching to
  child-selector extraction, but every card-like component will need this pass.
- **Coverage numbers flatter themselves.** 260 of the issues page's 663 “visible”
  interactive nodes are closed context menus inside `#context-menu-portal`. One
  catch-all component converted 39% of the page to “covered” without adding any
  semantic value. The 0-orphan goal is largely achievable by container-wrapping,
  which is the metric gaming the docs warn about, except the tool's own counting
  invites it.
- **Invented nothing** — the tool never fabricated components or views. What it missed:
  everything not URL-addressable (view = pathname only; no auth-state, no modal/drawer
  states, no "same URL, different mode").
- Misc: `snapshot --coverage` on a corpus with a matched view but zero components
  prints only the view header — no `[Coverage]` line at all, so the documented
  bootstrap ("create view file, run snapshot --coverage") shows nothing to iterate on;
  `.sightmap/.session` lands in `git add` unless you know to ignore it (no shipped
  gitignore/hint); untranslated `aria_labels.app_sidebar.*` keys in Plane's own UI
  showed up prominently in every snapshot — the tool is good at exposing the target
  app's a11y debt.

## Phase 4 — Consumption A/B (the value-proposition test)

Design: two tasks × {with corpus, without corpus}; four fresh agent contexts; identical
prompts and CLI cheat-sheet; same live logged-in session, run sequentially; corpus
physically removed for the "without" runs; ground truth verified via API out-of-band;
FALCON-5 state reset between runs. n=1 per cell — treat numbers as anecdotes with error
bars, not statistics.

**Task N (navigational):** "find the work item about a telemetry dropout; report ID,
state, priority" (truth: FALCON-7 / Done / Urgent).

| Condition        | Success | Commands | Wrong turns          | Tokens | Wall time |
| ---------------- | ------- | -------- | -------------------- | ------ | --------- |
| Without sightmap | ✓       | 9        | 1 (20 s wasted wait) | 38,976 | 81 s      |
| With sightmap    | ✓       | 21       | 4 clusters           | 56,814 | 150 s     |

The bare agent found the command palette and searched "telemetry" — done. The corpus
agent tried the home-page recents links, got ambushed by the onboarding overlay
(state drift between runs; Plane re-showed it), burned commands, then recovered _using
corpus features_ (SidebarProjectLink component query worked first try; the view memory's
`/browse/:workItem` note supplied the direct URL). Net: the map lost to a good prior.

**Task S (semantic/state):** "change FALCON-5 from Backlog to In Progress via the UI;
confirm it stuck" (verified via API after each run).

| Condition        | Success           | Commands | Wrong turns       | Tokens | Wall time |
| ---------------- | ----------------- | -------- | ----------------- | ------ | --------- |
| Without sightmap | ✓ (API-confirmed) | 27       | 8-command cluster | 61,353 | 197 s     |
| With sightmap    | ✓ (API-confirmed) | 22       | 7-command cluster | 55,979 | 128 s     |

Both agents independently discovered the row's state chip; both got stuck on the same
Plane UX trap (row clicks that silently don't navigate + hover overlays that cover
targets — sightmap's covered-click detection produced loud, correct errors both times).
The corpus run was ~19% fewer commands, ~9% fewer tokens, ~35% faster.

**Verdict on the value proposition, plainly:** on this app, with this corpus, the delta
is **a wash** — one task worse, one task moderately better, 4/4 success in both
conditions. The strong baseline is the problem: a competent agent with a raw a11y tree
and a search palette is already good. Where the corpus visibly earned its keep:
component queries (no stale numeric ids), and one memory note that converted a dead end
into a direct URL. Where it didn't: none of the failures either agent hit (overlays,
non-navigating clicks, SPA loading stalls) are things a sightmap can prevent — and those
were the dominant cost in all four runs. The pitch "agents check it against the running
app to keep it current" also cuts the other way: the app's _state_ (onboarding overlay)
varied between runs and dominated the outcome, and no URL-keyed view model can express that.

What would move the delta: (1) requests actually being consumed (C17) so agents can name
network traffic; (2) memory accumulating over many sessions (untestable in one day);
(3) apps with `data-component` discipline where per-row semantics (state chips, priority
dropdowns) become addressable — on Plane those were exactly the nodes that stayed anonymous.

## Phase 5 — Break it

| Probe                                                                                       | What happened                                                                                                                                                                                                                                                       | Loud or silent?                                                                                                               |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Malformed YAML in corpus                                                                    | `validate` rc=1 with file+line; `snapshot` rc=1 same message                                                                                                                                                                                                        | **Loud** ✓                                                                                                                    |
| View missing `route`                                                                        | `validate` rc=1 `view has empty route`                                                                                                                                                                                                                              | **Loud** ✓                                                                                                                    |
| Component missing `selector` (schema-required)                                              | `validate` rc=0, no warning; component just never matches                                                                                                                                                                                                           | **Silent** ✗                                                                                                                  |
| Duplicate view name, different route                                                        | No warning (spec says SHOULD warn)                                                                                                                                                                                                                                  | **Silent** ✗                                                                                                                  |
| Two views, same route, different files                                                      | Alphabetically-earlier file **hijacks the view**: T1 24→15, orphans 16→273, real components stop applying. No warning anywhere                                                                                                                                      | **Silent, corrupting** ✗✗                                                                                                     |
| Duplicate global component name, different selector                                         | No merge-collision warning                                                                                                                                                                                                                                          | **Silent** ✗                                                                                                                  |
| Unresolved / circular `$ref`                                                                | (documented as validate errors; exit-code table says so) — not reached because dup-name tests above already passed validate silently                                                                                                                                | —                                                                                                                             |
| Stale map after real UI change (renamed `data-ph-element` in Plane source, Vite hot-reload) | Next snapshot: `CreateWorkItemButton — 0 matches` warning; component-query click fails rc=1 `no component matches query`                                                                                                                                            | **Loud** ✓ (for vanished selectors; a selector that still matches the _wrong_ thing, or stale memory prose, has no detection) |
| SPA route not in DOM at load                                                                | 0-interactive guard + `∅` + rc=1, good remedy text; snapshots mid-hydration also produced a burst of spurious `0 matches` warnings for every global before settling                                                                                                 | **Loud**, with a noisy transient                                                                                              |
| Auth-gated page, logged-out profile                                                         | App bounces to `/?next_path=…`; snapshot silently renders the login tree with **no view matched and no "no view matched" indicator** (plus an odd sparse `[Guide] ContextMenuPortal 1` header). An agent gets no cue it fell off the map                            | **Silent-ish** ✗                                                                                                              |
| Two sightmaps in scope (nested `apps/web/.sightmap` + root corpus)                          | From the subdir, the nested corpus **silently wins** — `[View: TotallyWrongView]` with its memory served as truth; no "parent corpus exists" hint                                                                                                                   | **Silent** ✗                                                                                                                  |
| Session-file keying                                                                         | No corpus → `/tmp/sightmap-session`; create `.sightmap/` afterwards → all commands look elsewhere, fall back to port 7892, `status` calls the live session an _orphan_. This is triggered by the recommended bootstrap order (start session → agent creates corpus) | **Loud but wrong** — errors point to the wrong cause ✗                                                                        |
| `--port 0` / `--cdp-port 0` (documented auto-allocate)                                      | Prints `● ready port=0 cdp=1 … --addr localhost:1`; serve binds “127.0.0.1:0”; session file records port 1; unusable, and `status` then reported a _different directory's_ session                                                                                  | **Broken** ✗                                                                                                                  |
| Unknown command / unknown flag                                                              | rc=1, usage printed                                                                                                                                                                                                                                                 | **Loud** ✓                                                                                                                    |
| Killed Chrome behind a live session file                                                    | `status` probes CDP, reports unreachable, removes stale file; a leftover "orphan Chrome" heuristic then needs `browser stop` to reap                                                                                                                                | Mostly ✓                                                                                                                      |

Pattern: **runtime failures are loud** (the interaction layer is defensively built —
covered-click detection, value-stick verification on fill, ambiguous-query listings are
all better than typical browser-automation CLIs). **Corpus-semantics failures are
silent** (duplicate names, route conflicts, missing required fields, shadowed corpora,
unconsumed requests). The silent ones are exactly the ones that poison agents at scale,
because agents trust the map.

## Bottom line for the builder

Worth keeping, verbatim: sel-probe's dual-matcher honesty, the covered-click/fill-verify
interaction layer, the console/network collector, memory-in-snapshot, loud validate
messages (the `:first-child` error text is a model for the genre).

What kills adoption today, in order:

1. **Spec vs. tooling schism (C8):** the shipped skill _requires_ fields the published
   schema _forbids_ (`properties`/`extract`/`transform`, `url`). Either SEP them into v1
   or stop the skill from writing them. Right now "open spec" and "the tool" are two
   products with one name — and `validate` enforces neither (missing `selector` passes).
2. **Requests are decorative (C17):** landing page shows named network detail; 0.15.5
   annotates nothing. Ship it or delete the pillar from the marketing.
3. **First-run composition (D1/D2, C18, port-0):** install→start, session-file keying
   across the recommended bootstrap order, and auto-port are all broken in ways that
   burn the first hour.
4. **Silent corpus conflicts (P5):** dup names, same-route hijack by file order,
   corpus shadowing. Each needs a warning; the spec already says SHOULD.
5. **The value prop needs a harder demo than "agent drives an app"** — a strong agent
   with a raw a11y tree already does that. The measurable wins here were component
   queries and one memory note; the losses were authoring cost and app-state drift the
   map can't express. On a hook-poor app (i.e., most real apps), the authoring loop is
   manual and the artifact is fragile. `data-component` discipline isn't a
   recommendation — it's a prerequisite, and the docs should say so in the first
   paragraph, not the appendix.

_Generated during a five-phase evaluation session; corpus, captures, and this report are
committed on branch `claude/sightmap-plane-evaluation-gqf8zd`. Test-bed scaffolding
(proxy-CA build tweaks to `apps/api/Dockerfile.dev` / `docker-compose-local.yml`) was
deliberately left uncommitted._
