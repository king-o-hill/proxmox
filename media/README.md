# 🎬 Media Encoding

Scripts for converting remuxes and disc rips into files that **direct play** on
this setup, so Jellyfin and Plex never transcode on the fly.

These are unrelated to the container tooling in the repo root — they run inside
a container, not on the Proxmox host.

---

## 📁 What's Included

| File | Purpose |
|------|---------|
| `crf-sweep.sh` | Encodes one hard segment at several CRF values so you can compare and pick one before committing to a full pass |
| `encode-movie.sh` | The production encode: full film, correct track layout, HDR metadata carried through |

---

## 🎯 Target Profile

Chosen for the playback hardware here: **4K Fire TVs** and an **NVIDIA Shield**.

| Stream | Choice | Why |
|--------|--------|-----|
| Video | HEVC Main10, 10-bit | Direct plays on every device here. 10-bit is more efficient than 8-bit even from an 8-bit source, and reduces banding |
| HDR | HDR10, metadata preserved | Every display here is HDR-capable, so there is no SDR tone-mapping to avoid |
| Audio 1 | E-AC3 640k 5.1 (default) | What the Fire TVs will actually use; built-in Fire TV sets are limited on lossless passthrough |
| Audio 2 | Original track, copied | The Shield reaches past track 1 and bitstreams this to an AVR |
| Subtitles | Copied, **none flagged default** | A defaulted PGS track can force burn-in, which means a full video transcode |

**AV1 is deliberately not used.** The Shield's Tegra X1 has no AV1 hardware
decode, so an AV1 library would transcode on the best client in the house.
HEVC stays correct for the life of this hardware.

**Dolby Vision is not handled.** Profile 7 FEL from discs can be dropped safely
— the HDR10 base layer underneath is what these scripts keep. Profile 5 sources
(mostly streaming rips) have *no* HDR10 base layer, so stripping DV from one
leaves a green, washed-out picture. Check before encoding a P5 source.

---

## 🚀 Usage

### 1. Pick a CRF

Test on 2 minutes of the hardest content in the film — dark, grainy, high
motion. Not a bright establishing shot.

```bash
CRFS="18 20 22" ./crf-sweep.sh /media/movies/Example.mkv 00:04:30 120
```

Compare the outputs at 1:1 zoom, paused, on the display you actually watch on.
Look at dark detail, gradients for banding, and whether film grain survives.

### 2. Encode

```bash
CRF=20 ./encode-movie.sh /media/movies/Example.mkv /scratch/Example.hevc.mkv
```

Run it inside `tmux` — a 4K feature at `preset slow` takes many hours and a
dropped SSH session kills it.

### 3. Verify it direct plays

Play the result on a Fire TV and on the Shield, then check the Jellyfin
dashboard. It must read **Direct Play**, not Transcode. The dashboard is the
scoreboard; how the file looks is a separate question from whether it plays
without cooking the CPU.

---

## ⚙️ Options

Both scripts take the same environment overrides:

| Variable | Default | Notes |
|----------|---------|-------|
| `CRF` | 20 (2160p) / 19 (≤1080p) | Lower is higher quality and larger |
| `PRESET` | `slow` | `slower` for ~3–5% more efficiency at much longer runtime |
| `TUNE` | none | `grain` for grainy catalog titles — preserves grain but inflates bitrate |
| `ANIME` | `0` | `1` lowers psy-rd, which otherwise causes ringing on flat animation |
| `CRFS` | `18 20 22 24` | `crf-sweep.sh` only — values to try |
| `OUTDIR` | `./crf-sweep` | `crf-sweep.sh` only |
| `KEEP_LOSSLESS` | `1` | `encode-movie.sh` only — `0` drops the copied second audio track |

---

## ✅ Requirements

- `ffmpeg` built with `libx265`, plus `ffprobe` and `python3`
- Run in a dedicated container, not alongside Jellyfin/Plex — an encode pegs
  every core for hours and would starve the media servers it is meant to help
- Source media bind-mounted read-only; scratch space for output

```bash
apt install -y ffmpeg mediainfo tmux
```

---

## 📌 Notes

- Encoding is **CPU only**. Hardware encoders (NVENC/QSV/VAAPI) are built for
  throughput, not compression efficiency, and produce visibly worse results at
  the same file size. Use them for live transcoding, never for archival.
- `encode-movie.sh` refuses to overwrite an existing output file.
- If the source's first audio track is already AC3 or E-AC3, it is copied
  rather than re-encoded — there is nothing to gain from a second lossy pass.
- HDR detection is automatic, and the script prints the metadata it found.
  Getting this wrong is a silent failure that only shows up on playback.
