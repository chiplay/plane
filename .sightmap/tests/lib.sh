#!/usr/bin/env bash
# Shared helpers for sightmap-driven UI smoke tests.
# Requirements: a running `sightmap browser start` session (headless is fine)
# against the app at $PLANE_URL, signed in unless the test says otherwise.

PLANE_URL="${PLANE_URL:-http://localhost:3000}"
WORKSPACE="${PLANE_WORKSPACE:-acme-corp}"
FAILURES=0

# The app is a client-rendered SPA: navigation lands on a loading shell first.
# Wait until the inner content region has real DOM before snapshotting.
wait_for_render() {
  local tries=0
  until sightmap browser eval 'document.querySelectorAll("main main *").length>50' 2>/dev/null | grep -q true; do
    tries=$((tries + 1))
    [ "$tries" -gt 30 ] && echo "  RENDER TIMEOUT" && return 1
    sleep 1
  done
}

# Wait until a specific CSS selector is present — for content that loads after
# the shell (lists, cards). Pass the selector with double quotes for attribute
# values; it is embedded in a single-quoted JS string.
wait_for_selector() {
  local sel="$1" tries=0
  until sightmap browser eval "!!document.querySelector('$sel')" 2>/dev/null | grep -q true; do
    tries=$((tries + 1))
    [ "$tries" -gt 30 ] && echo "  SELECTOR TIMEOUT: $sel" && return 1
    sleep 1
  done
}

goto() {
  sightmap browser navigate "$1" >/dev/null || return 1
  wait_for_render
}

snap() { sightmap snapshot 2>/dev/null; }

assert_contains() { # $1=haystack-cmd-output $2=pattern $3=label
  if echo "$1" | grep -qE "$2"; then
    echo "  ok    - $3"
  else
    echo "  FAIL  - $3 (pattern not found: $2)"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_not_contains() {
  if echo "$1" | grep -qE "$2"; then
    echo "  FAIL  - $3 (forbidden pattern present: $2)"
    FAILURES=$((FAILURES + 1))
  else
    echo "  ok    - $3"
  fi
}

finish() {
  if [ "$FAILURES" -gt 0 ]; then
    echo "RESULT: $FAILURES assertion(s) failed"
    exit 1
  fi
  echo "RESULT: all assertions passed"
}
