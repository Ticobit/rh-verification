#!/bin/bash
# Export determinism test for leanprover-community/riemann-hypothesis issue #6.
#
# Runs step 1 of the repository's README (the challenge export, same commands as
# its CI job) in two clones that live at different absolute paths, then compares
# the two exports with each other and with the published sha256.
#
# Usage:  ./challenge_export_test.sh
# Needs:  git, curl, and elan (https://github.com/leanprover/elan). Nothing is
#         installed by this script. Uses roughly 20 GB of disk and downloads
#         Mathlib's build cache.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HOME/.elan/env" ] && . "$HOME/.elan/env"

REPO="https://github.com/leanprover-community/riemann-hypothesis"
CANON="bd484ac9886a96f26b1d9a7a59ebd45b7a70d102c015d4f31f9302bbdd6ab2b9"
ROOT_A="$HOME/rh-export-test/a"
ROOT_B="/tmp/rh-export-test-b-$(id -u)/a/much/longer/build/directory"
EXPORTER_DIR="$HOME/rh-export-test/lean4export"
LOG="$HERE/export_test.log"
OUT="$HERE/EXPORT_TEST.md"

export LEAN_ABORT_ON_PANIC=1
export LAKE_ARTIFACT_CACHE=false
export MATHLIB_CACHE_GET_URL=https://cache.mathlib.org/mathlib4

exec > >(tee -a "$LOG") 2>&1
echo "=== run started $(date -u +%Y-%m-%dT%H:%M:%SZ)"

for t in git curl shasum lake; do
  command -v "$t" >/dev/null || { echo "Falta '$t'. Instale elan (ver instrucciones) y vuelva a correr."; exit 1; }
done
die() { echo "ERROR: $*"; exit 1; }

echo "== 1/5 clone A (shallow, about 1 GB on disk)"
if [ ! -d "$ROOT_A/riemann-hypothesis/.git" ]; then
  mkdir -p "$ROOT_A" && git clone --depth 1 "$REPO" "$ROOT_A/riemann-hypothesis" || die "clone A"
fi
COMMIT="$(git -C "$ROOT_A/riemann-hypothesis" rev-parse HEAD)"

echo "== 2/5 clone B at a different path, same commit"
if [ ! -d "$ROOT_B/riemann-hypothesis/.git" ]; then
  mkdir -p "$ROOT_B" && git clone --depth 1 "file://$ROOT_A/riemann-hypothesis" "$ROOT_B/riemann-hypothesis" || die "clone B"
fi
[ "$(git -C "$ROOT_B/riemann-hypothesis" rev-parse HEAD)" = "$COMMIT" ] || die "clones are at different commits"

echo "== 3/5 exporter: lean4export v4.33.0 built with the project's Lean"
if [ ! -x "$EXPORTER_DIR/.lake/build/bin/lean4export" ]; then
  [ -d "$EXPORTER_DIR/.git" ] || git clone --quiet --depth 1 --branch v4.33.0 https://github.com/leanprover/lean4export "$EXPORTER_DIR" || die "clone lean4export"
  cp "$ROOT_A/riemann-hypothesis/lean-toolchain" "$EXPORTER_DIR/lean-toolchain"
  (cd "$EXPORTER_DIR" && lake build lean4export) || die "build lean4export"
fi
EXPORTER="$EXPORTER_DIR/.lake/build/bin/lean4export"
EXPORTER_COMMIT="$(git -C "$EXPORTER_DIR" rev-parse HEAD)"

export_in() {  # $1 = clone directory
  cd "$1" || return 1
  if [ ! -s challenge.export ]; then
    lake exe mathlib/cache get || return 1
    lake build Challenge || return 1
    lake env "$EXPORTER" Challenge -- $(cat export-targets.txt) > challenge.export.tmp || return 1
    mv challenge.export.tmp challenge.export
  fi
}
echo "== 4/5 build Challenge and export, in A"
export_in "$ROOT_A/riemann-hypothesis" || die "export in A"
echo "== 5/5 build Challenge and export, in B"
export_in "$ROOT_B/riemann-hypothesis" || die "export in B"

row() {  # $1 = label, $2 = clone directory
  local f="$2/challenge.export" o="$2/.lake/build/lib/lean/Challenge.olean"
  local sha bytes lines osha verdict
  sha="$(shasum -a 256 "$f" | awk '{print $1}')"
  bytes="$(wc -c < "$f" | tr -d ' ')"
  lines="$(wc -l < "$f" | tr -d ' ')"
  osha="$( [ -f "$o" ] && shasum -a 256 "$o" | awk '{print $1}' || echo 'not found')"
  verdict="DIFFERENT"; [ "$sha" = "$CANON" ] && verdict="identical"
  echo "| $1 | \`$2\` | \`$sha\` | $bytes | $lines | $verdict | \`$osha\` |"
}
LEANV="$(cd "$ROOT_A/riemann-hypothesis" && lean --version 2>/dev/null)"
{
  echo "# Challenge export from two build directories"
  echo
  echo "Step 1 of the riemann-hypothesis README, run twice on one machine at two different absolute paths."
  echo
  echo "| Run | Build directory | sha256 of challenge.export | Bytes | Lines | vs published sha256 | sha256 of Challenge.olean |"
  echo "| --- | --- | --- | --- | --- | --- | --- |"
  row A "$ROOT_A/riemann-hypothesis"
  row B "$ROOT_B/riemann-hypothesis"
  echo
  echo "Published sha256 (README and CI of the repository): \`$CANON\`"
  echo
  echo "| Field | Value |"
  echo "| --- | --- |"
  echo "| Date (UTC) | $(date -u +%Y-%m-%dT%H:%M:%SZ) |"
  echo "| Repository commit | $COMMIT |"
  echo "| Lean | $LEANV |"
  echo "| lean4export | tag v4.33.0, commit $EXPORTER_COMMIT |"
  echo "| Machine | $(sysctl -n machdep.cpu.brand_string 2>/dev/null), $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 )) GB RAM |"
  echo "| OS | macOS $(sw_vers -productVersion 2>/dev/null) ($(uname -m)) |"
  echo
  echo "Scope: this is the challenge export (five statements with \`sorry\`), not the solution export."
  echo "Not sandboxed. Full output in export_test.log."
} > "$OUT"
echo
cat "$OUT"
echo
echo "Listo. Resultado en $OUT"
