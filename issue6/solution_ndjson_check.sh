#!/bin/bash
# Checks the scan of issue #6 against the original MIT export instead of a repack.
#
#  1. downloads solution.ndjson.zst from the MIT audit page (7.7 GB, resumable)
#  2. checks its size and sha256, unpacks it, checks size and sha256 again
#  3. scans the ndjson line by line (axiom declarations, strings with / or \)
#  4. packs it to Susz and compares with the Susz file that Gruszka checked
#
# Usage:  ./solution_ndjson_check.sh        (long: leave it running)
# Needs:  curl, zstd, python3, cargo. Uses about 80 GB of disk in ~/rh-export-test/solution/.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
# keep the Mac awake while this runs
if [ -z "${RH_AWAKE:-}" ] && command -v caffeinate >/dev/null; then
  RH_AWAKE=1 exec caffeinate -i "$0" "$@"
fi

WORK="$HOME/rh-export-test/solution"; mkdir -p "$WORK"   # outside Documents on purpose
URL="https://math.mit.edu/~drew/grh/solution.ndjson.zst"
ZST="$WORK/solution.ndjson.zst";  ZST_BYTES=7699933588
ZST_SHA="61a8938ad5f5e57397c1c0e3b954916af546d9004ade01c3555744a681b05381"
ND="$WORK/solution.ndjson";       ND_BYTES=61570595788
ND_SHA="5ea74b912147c5c93cc2b6d70cc727cf908df2f62ac6a20480a3fa02f6be244e"
REF_SUSZ="$ROOT/rh-alpoge-5ea74b91.susz"
REF_SHA="a5b17c25c97daf1ab1ed69addc1a0be09f1ccdd122e718c3a7670d9044d7aceb"
CHALLENGE="$HOME/rh-export-test/a/riemann-hypothesis/challenge.export"
OUT="$HERE/SOLUTION_NDJSON_CHECK.md"; LOG="$HERE/solution_check.log"

