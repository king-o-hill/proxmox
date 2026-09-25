#!/usr/bin/env bash
# crf-sweep.sh — encode the same segment at several CRF values so you can compare
# them side by side and pick one before committing to a full library pass.
#
# Usage:
#   ./crf-sweep.sh <input> [start-timecode] [duration-seconds]
#
# Example:
#   ./crf-sweep.sh /media/test/Meridian.mkv 00:04:30 120
#
# Environment overrides:
#   CRFS="18 20 22"    CRF values to try              (default: 18 20 22 24)
#   PRESET=slower      x265 preset                    (default: slow)
#   TUNE=grain         x265 tune, for grainy sources  (default: none)
#   ANIME=1            lower psy-rd for animation     (default: off)
#   OUTDIR=/scratch/x  where to write outputs         (default: ./crf-sweep)
#
# HDR metadata is detected from the source and carried through automatically.
# Getting that wrong is a silent failure, so the script prints what it found.

set -euo pipefail

INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
    echo "usage: $0 <input> [start-timecode] [duration-seconds]" >&2
    exit 1
fi
if [[ ! -r "$INPUT" ]]; then
    echo "error: cannot read '$INPUT'" >&2
    exit 1
fi

START="${2:-00:10:00}"
DUR="${3:-120}"
CRFS="${CRFS:-18 20 22 24}"
PRESET="${PRESET:-slow}"
TUNE="${TUNE:-}"
ANIME="${ANIME:-0}"
OUTDIR="${OUTDIR:-./crf-sweep}"

for bin in ffmpeg ffprobe python3; do
    command -v "$bin" >/dev/null || { echo "error: $bin not found in PATH" >&2; exit 1; }
done

mkdir -p "$OUTDIR"

# ---------------------------------------------------------------------------
# Probe the source
# ---------------------------------------------------------------------------
echo "=== Source ==="
SRC_JSON=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,pix_fmt,color_transfer,color_primaries,color_space,r_frame_rate \
    -show_entries format=duration -of json "$INPUT")

read -r WIDTH HEIGHT PIXFMT TRANSFER PRIMARIES MATRIX SRC_DUR <<<"$(
    printf '%s' "$SRC_JSON" | python3 -c '
import sys, json
d = json.load(sys.stdin)
s = (d.get("streams") or [{}])[0]
f = d.get("format") or {}
def g(k, default="unknown"):
    v = s.get(k)
    return v if v else default
print(g("width"), g("height"), g("pix_fmt"),
      g("color_transfer"), g("color_primaries"), g("color_space"),
      f.get("duration", "0"))
')"

printf '  %sx%s  %s  transfer=%s  primaries=%s\n' \
    "$WIDTH" "$HEIGHT" "$PIXFMT" "$TRANSFER" "$PRIMARIES"

# ---------------------------------------------------------------------------
# HDR detection. smpte2084 (PQ) or arib-std-b67 (HLG) means we must carry the
# mastering-display and content-light metadata through, or playback is wrong.
# ---------------------------------------------------------------------------
HDR_PARAMS=""
HDR_FFARGS=()
IS_HDR=0

