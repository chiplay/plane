#!/usr/bin/env bash
# Regression: no raw i18n keys may leak into accessible names.
# Guards the fix for aria_labels.app_sidebar.* rendering literally
# (sidebar disclosure buttons), and catches any future missing-key leak,
# since untranslated keys surface verbatim in the accessibility tree.
. "$(dirname "$0")/lib.sh"
echo "test-a11y-labels"

for path in "/$WORKSPACE/" "/$WORKSPACE/projects/"; do
  goto "$PLANE_URL$path" || exit 1
  S=$(snap)
  assert_not_contains "$S" '"[a-z0-9_]+\.[a-z0-9_]+\.[a-z0-9_]+"' "no raw i18n keys in accessible names on $path"
done

# The two buttons the fix touched must carry real labels.
goto "$PLANE_URL/$WORKSPACE/" || exit 1
S=$(snap)
assert_contains "$S" '"(Open|Close) workspace menu"' "workspace menu disclosure labeled"
assert_contains "$S" '"(Open|Close) extended sidebar"' "extended sidebar toggle labeled"
finish
