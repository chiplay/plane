# Part 2 — Sightmap as a verification and test substrate for Plane

Follow-up to [SIGHTMAP-EVALUATION.md](./SIGHTMAP-EVALUATION.md). Three questions: what automated
test coverage does Plane have; does a sightmap help an agent verify its own change; can Sightmap
primitives carry ongoing automated UI coverage. Plus an assessment of the macros roadmap item.

## 1. Plane's existing automated coverage

| Layer                | Coverage                                                                                                                                                                                |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Django API           | 64 pytest files — `tests/unit/` (models, serializers, utils, views), `tests/contract/` (endpoint contracts), `tests/smoke/` (auth). Real, structured, documented in `TESTING_GUIDE.md`. |
| Web app (`apps/web`) | **Zero tests.** No unit, no component, no E2E. No Playwright/Cypress anywhere in the app.                                                                                               |
| Other JS             | A handful of vitest specs in `packages/codemods` and `apps/live`.                                                                                                                       |

The entire UI surface Sightmap describes is untested today. Any UI regression ships silently unless
a human notices. This is the gap a sightmap-driven suite can occupy — and it means Sightmap is not
competing with an incumbent E2E stack here; it is competing with _nothing_.

## 2. The experiment: a typical OSS PR, verified by the agent through Sightmap

**The change.** Phase 3's bare accessibility snapshots had already exposed a real Plane bug:
sidebar disclosure buttons rendered raw i18n keys as their aria-labels
(`button "aria_labels.app_sidebar.close_workspace_menu"`). Root cause: two components reference an
`aria_labels.app_sidebar.*` namespace that no locale file defines, so `t()` falls through to the
key string. Exactly the shape of a typical community PR: small, user-visible, cross-cutting
(19 locale files + 2 components).

Fix shipped on this branch (`fix(i18n): sidebar disclosure aria-labels rendered raw translation
keys`): retarget the six references to the existing `aria_labels.projects_sidebar` namespace and
add the two genuinely missing keys (`open_workspace_menu`/`close_workspace_menu`) to all 19
locales, phrased per-locale from sibling keys per the repo's translation guide. `sync:check`: 19/19
locales in sync.

**The verification.** Because the corpus and browser session already existed, verifying the fix
was literally one command after navigation:

```
$ sightmap snapshot | grep -E "workspace menu|extended"
152 button "Close workspace menu"
173 [ExtendedSidebarToggle "Open extended sidebar"]
```

No Playwright to set up, no page objects to write, no relearning where the buttons live — the
snapshot _is_ the accessibility tree, which for an a11y fix is precisely the artifact under test.
This is the strongest concrete support for the "agents verify their own work" thesis in this whole
evaluation — stronger than the Phase 4 A/B, because here Sightmap's native output format and the
change's acceptance criterion coincide exactly.

**The twist that proves the point.** Minutes later, the regression test I wrote for this fix
_failed_: the raw keys were back. Cause: Vite's pre-bundled dependency cache served a stale
`@plane/i18n` after a full reload — my one-shot verification had been true only for the
HMR-patched module graph. A one-off "looks fixed" check would have shipped a regression; the
checked-in test caught it (fixed by clearing `node_modules/.vite`). Agent self-verification needs
_standing_ checks, not point-in-time glances — which is exactly the argument for the suite below.

**Corpus maintenance.** The fix invalidated a `memory` note in `components.yaml` (which had
documented the broken labels as a matching hint). Updated in the same commit — the "curate after
your PR" loop the docs prescribe, and it worked as intended: `git diff` on the corpus reviews like
any other code change.

## 3. Agentic test coverage on Sightmap primitives

Shipped in this branch under `.sightmap/tests/`: a smoke suite for the UI surface Plane doesn't
test, using the corpus as a shared page-object model. `run.sh` + four tests:

- **test-navigation** — sign-in state, `[View: WorkspaceHome]`, then drive by component identity
  (`browser click 'AppSidebar SidebarNavLink[label=Projects]'`) and assert `[View: ProjectsList]`
  - `[ProjectCard … title="Rocket Ship"]`.
- **test-work-items** — `[View: ProjectWorkItems]`, every row annotates
  `key="…" state="…" title="…"`, then follow a row's key to `[View: WorkItemDetail]` and assert
  the title input.
- **test-a11y-labels** — regression guard for the PR above, generalized: **no accessible name may
  match a raw i18n-key pattern** on any tested page. This check is nearly free with Sightmap and
  catches an entire bug class (missing translation keys) app-wide.
