#!/usr/bin/env bash
# Smoke: sidebar navigation reaches the projects list; project cards annotate.
. "$(dirname "$0")/lib.sh"
echo "test-navigation"

goto "$PLANE_URL/$WORKSPACE/" || exit 1
S=$(snap)
assert_contains "$S" '\[View: WorkspaceHome\]' "home view matches"

# Drive by component identity, not CSS or coordinates.
sightmap browser click 'AppSidebar SidebarNavLink[label=Projects]' >/dev/null || {
  echo "  FAIL  - click SidebarNavLink[label=Projects]"
  FAILURES=$((FAILURES + 1))
}
wait_for_render
wait_for_selector 'a.group\\/project-card'
S=$(snap)
assert_contains "$S" '\[View: ProjectsList\]' "projects view matches after click"
assert_contains "$S" '\[ProjectCard .*title="Rocket Ship"' "seeded project card annotated with title"
assert_contains "$S" '\[AddProjectButton' "add-project button present"
finish
