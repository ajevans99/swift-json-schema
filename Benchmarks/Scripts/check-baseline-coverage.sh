#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly benchmark_dir="${script_dir}/.."
readonly baseline_dir="${BENCHMARK_BASELINE_PATH:-${benchmark_dir}/Baselines}"

# Exit codes: 0 for complete coverage, 1 for missing files, 2 for discovery errors.
missing=0
benchmark_count=0
current_target=""

if ! benchmark_list="$(
  cd "$benchmark_dir"
  swift package --disable-automatic-resolution benchmark list --no-progress
)"; then
  echo "Failed to list benchmark targets." >&2
  exit 2
fi

while IFS= read -r line; do
  if [[ "$line" =~ ^Target\ \'([^\']+)\'\ available\ benchmarks:$ ]]; then
    current_target="${BASH_REMATCH[1]}"
    continue
  fi

  if [[ -n "$current_target" ]] && [[ "$line" =~ ^(parse|serialize|roundtrip|construct|validate|output)\. ]]; then
    benchmark_count=$((benchmark_count + 1))
    threshold_file="${baseline_dir}/${current_target}.${line}.p90.json"
    if [[ ! -f "$threshold_file" ]]; then
      echo "Missing benchmark threshold: ${threshold_file}" >&2
      missing=1
    fi
  fi
done <<< "$benchmark_list"

if [[ "$benchmark_count" -eq 0 ]]; then
  echo "No benchmarks found in benchmark list output." >&2
  exit 2
fi

exit "$missing"
