#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <benchmark-target>" >&2
  exit 64
fi

readonly target="$1"
readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly benchmark_dir="${script_dir}/.."
readonly baseline_path="${BENCHMARK_BASELINE_PATH:-Baselines}"
readonly report_file="$(mktemp)"
readonly check_file="$(mktemp)"
trap 'rm -f "$report_file" "$check_file"' EXIT

set +e
(
  cd "$benchmark_dir"
  swift package --disable-automatic-resolution benchmark \
    --target "$target" \
    --format markdown \
    --path stdout \
    --no-progress
) 2>&1 | tee "$report_file"
report_status=${PIPESTATUS[0]}
set -e

if [[ $report_status -ne 0 ]]; then
  exit "$report_status"
fi

set +e
(
  cd "$benchmark_dir"
  swift package --disable-automatic-resolution benchmark \
    thresholds check \
    --target "$target" \
    --metric mallocCountTotal \
    --path "$baseline_path" \
    --format markdown \
    --no-progress
) 2>&1 | tee "$check_file"
status=${PIPESTATUS[0]}
set -e

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## ${target}"
    cat "$report_file"
    echo
    echo "### Allocation regression check"
    cat "$check_file"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [[ $status -eq 0 ]]; then
  exit 0
fi

if grep -q "benchmarkThresholdImprovement" "$check_file"; then
  echo "All threshold deviations are improvements."
  exit 0
fi

exit "$status"