say() { echo "$@"; echo "$(date -u +%H:%M:%SZ) $*" >> "$LOG"; }
die() { say "ERROR: $*"; exit 1; }
size() { wc -c < "$1" | tr -d ' '; }
sha() { if command -v openssl >/dev/null; then openssl dgst -sha256 "$1" | awk '{print $NF}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }

say "=== run started $(date -u +%Y-%m-%dT%H:%M:%SZ)"
for t in curl python3 zstd cargo; do
  command -v "$t" >/dev/null || die "falta '$t' (zstd se instala con: brew install zstd)"
done
FREE_GB="$(df -g "$WORK" | awk 'NR==2{print $4}')"
[ -f "$ND" ] || [ "${FREE_GB:-0}" -ge 85 ] || die "solo hay ${FREE_GB} GB libres; se necesitan unos 85"

say "== 1/5 download (7.7 GB; el servidor es lento, puede tardar una hora o mas)"
if [ ! -f "$ZST" ] || [ "$(size "$ZST")" != "$ZST_BYTES" ]; then
  curl -L --fail -C - --retry 40 --retry-delay 15 --retry-all-errors -o "$ZST" "$URL" || die "la descarga no termino; vuelva a correr el script para continuarla"
fi
[ "$(size "$ZST")" = "$ZST_BYTES" ] || die "tamano de $ZST: $(size "$ZST"), esperado $ZST_BYTES"
GOT_ZST_SHA="$(sha "$ZST")"
[ "$GOT_ZST_SHA" = "$ZST_SHA" ] || die "sha256 del .zst no coincide: $GOT_ZST_SHA"
say "   .zst: tamano y sha256 correctos"

say "== 2/5 unpack (61.6 GB) y sha256"
# zstd exits 0 on truncated input, so size and sha256 are checked before and after
if [ ! -f "$ND" ]; then
  zstd -d --long=30 -o "$ND.tmp" "$ZST" || die "zstd"
  mv "$ND.tmp" "$ND"
fi
[ "$(size "$ND")" = "$ND_BYTES" ] || die "tamano de solution.ndjson: $(size "$ND"), esperado $ND_BYTES"
GOT_ND_SHA="$(sha "$ND")"
[ "$GOT_ND_SHA" = "$ND_SHA" ] || die "sha256 de solution.ndjson no coincide: $GOT_ND_SHA"
say "   solution.ndjson: tamano y sha256 correctos"

say "== 3/5 control: el mismo scan sobre el challenge export (numeros conocidos)"
if [ -f "$CHALLENGE" ]; then
  python3 "$HERE/ndjson_scan.py" "$CHALLENGE" "$HERE/ndjson_scan_challenge.json" | tee -a "$LOG"
else
  say "   no encontre $CHALLENGE; se omite el control"
fi

say "== 4/5 scan de solution.ndjson (unos mil millones de lineas; paciencia)"
python3 "$HERE/ndjson_scan.py" "$ND" "$HERE/ndjson_scan_solution.json" | tee -a "$LOG" || die "scan"

say "== 5/5 repack a Susz y comparacion"
PACK="no se intento"; MY_SHA="-"; SUSZ_V="-"
if command -v susz >/dev/null || cargo install susz; then
  SUSZ_V="$(susz --version 2>/dev/null | head -n 1)"
  REF_NOW="$( [ -f "$REF_SUSZ" ] && sha "$REF_SUSZ" || echo "$REF_SHA")"
  for mode in "--no-index" ""; do
    rm -f "$WORK/mine.susz"
    if /usr/bin/time -l susz pack "$ND" "$WORK/mine.susz" $mode 2> "$WORK/pack.time"; then
      MY_SHA="$(sha "$WORK/mine.susz")"
      if [ "$MY_SHA" = "$REF_NOW" ]; then PACK="identico al archivo que reviso Gruszka (susz pack ${mode:-con indice})"; break
      else PACK="DIFERENTE (ultimo intento: susz pack ${mode:-con indice})"; fi
    else
      PACK="susz pack fallo (ver $WORK/pack.time)"; break
    fi
  done
  # Different container bytes (index, packer version) do not mean different content:
  # unpack both and compare what comes out.
  case "$PACK" in DIFERENTE*)
    if [ -f "$REF_SUSZ" ]; then
      say "   los .susz difieren; comparando el contenido desempacado (lento)"
      U_REF="$(susz unpack "$REF_SUSZ" - | openssl dgst -sha256 | awk '{print $NF}')"
      U_MINE="$(susz unpack "$WORK/mine.susz" - | openssl dgst -sha256 | awk '{print $NF}')"
      if [ -n "$U_REF" ] && [ "$U_REF" = "$U_MINE" ]; then
        PACK="archivos .susz distintos, pero el contenido desempacado es identico (sha256 $U_REF)"
      else
        PACK="DIFERENTE tambien al desempacar (ref $U_REF, mio $U_MINE)"
      fi
    fi ;;
  esac
  susz axioms "$WORK/mine.susz" --all > "$HERE/susz_axioms.txt" 2>&1 || true
else
  PACK="no se pudo instalar susz"
fi
say "   repack: $PACK"

{
  echo "# The scan, repeated on the original MIT export"
  echo
  echo "| Check | Result |"
  echo "| --- | --- |"
  echo "| solution.ndjson.zst | $ZST_BYTES bytes, sha256 \`$GOT_ZST_SHA\` (as published) |"
  echo "| solution.ndjson | $ND_BYTES bytes, sha256 \`$GOT_ND_SHA\` (as published) |"
  echo "| My Susz pack of it | sha256 \`$MY_SHA\`: $PACK |"
  echo "| susz | $SUSZ_V |"
  echo "| Date (UTC) | $(date -u +%Y-%m-%dT%H:%M:%SZ) |"
  echo "| Machine | $(sysctl -n machdep.cpu.brand_string 2>/dev/null), macOS $(sw_vers -productVersion 2>/dev/null) |"
  echo
  echo "Scan results: \`ndjson_scan_solution.json\` (and \`ndjson_scan_challenge.json\` as a control"
  echo "against the numbers already posted in the issue)."
} > "$OUT"
say "Listo. Resumen en $OUT"
cat "$OUT"
