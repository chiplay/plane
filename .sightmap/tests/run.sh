#!/usr/bin/env bash
# Sightmap-driven UI smoke suite for Plane.
#
# Plane's web app has no automated UI tests today (API has pytest; web has
# nothing). This suite uses the checked-in .sightmap/ corpus as the page
# object model: views assert by [View:] identity, elements by component
# annotations, interactions by component query. No per-test selectors.
#
# Prereqs:
#   1. Web app on $PLANE_URL (default http://localhost:3000), signed in.
#   2. `sightmap browser start --headless` running from the repo root.
#   3. PLANE_PROJECT_ISSUES_PATH exported for test-work-items.sh.
#
# Usage: bash .sightmap/tests/run.sh
set -u
cd "$(dirname "$0")/../.." || exit 1
overall=0
for t in .sightmap/tests/test-*.sh; do
  bash "$t" || overall=1
  echo
done
[ "$overall" -eq 0 ] && echo "SUITE PASSED" || echo "SUITE FAILED"
exit "$overall"
