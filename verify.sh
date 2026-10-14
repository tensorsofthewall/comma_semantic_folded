#!/usr/bin/env bash
# Verify the committed archive, the manifest and the exact rebuild.  Optional: --decode <archive_dir> <out_dir> (needs GPU).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
ARC=submission/semantic_folded/archive.zip
SHA=b1b94e987e9430382e00e11d8f2a5402ffa5ed5788e7f4c4e90e59b046900eb6
RAW=0ee1022894874d59ddae232f31f873a483adcd8745e42a91054d6843a4df6701
PY="${PYTHON:-python3}"
fail=0
chk() { if [ "$2" = ok ]; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }

[ "$(stat -c %s "$ARC")" = 173316 ] && chk "archive size 173316" ok || chk "archive size" bad
[ "$(sha256sum "$ARC" | cut -d' ' -f1)" = "$SHA" ] && chk "archive sha256" ok || chk "archive sha256" bad
sha256sum -c --quiet MANIFEST.sha256 && chk "MANIFEST.sha256" ok || chk "MANIFEST.sha256" bad
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
"$PY" rebuild.py "$T/archive.zip" > "$T/rebuild.log" 2>&1 && chk "rebuild sha256" ok || { cat "$T/rebuild.log"; chk "rebuild sha256" bad; }
cmp "$T/archive.zip" "$ARC" && chk "rebuilt == committed (cmp)" ok || chk "cmp" bad

if [ "${1:-}" = "--decode" ]; then
  [ "$#" -eq 3 ] || { echo "usage: verify.sh --decode <archive_dir> <out_dir>" >&2; exit 2; }
  bash submission/semantic_folded/inflate.sh "$2" "$3" submission/semantic_folded/public_test_video_names.txt \
    && [ "$(sha256sum "$3/0.raw" | cut -d' ' -f1)" = "$RAW" ] && chk "decoded raw sha256" ok || chk "decoded raw sha256" bad
fi
[ "$fail" = 0 ] && echo "ALL PASS" || { echo "FAILED"; exit 1; }
