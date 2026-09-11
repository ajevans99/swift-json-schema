#!/usr/bin/env bash

set -euo pipefail

readonly upstream_commit="478d5727c2a4048e835a29c65adecc7d795360d5"
readonly base_url="https://raw.githubusercontent.com/miloyip/nativejson-benchmark/${upstream_commit}/data"
readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly resource_dir="${script_dir}/../OrderedJSONBenchmarks/Resources"

checksum() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "error: shasum or sha256sum is required" >&2
    return 1
  fi
}

download() {
  local name="$1"
  local expected_checksum="$2"
  local destination="${resource_dir}/${name}.json"

  if [[ -f "$destination" ]] && [[ "$(checksum "$destination")" == "$expected_checksum" ]]; then
    echo "Verified ${name}.json"
    return
  fi

  local temporary
  temporary="$(mktemp "${resource_dir}/.${name}.XXXXXX")"
  if ! curl --fail --location --retry 3 --silent --show-error \
    "${base_url}/${name}.json" \
    --output "$temporary"
  then
    rm -f "$temporary"
    return 1
  fi

  local actual_checksum
  actual_checksum="$(checksum "$temporary")"
  if [[ "$actual_checksum" != "$expected_checksum" ]]; then
    echo "error: checksum mismatch for ${name}.json" >&2
    echo "expected: ${expected_checksum}" >&2
    echo "actual:   ${actual_checksum}" >&2
    rm -f "$temporary"
    return 1
  fi

  mv "$temporary" "$destination"
  echo "Downloaded and verified ${name}.json"
}

mkdir -p "$resource_dir"

download "canada" "f83b3b354030d5dd58740c68ac4fecef64cb730a0d12a90362a7f23077f50d78"
download "citm_catalog" "a73e7a883f6ea8de113dff59702975e60119b4b58d451d518a929f31c92e2059"
download "twitter" "a08b769f32b95f426cbc3abafcec65c1a19d3eb544d4ddf320eae142c99efc5d"