if [[ "$TRANSFER" == "smpte2084" || "$TRANSFER" == "arib-std-b67" ]]; then
    IS_HDR=1
    SIDE_JSON=$(ffprobe -v error -select_streams v:0 -read_intervals "%+#1" \
        -show_frames -show_entries frame=side_data_list -of json "$INPUT" 2>/dev/null || echo '{}')

    HDR_PARAMS=$(printf '%s' "$SIDE_JSON" | python3 -c '
import sys, json
from fractions import Fraction

def num(v, scale):
    # ffprobe emits these as "34000/50000"; normalise to the x265 unit.
    try:
        return int(round(float(Fraction(str(v))) * scale))
    except Exception:
        return None

md = cll = None
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
for fr in d.get("frames", []):
    for sd in fr.get("side_data_list", []):
        t = (sd.get("side_data_type") or "").lower()
        if "mastering display" in t:
            md = sd
        elif "content light" in t:
            cll = sd

parts = []
if md:
    # chromaticity in units of 0.00002, luminance in units of 0.0001 cd/m2
    c = {k: num(md.get(k), 50000) for k in
         ("green_x","green_y","blue_x","blue_y","red_x","red_y","white_point_x","white_point_y")}
    lmax = num(md.get("max_luminance"), 10000)
    lmin = num(md.get("min_luminance"), 10000)
    if all(v is not None for v in c.values()) and lmax is not None and lmin is not None:
        parts.append(
            "master-display=G({green_x},{green_y})B({blue_x},{blue_y})"
            "R({red_x},{red_y})WP({white_point_x},{white_point_y})".format(**c)
            + "L({},{})".format(lmax, lmin))
if cll:
    mc, ma = cll.get("max_content"), cll.get("max_average")
    if mc is not None and ma is not None:
        parts.append("max-cll={},{}".format(mc, ma))

print(":".join(parts))
')

    HDR_FFARGS=(-color_primaries "$PRIMARIES" -color_trc "$TRANSFER" -colorspace "$MATRIX")

    echo "  HDR detected (${TRANSFER})"
    if [[ -n "$HDR_PARAMS" ]]; then
        echo "  carrying: ${HDR_PARAMS}"
    else
        echo "  WARNING: no mastering-display metadata found in the source."
        echo "           Output will be HDR-flagged but without static metadata."
    fi
else
    echo "  SDR source"
fi

# ---------------------------------------------------------------------------
# Build the x265 parameter string
# ---------------------------------------------------------------------------
PSY_RD=2.0
[[ "$ANIME" == "1" ]] && PSY_RD=1.0

X265P="aq-mode=3:aq-strength=0.9:psy-rd=${PSY_RD}:psy-rdoq=1.0"
X265P="${X265P}:no-sao=1:deblock=-1,-1:bframes=8:rc-lookahead=60"
if [[ "$IS_HDR" == "1" ]]; then
    X265P="${X265P}:hdr10=1:hdr10-opt=1:repeat-headers=1"
    X265P="${X265P}:colorprim=${PRIMARIES}:transfer=${TRANSFER}:colormatrix=${MATRIX}"
    [[ -n "$HDR_PARAMS" ]] && X265P="${X265P}:${HDR_PARAMS}"
fi

TUNE_ARGS=()
[[ -n "$TUNE" ]] && TUNE_ARGS=(-tune "$TUNE")

echo
echo "=== Encoding ==="
echo "  segment : ${START} +${DUR}s"
echo "  preset  : ${PRESET}${TUNE:+  tune: $TUNE}"
echo "  crfs    : ${CRFS}"
echo "  outdir  : ${OUTDIR}"
echo

# ---------------------------------------------------------------------------
# Sweep
# ---------------------------------------------------------------------------
declare -a RESULTS=()

for crf in $CRFS; do
    OUT="${OUTDIR}/crf${crf}.mkv"
    printf '  CRF %-3s ... ' "$crf"
    ELAPSED_START=$(date +%s)

    if ffmpeg -nostdin -loglevel error -y \
        -ss "$START" -t "$DUR" -i "$INPUT" \
        -map 0:v:0 -an -sn \
        -c:v libx265 -preset "$PRESET" "${TUNE_ARGS[@]}" -crf "$crf" \
        -pix_fmt yuv420p10le \
        "${HDR_FFARGS[@]}" \
        -x265-params "$X265P" \
        "$OUT" 2>"${OUTDIR}/crf${crf}.log"
    then
        ELAPSED=$(( $(date +%s) - ELAPSED_START ))
        BYTES=$(stat -c %s "$OUT")
        KBPS=$(python3 -c "print(round($BYTES*8/1000/$DUR))")
        printf 'done  %6.1f MiB  %6s kb/s  (%ss)\n' \
            "$(python3 -c "print($BYTES/1048576)")" "$KBPS" "$ELAPSED"
        RESULTS+=("$crf|$BYTES|$KBPS")
    else
        echo "FAILED — see ${OUTDIR}/crf${crf}.log"
        tail -3 "${OUTDIR}/crf${crf}.log" | sed 's/^/      /'
    fi
done

# ---------------------------------------------------------------------------
# Summary, with the number that actually matters: full-length size
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
printf '  %-6s %12s %12s %18s\n' "CRF" "segment" "bitrate" "est. full length"
printf '  %-6s %12s %12s %18s\n' "---" "-------" "-------" "----------------"
for r in "${RESULTS[@]}"; do
    IFS='|' read -r crf bytes kbps <<<"$r"
    EST=$(python3 -c "
d = float('$SRC_DUR') if '$SRC_DUR' not in ('', '0', 'unknown') else 0
print('%.1f GiB' % ($bytes / $DUR * d / 1073741824) if d else 'unknown source duration')
")
    printf '  %-6s %9.1f MiB %9s kb/s %18s\n' \
        "$crf" "$(python3 -c "print($bytes/1048576)")" "$kbps" "$EST"
done

echo
echo "Compare at 1:1 zoom, paused, on the display you actually watch on."
echo "Look at: dark detail, gradients/banding, and whether grain survives."
echo "Files: ${OUTDIR}/"
