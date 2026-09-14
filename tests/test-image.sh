#!/bin/bash
#
# Integration tests for the built image. Kodi itself cannot start without a
# display, so the entrypoint's start/stop logic is exercised against a fake
# kodi.bin (a copy of bash, so that `pidof kodi.bin` finds it).
#
# Usage: tests/test-image.sh            (after `make build`)
#   CONTAINER_RUNTIME=docker IMAGE=... tests/test-image.sh

set -euo pipefail

readonly runtime="${CONTAINER_RUNTIME:-podman}"
readonly image="${IMAGE:-just-barcodes/kodi}"

readonly fake_kodi_forever='cp /bin/bash /tmp/kodi.bin && /tmp/kodi.bin -c "while true; do sleep 1; done"'
readonly fake_kodi_exits_after_3s='cp /bin/bash /tmp/kodi.bin && /tmp/kodi.bin -c "sleep 3; true"'

failures=0

pass () { echo "PASS: $1"; }

fail () {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

dump () {
  while IFS= read -r line; do echo "    | $line"; done <<< "$1"
}

assert_contains () {  # description, haystack, needle
  if [[ $2 == *"$3"* ]]; then
    pass "$1"
  else
    fail "$1 (expected to find: '$3')"
    dump "$2"
  fi
}

assert_not_contains () {  # description, haystack, needle
  if [[ $2 != *"$3"* ]]; then
    pass "$1"
  else
    fail "$1 (did not expect to find: '$3')"
    dump "$2"
  fi
}

assert_eq () {  # description, expected, actual
  if [[ $2 == "$3" ]]; then
    pass "$1"
  else
    fail "$1 (expected '$2', got '$3')"
  fi
}

assert_less_than () {  # description, limit, actual
  if (( $3 < $2 )); then
    pass "$1"
  else
    fail "$1 (expected < $2, got $3)"
  fi
}

# Run a shell command inside the image, bypassing the entrypoint.
in_image () {
  "$runtime" run --rm --entrypoint bash "$image" -c "$1" 2>&1
}

# Start the image detached with the given `run` arguments, stop it after a
# moment, and record what happened in $logs and $stop_seconds.
logs=""
stop_seconds=""
run_then_stop () {  # stop-timeout, run args...
  local stop_timeout=$1 cid started
  shift
  cid=$("$runtime" run -d "$@" "$image")
  sleep 2
  started=$SECONDS
  "$runtime" stop -t "$stop_timeout" "$cid" > /dev/null
  stop_seconds=$((SECONDS - started))
  logs=$("$runtime" logs "$cid" 2>&1)
  "$runtime" rm "$cid" > /dev/null
}

test_kodi_binaries_present () {
  local out
  out=$(in_image 'test -x /usr/lib/*/kodi/kodi.bin && test -x /usr/bin/kodi-standalone && test -x /usr/bin/kodi-send && echo present')
  assert_eq "kodi.bin, kodi-standalone and kodi-send are installed" "present" "$out"
}

test_entrypoint_permissions () {
  local out
  out=$(in_image 'stat -c "%a %U" /usr/local/bin/entrypoint.sh')
  assert_eq "entrypoint is executable and owned by root" "755 root" "$out"
}

test_kodi_command_is_used () {
  local out
  out=$("$runtime" run --rm -e KODI_COMMAND="echo custom command ran" "$image" 2>&1)
  assert_contains "KODI_COMMAND replaces kodi-standalone" "$out" "custom command ran"
}

test_stop_when_kodi_not_running () {
  run_then_stop 10 -e KODI_COMMAND="sleep 300"
  assert_contains "stopping without Kodi running exits immediately" "$logs" "Kodi does not appear to be running"
  assert_less_than "stop is quick when Kodi is not running" 5 "$stop_seconds"
}

test_graceful_shutdown () {
  run_then_stop 20 -e KODI_QUIT_TIMEOUT=15 -e KODI_COMMAND="$fake_kodi_exits_after_3s"
  assert_contains "stop asks Kodi to quit" "$logs" "asking Kodi to quit"
  assert_contains "stop waits for Kodi to exit" "$logs" "Kodi terminated successfully"
  assert_less_than "stop returns as soon as Kodi has exited" 10 "$stop_seconds"
}

test_quit_timeout () {
  run_then_stop 20 -e KODI_QUIT_TIMEOUT=2 -e KODI_COMMAND="$fake_kodi_forever"
  assert_contains "stop gives up after KODI_QUIT_TIMEOUT" "$logs" "timeout of 2 second(s) reached"
  assert_less_than "stop does not wait much longer than KODI_QUIT_TIMEOUT" 8 "$stop_seconds"
}

main () {
  echo "Testing image '$image' with $runtime"
  for t in $(declare -F | awk '$3 ~ /^test_/ { print $3 }'); do
    echo "--- $t"
    "$t"
  done
  echo
  if (( failures > 0 )); then
    echo "$failures assertion(s) failed"
    exit 1
  fi
  echo "All tests passed"
}

main "$@"
