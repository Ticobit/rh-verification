#!/bin/bash
# Independent check of the Alpöge RH/GRH Lean export with the Gruszka kernel.
# Usage:  ./verify.sh [workers]      (default: 8)
# Needs:  git, curl, and a Rust toolchain (cargo). Nothing is installed by this script.
set -uo pipefail
cd "$(dirname "$0")"

WORKERS="${1:-8}"
GRUSZKA_REPO="https://github.com/jasisz/gruszka"
SUSZ_URL="https://huggingface.co/datasets/jasisz/susz/resolve/main/susz-0.1/rh-alpoge-5ea74b91.susz"
SUSZ_FILE="rh-alpoge-5ea74b91.susz"
# sha256 shown on the Hugging Face file page (5.83 GB file)
SUSZ_SHA_EXPECTED="a5b17c25c97daf1ab1ed69addc1a0be09f1ccdd122e718c3a7670d9044d7aceb"

for t in git curl cargo shasum; do
  command -v "$t" >/dev/null || { echo "Falta '$t'. Instale Rust con rustup (https://rustup.rs) y vuelva a correr."; exit 1; }
done

echo "== 1/4 Gruszka: clone + build"
[ -d gruszka ] || git clone "$GRUSZKA_REPO" gruszka || exit 1
GRUSZKA_COMMIT="$(git -C gruszka rev-parse HEAD)"
(cd gruszka && cargo build --release) || { echo "Falló el build de Gruszka"; exit 1; }

echo "== 2/4 Download export (5.83 GB, resumable)"
curl -L --fail -C - -o "$SUSZ_FILE" "$SUSZ_URL"
rc=$?
# 33/416: server refuses the range because the file is already complete
if [ $rc -ne 0 ] && [ $rc -ne 33 ] && [ $rc -ne 22 ]; then echo "Falló la descarga (curl $rc)"; exit 1; fi

echo "== 3/4 sha256"
SUSZ_SHA="$(shasum -a 256 "$SUSZ_FILE" | awk '{print $1}')"
echo "computed: $SUSZ_SHA"
echo "expected: $SUSZ_SHA_EXPECTED"
if [ "$SUSZ_SHA" != "$SUSZ_SHA_EXPECTED" ]; then
  echo "El sha256 NO coincide. Compare con la página del archivo en Hugging Face antes de seguir."
  exit 1
fi

echo "== 4/4 Check with $WORKERS workers (cierre otras apps: usa mucha RAM)"
START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
/usr/bin/time -l gruszka/target/release/gruszka "$SUSZ_FILE" "$WORKERS" > run.stdout.log 2> run.stderr.log
EXIT=$?
END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
VERDICT="$(tail -n 1 run.stdout.log)"
REAL="$(awk '/ real /{print $1}' run.stderr.log | tail -n 1)"
RSS_BYTES="$(awk '/maximum resident set size/{print $1}' run.stderr.log | tail -n 1)"
RSS_GB="$(awk -v b="${RSS_BYTES:-0}" 'BEGIN{printf "%.1f", b/1073741824}')"
FOOT_BYTES="$(awk '/peak memory footprint/{print $1}' run.stderr.log | tail -n 1)"
FOOT_GB="$(awk -v b="${FOOT_BYTES:-0}" 'BEGIN{printf "%.1f", b/1073741824}')"

cat > RECEIPT.md <<R
# Gruszka check of the Alpöge RH/GRH Lean export

| Field | Value |
| --- | --- |
| Verdict (last line of stdout) | \`$VERDICT\` |
| Exit code | $EXIT |
| Started / finished (UTC) | $START / $END |
| Wall time | ${REAL:-?} s |
| Peak memory footprint | ${FOOT_GB} GiB |
| Max resident set size | ${RSS_GB} GiB |
| Workers | $WORKERS |
| Machine | $(sysctl -n machdep.cpu.brand_string 2>/dev/null), $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 )) GB RAM, $(sysctl -n hw.ncpu 2>/dev/null) cores |
| OS | macOS $(sw_vers -productVersion 2>/dev/null) ($(uname -m)) |
| Checker | $GRUSZKA_REPO @ $GRUSZKA_COMMIT |
| Rust | $(rustc --version 2>/dev/null) |
| Input | $SUSZ_FILE, sha256 $SUSZ_SHA |

## Scope
- Input is the Susz repack published by Gruszka's author of the solution export
  (solution.ndjson, sha256 5ea74b91…, from math.mit.edu/~drew/grh). I did not repack it myself.
- This checks that every declaration in the export type-checks in Gruszka.
  It does not compare the statements against the challenge file; that is what comparator does.
- Logs: run.stdout.log, run.stderr.log.
R

echo
echo "Verdict: $VERDICT (exit $EXIT). Recibo en RECEIPT.md"
exit $EXIT
