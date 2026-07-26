#!/usr/bin/env bash
# CI gate: the corpus itself is structurally valid and has not drifted
# from the running app. Run after any PR that touches apps/web.
. "$(dirname "$0")/lib.sh"
echo "test-corpus-health"

if sightmap validate >/dev/null 2>&1; then echo "  ok    - validate"; else
  echo "  FAIL  - sightmap validate"
  FAILURES=$((FAILURES + 1))
fi

# Drift check: on each mapped view, no component may report 0 matches,
# except components that are legitimately state-dependent (portals render
# their menus only while open).
STATE_DEPENDENT='ContextMenuItem|ContextMenuPortal'
for path in "/$WORKSPACE/" "/$WORKSPACE/projects/"; do
  goto "$PLANE_URL$path" || exit 1
  DEAD=$(snap | sed -n '/\[Warnings\]/,/^$/p' | grep '0 matches' | grep -vE "$STATE_DEPENDENT")
  if [ -n "$DEAD" ]; then
    echo "  FAIL  - drift on $path:"
    echo "$DEAD" | sed 's/^/          /'
    FAILURES=$((FAILURES + 1))
  else
    echo "  ok    - no drift on $path"
  fi
done
finish
