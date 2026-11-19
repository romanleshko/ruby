#!/bin/zsh
# merge-embed.sh <ruby build dir> <core static lib> <output archive>
#
# Merges Ruby's core static library, the statically linked C extensions, their
# init table and the encoding tables into one archive an app can link, evicts
# the dummy Init_ext/Init_enc objects and verifies key symbols.
#
# Ruby's make leaves ~30 separate archives behind (the core, one per extension,
# the encodings). extinit.o defines the real Init_ext (registers every static
# extension); encinit.o defines the real Init_enc (libenc.a only has
# Init_encdb). dmyext.o / dmyenc.o are empty stand-ins used by miniruby; left in
# the archive they can win over the real ones, and `require 'zlib'` then fails
# at runtime.

set -euo pipefail

if (( $# != 3 )); then
  echo "usage: ${0:t} <ruby build dir> <core static lib> <output archive>" >&2
  exit 2
fi
bdir="$1" core="$2" out="$3"

local -a exts
exts=(${(f)"$(find "$bdir/ext" -name '*.a')"})
if (( ${#exts[@]} == 0 )); then
  echo "error: no ext archives found under $bdir/ext" >&2
  exit 1
fi

mkdir -p "${out:h}"
libtool -static -no_warning_for_no_symbols -o "$out" \
  "$core" \
  "$bdir/ext/extinit.o" \
  "${exts[@]}" \
  "$bdir/enc/encinit.o" \
  "$bdir/enc/libenc.a" \
  "$bdir/enc/libtrans.a"

ar -d "$out" dmyext.o dmyenc.o

# nm captured once: nm | grep -q under pipefail is a SIGPIPE trap (grep exits
# at the first match, nm dies mid-stream, the pipeline reports failure).
symtab="$(nm "$out" 2>/dev/null)"
for sym in _Init_ext _Init_enc _Init_zlib _Init_psych; do
  if ! grep -q "T $sym\$" <<< "$symtab"; then
    echo "error: $sym missing from $out" >&2
    exit 1
  fi
done
if ar -t "$out" | grep -qE '^dmy(ext|enc)\.o$'; then
  echo "error: dummy init objects still present in $out" >&2
  exit 1
fi

echo "    merged core + ${#exts[@]} ext archives + encodings → $out"
