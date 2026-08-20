#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly benchmark_dir="${script_dir}/.."
readonly baseline_dir="${BENCHMARK_BASELINE_PATH:-${benchmark_dir}/Baselines}"

missing=0
current_target=""

while IFS= read -r line; do
  if [[ "$line" =~ ^Target\ \'([^\']+)\'\ available\ benchmarks:$ ]]; then
    current_target="${BASH_REMATCH[1]}"
    continue
  fi

  if [[ -n "$current_target" ]] && [[ "$line" =~ ^(parse|serialize|roundtrip|construct|validate|output)\. ]]; then
    threshold_file="${baseline_dir}/${current_target}.${line}.p90.json"
    if [[ ! -f "$threshold_file" ]]; then
      echo "Missing benchmark threshold: ${threshold_file}" >&2
      missing=1
    fi
  fi
done < <(
  cd "$benchmark_dir"
  swift package --disable-automatic-resolution benchmark list --no-progress
)

exit "$missing"
