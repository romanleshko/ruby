#!/bin/zsh
# stage-headers.sh <include tree> <config.h search root> <output dir>
#
# An xcframework slice allows exactly one Headers dir, but Ruby's headers need
# two include roots: the main tree (ruby.h, ruby/*.h) and an arch dir holding
# the generated ruby/config.h. The arch dir is named after the platform and,
# on macOS, the OS version (arm64-darwin27 on macOS 27), so it is looked up,
# never hard-coded. Each slice is single-arch, so config.h is copied into the
# main tree and the arch dirs are dropped.

set -euo pipefail

if (( $# != 3 )); then
  echo "usage: ${0:t} <include tree> <config.h search root> <output dir>" >&2
  exit 2
fi
tree="$1" root="$2" out="$3"

local -a configs
configs=(${(f)"$(find "$root" -path '*-darwin*/ruby/config.h')"})
if (( ${#configs[@]} != 1 )); then
  echo "error: expected exactly one *-darwin*/ruby/config.h under $root, found ${#configs[@]}:" >&2
  printf '         %s\n' "${configs[@]}" >&2
  echo "       (a stale arch dir after a macOS update? run: make -f apple/Makefile clean)" >&2
  exit 1
fi

rm -rf "$out"
mkdir -p "$out"
cp -R "$tree/." "$out/"
cp "${configs[1]}" "$out/ruby/config.h"
rm -rf "$out"/*-darwin*(N)

echo "    headers + ${configs[1]:h:h:t}/ruby/config.h → $out"
