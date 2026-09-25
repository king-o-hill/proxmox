#!/usr/bin/env bash
# encode-movie.sh — produce a direct-play file for Jellyfin/Plex on Fire TV 4K
# and NVIDIA Shield, from a remux or disc rip.
#
# Target profile:
#   video : HEVC Main10 (10-bit), HDR10 metadata carried from source
#   audio : track 1 = E-AC3 640k 5.1  (Fire TV safe, set as default)
#           track 2 = original audio copied  (Shield -> AVR passthrough)
#   subs  : copied, none flagged default  (a defaulted PGS track can force
#           burn-in on some clients, which means a full video transcode)
#
# Usage:
#   ./encode-movie.sh <input> [output]
#
# Environment overrides:
#   CRF=20            quality  (default: 20 for 2160p, 19 for <=1080p)
#   PRESET=slow       x265 preset
#   TUNE=grain        for grainy sources
#   ANIME=1           lower psy-rd for animation
#   KEEP_LOSSLESS=0   skip the copied second audio track

set -euo pipefail

INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
    echo "usage: $0 <input> [output]" >&2
    exit 1
fi
[[ -r "$INPUT" ]] || { echo "error: cannot read '$INPUT'" >&2; exit 1; }

OUTPUT="${2:-${INPUT%.*}.hevc.mkv}"
if [[ -e "$OUTPUT" ]]; then
    echo "error: '$OUTPUT' already exists — refusing to overwrite" >&2
    exit 1
fi

PRESET="${PRESET:-slow}"
TUNE="${TUNE:-}"
ANIME="${ANIME:-0}"
KEEP_LOSSLESS="${KEEP_LOSSLESS:-1}"

for bin in ffmpeg ffprobe python3; do
    command -v "$bin" >/dev/null || { echo "error: $bin not found" >&2; exit 1; }
done

# ---------------------------------------------------------------------------
# Probe video
# ---------------------------------------------------------------------------
read -r WIDTH HEIGHT TRANSFER PRIMARIES MATRIX <<<"$(
ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,color_transfer,color_primaries,color_space \
    -of json "$INPUT" | python3 -c '
import sys, json
s = (json.load(sys.stdin).get("streams") or [{}])[0]
g = lambda k: s.get(k) or "unknown"
print(g("width"), g("height"), g("color_transfer"), g("color_primaries"), g("color_space"))
')"

CRF="${CRF:-$([[ "${HEIGHT:-0}" -gt 1080 ]] && echo 20 || echo 19)}"

echo "=== Source ==="
echo "  ${WIDTH}x${HEIGHT}  transfer=${TRANSFER}"

# ---------------------------------------------------------------------------
# HDR metadata
# ---------------------------------------------------------------------------
IS_HDR=0
HDR_PARAMS=""
HDR_FFARGS=()