- **test-corpus-health** — `sightmap validate` + drift gate: no mapped component may report
  `0 matches` on its view (state-dependent portal components excluded) — i.e., CI fails when the
  app changes out from under the map, which is what keeps the corpus trustworthy for the next
  agent.

Assertions are grep-level one-liners against semantic annotations (`[View: X]`,
`[WorkItemRow key="…"]`) rather than CSS — which is the practical payoff of the corpus: the test
reads like the intent, and selector churn is absorbed by re-curating one YAML definition instead
of editing every test.

**What the suite surfaced while being built** (all reproduced, all fixed in-suite):

1. The Vite stale-dep regression above — a genuine catch on the first run.
2. SPA loading races are the #1 flakiness source; snapshotting after `navigate` needs
   content-specific waits. The CLI has the right primitive (`browser wait-for --selector`), and the
   suite wraps it; a test harness on Sightmap should treat "wait until component matches" as the
   default step boundary, not wall-clock sleeps.
3. Anchor clicks that don't trigger SPA navigation (seen repeatedly in Phase 4) make
   "click then assert view" occasionally fail through no fault of the map — the suite drives
   row-follows by URL, per a corpus memory note. A `browser click --expect-view X` (act +
   postcondition in one step) would remove this class of flake.

**What's missing for real CI** (in priority order): the Linux/root fixes from Part 1 (Chrome
discovery, `--no-sandbox`, stderr surfacing) since CI is exactly Linux-root-headless; a supervised
session lifecycle (`browser start` is a foreground daemon; the suite assumes an ambient session);
and a documented exit-code contract for `snapshot` (today a blank page exits 0 with `✓`).

## 4. Assessment: the macros roadmap (learned, self-healing trajectories)

The spec's open-questions list includes: _"Macros — learned trajectories that replay and heal when
the site changes."_ Judged against what this evaluation actually observed:

**The need is real and quantified.** Both Phase 4 mutation runs burned 19–23 commands re-deriving
the same trajectory (locate item → open detail → open priority dropdown → pick option → verify).
A parameterized `set_work_item_priority(key, value)` macro would collapse that to one call. The
4-command sign-in replay via component queries, and the test files in `.sightmap/tests/`, are
already hand-written macros in all but name.

**Component queries are the right substrate for healing.** A trajectory recorded as
`click 'WorkItemRow[key=…]'` / `fill 'SignInForm EmailInput'` references _semantic identity_; the
corpus owns the identity→selector binding. When the DOM changes, re-curating one component heals
every macro that mentions it. That is structurally better than Playwright-style recordings, which
bake raw selectors into each script and rot per-script. This part of the vision is sound and
mostly already works.

**Three prerequisites, or macros will disappoint:**

1. **Portal/dropdown visibility.** The hardest 20% of Plane trajectories go through elements that
   never appear in any snapshot (the open priority dropdown — invisible even with
   `--include-hidden`). Both Phase 4 agents ended in `click --x 639 --y 315`. A macro recorded from
   those runs would bake in the one step that _cannot_ heal (no identity attached). Until the
   observation layer sees portal content, the recorder should **refuse** to record
   coordinate-click steps rather than silently capture them — the pressure will surface the gap
   instead of hiding it inside flaky macros.
2. **Per-step postconditions.** Healing needs an oracle for "did this step work?", and today's
   oracles are weak: anchor clicks silently don't navigate; a loading shell passes coverage with
   `✓`. The corpus already contains the right postcondition vocabulary — views and components. A
   macro step should be `(component-query action, expected view/component state)`; on postcondition
   failure, escalate to an agent with the corpus in hand. Note the convergence: **a macro with
   postconditions is a test, and a test is a recorded trajectory with assertions.** `.sightmap/tests/`
   and the macro engine should be one primitive with two front-ends — build it once.
3. **Reliable view identity.** Every view-based postcondition rides on route matching — the same
   mechanism that shipped silently broken (trailing slashes) in v0.15.0. Macros multiply the blast
   radius of that class of silent failure: fix loudness first (Part 1 recommendations 1 and 3),
   then build trajectories on top.

**Also encode waits, not sleeps.** The suite's flakiness was entirely wait-related; a macro format
that records wall-clock timing will flake everywhere. Steps should carry "wait until component
matches" boundaries (the `wait-for` primitive generalized to component queries).

**Net:** macros are the natural next floor of the building — the substrate (queries + corpus +
memory) is genuinely well-shaped for them, the demand is visible in this evaluation's own
transcripts, and the two hard prerequisites (portal visibility, postconditions) are the same fixes
the core product needs anyway. Sequence them first and macros become the feature that makes the
corpus earn its keep daily; skip them and macros become a flake generator that erodes trust in the
whole map.
