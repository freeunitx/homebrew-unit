#!/usr/bin/env bash
set -u

if (( $# < 3 )); then
  echo "Usage: retry.sh <max_runs> <delay_seconds> <command> [args...]" >&2
  exit 2
fi

max_runs="$1"
delay_seconds="$2"
shift 2

for ((attempt = 1; attempt <= max_runs; attempt++)); do
  if "$@"; then
    exit 0
  fi
  if (( attempt < max_runs )); then
    sleep "${delay_seconds}"
  fi
done

exit 1