if [[ "$TRANSFER" == "smpte2084" || "$TRANSFER" == "arib-std-b67" ]]; then
    IS_HDR=1
    HDR_PARAMS=$(ffprobe -v error -select_streams v:0 -read_intervals "%+#1" \
        -show_frames -show_entries frame=side_data_list -of json "$INPUT" 2>/dev/null \
      | python3 -c '
import sys, json
from fractions import Fraction
def num(v, scale):
    try: return int(round(float(Fraction(str(v))) * scale))
    except Exception: return None
md = cll = None
try: d = json.load(sys.stdin)
except Exception: d = {}
for fr in d.get("frames", []):
    for sd in fr.get("side_data_list", []):
        t = (sd.get("side_data_type") or "").lower()
        if "mastering display" in t: md = sd
        elif "content light" in t: cll = sd
parts = []
if md:
    c = {k: num(md.get(k), 50000) for k in
         ("green_x","green_y","blue_x","blue_y","red_x","red_y","white_point_x","white_point_y")}
    lmax, lmin = num(md.get("max_luminance"), 10000), num(md.get("min_luminance"), 10000)
    if all(v is not None for v in c.values()) and lmax is not None and lmin is not None:
        parts.append("master-display=G({green_x},{green_y})B({blue_x},{blue_y})"
                     "R({red_x},{red_y})WP({white_point_x},{white_point_y})".format(**c)
                     + "L({},{})".format(lmax, lmin))
if cll and cll.get("max_content") is not None:
    parts.append("max-cll={},{}".format(cll["max_content"], cll["max_average"]))
print(":".join(parts))
')
    HDR_FFARGS=(-color_primaries "$PRIMARIES" -color_trc "$TRANSFER" -colorspace "$MATRIX")
    echo "  HDR: ${TRANSFER}"
    [[ -n "$HDR_PARAMS" ]] && echo "  metadata: ${HDR_PARAMS}" \
        || echo "  WARNING: no mastering-display metadata found in source"
else
    echo "  SDR"
fi

# ---------------------------------------------------------------------------
# Audio plan. If the source's first track is already AC3/E-AC3 there is nothing
# to gain by re-encoding it — copy it and skip the compatibility track.
# ---------------------------------------------------------------------------
read -r A_CODEC A_CHANNELS <<<"$(
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,channels \
    -of json "$INPUT" | python3 -c '
import sys, json
s = (json.load(sys.stdin).get("streams") or [{}])
if not s or not s[0]: print("none 0")
else: print(s[0].get("codec_name","none"), s[0].get("channels",0))
')"

echo "=== Audio ==="
echo "  source track 1: ${A_CODEC} ${A_CHANNELS}ch"

AUDIO_ARGS=()
if [[ "$A_CODEC" == "none" ]]; then
    echo "  no audio stream found — encoding video only"
    AUDIO_MAPS=(-an)
elif [[ "$A_CODEC" == "ac3" || "$A_CODEC" == "eac3" ]]; then
    echo "  already lossy DD/DD+ — copying as-is, no compatibility track needed"
    AUDIO_MAPS=(-map 0:a)
    AUDIO_ARGS=(-c:a copy)
else
    # E-AC3 downmix to 5.1; ffmpeg's native encoder caps at 5.1 channels.
    DOWNMIX=$([[ "${A_CHANNELS:-0}" -gt 6 ]] && echo 6 || echo "${A_CHANNELS:-6}")
    if [[ "$KEEP_LOSSLESS" == "1" ]]; then
        echo "  track 1 -> E-AC3 640k ${DOWNMIX}ch (default, Fire TV)"
        echo "  track 2 -> ${A_CODEC} copied (Shield passthrough)"
        AUDIO_MAPS=(-map 0:a:0 -map 0:a:0)
        AUDIO_ARGS=(-c:a:0 eac3 -b:a:0 640k -ac:a:0 "$DOWNMIX"
                    -metadata:s:a:0 title="Dolby Digital Plus 5.1"
                    -c:a:1 copy
                    -disposition:a:0 default -disposition:a:1 0)
    else
        echo "  track 1 -> E-AC3 640k ${DOWNMIX}ch (lossless track dropped)"
        AUDIO_MAPS=(-map 0:a:0)
        AUDIO_ARGS=(-c:a:0 eac3 -b:a:0 640k -ac:a:0 "$DOWNMIX" -disposition:a:0 default)
    fi
fi

# ---------------------------------------------------------------------------
# x265 parameters
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

echo "=== Encoding ==="
echo "  crf ${CRF}, preset ${PRESET}${TUNE:+, tune ${TUNE}}"
echo "  -> ${OUTPUT}"
echo

START_TS=$(date +%s)
ffmpeg -nostdin -hide_banner -loglevel warning -stats -y \
    -i "$INPUT" \
    -map 0:v:0 "${AUDIO_MAPS[@]}" -map "0:s?" \
    -c:v libx265 -preset "$PRESET" "${TUNE_ARGS[@]}" -crf "$CRF" \
    -pix_fmt yuv420p10le \
    "${HDR_FFARGS[@]}" \
    -x265-params "$X265P" \
    "${AUDIO_ARGS[@]}" \
    -c:s copy -disposition:s 0 \
    -map_chapters 0 \
    "$OUTPUT"

ELAPSED=$(( $(date +%s) - START_TS ))

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
IN_SZ=$(stat -c %s "$INPUT")
OUT_SZ=$(stat -c %s "$OUTPUT")
echo
echo "=== Done in $((ELAPSED/3600))h $(((ELAPSED%3600)/60))m ==="
python3 -c "
i, o = $IN_SZ, $OUT_SZ
print('  input : %8.2f GiB' % (i/1073741824))
print('  output: %8.2f GiB  (%.0f%% of source)' % (o/1073741824, 100.0*o/i))
"
echo
echo "  Track layout:"
ffprobe -v error -show_entries stream=index,codec_type,codec_name,channels:stream_disposition=default \
    -of csv=p=0 "$OUTPUT" | sed 's/^/    /'
