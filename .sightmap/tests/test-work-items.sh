#!/usr/bin/env bash
# Smoke: the work-item list annotates every row with key/state/title,
# and the detail page exposes the title input.
. "$(dirname "$0")/lib.sh"
echo "test-work-items"

PROJECT_ISSUES_PATH="${PLANE_PROJECT_ISSUES_PATH:?export PLANE_PROJECT_ISSUES_PATH=/<ws>/projects/<id>/issues/}"

goto "$PLANE_URL$PROJECT_ISSUES_PATH" || exit 1
wait_for_selector 'a[href*="/browse/"]'
S=$(snap)
assert_contains "$S" '\[View: ProjectWorkItems\]' "work items view matches"
assert_contains "$S" '\[WorkItemRow key="[A-Z0-9]+-[0-9]+" state="[^"]+" title="[^"]+"\]' "rows annotate key+state+title"

ROWS=$(echo "$S" | grep -c '\[WorkItemRow ')
if [ "$ROWS" -ge 1 ]; then echo "  ok    - $ROWS work item rows found"; else
  echo "  FAIL  - no WorkItemRow matched"
  FAILURES=$((FAILURES + 1))
fi

# Follow the first row's href into the full-page view (row clicks open the
# peek overlay; the corpus memory documents driving by URL instead).
KEY=$(echo "$S" | grep -o 'key="[A-Z0-9]*-[0-9]*"' | head -1 | cut -d'"' -f2)
goto "$PLANE_URL/$WORKSPACE/browse/$KEY/" || exit 1
wait_for_selector '#title-input'
S=$(snap)
assert_contains "$S" '\[View: WorkItemDetail\]' "detail view matches for $KEY"
assert_contains "$S" '\[WorkItemTitleInput' "title input annotated"
finish
