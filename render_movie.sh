#!/bin/zsh
# ============================================================================
# render_movie.sh  --  RUN ME
# Turn a trajectory into an intermingling wiremesh movie (coloured chromosome
# territories + solid black >=2-overlap), using the settings in config.sh.
# ============================================================================
set -e
DIR=${0:a:h}; cd "$DIR"
source ./config.sh

[ -f "$TRAJECTORY" ] || { echo "!! TRAJECTORY not found: $TRAJECTORY  (edit config.sh)"; exit 1; }
[ -x "$VMD" ] || command -v "$VMD" >/dev/null || { echo "!! VMD not found ($VMD) — set VMD in config.sh"; exit 1; }
[ -f "$TACHYON" ] || { echo "!! Tachyon not found — set TACHYON in config.sh"; exit 1; }

COORDS=work/coords.txt
DXROOT=work/dx; SCENEDIR=work/scenes; FRAMES=work/frames
rm -rf "$DXROOT" "$SCENEDIR" "$FRAMES" "$COORDS"
mkdir -p "$DXROOT" "$SCENEDIR" "$FRAMES" output

if [ "$SLICE_COUNT" -le 0 ]; then LAST=-1; else LAST=$(( SLICE_START + (SLICE_COUNT-1)*STRIDE )); fi

echo "[1/5] extracting coordinates with VMD ($TRAJECTORY) ..."
TRAJ="$TRAJECTORY" TOPOLOGY="$TOPOLOGY" COORDS="$COORDS" START="$SLICE_START" LAST="$LAST" STRIDE="$STRIDE" \
  "$VMD" -dispdev text -e engine/dump_coords.tcl >/dev/null 2>&1

echo "[2/5] building density + overlap grids ..."
python3 engine/gen_density.py "$COORDS" "$DXROOT" "$ARM_RANGES" "$DX" "$SIGMA"

echo "[3/5] writing wireframe scenes (VMD) ..."
DXROOT="$DXROOT" SCENEDIR="$SCENEDIR" ZOOM="$ZOOM" ISO="$ISO" SPIN_DEG="$SPIN_DEG" \
  ARM_COLORS_RGB="$ARM_COLORS_RGB" OVERLAP_RGB="$OVERLAP_RGB" \
  "$VMD" -dispdev text -e engine/render_wireframe.tcl >/dev/null 2>&1

echo "[4/5] ray-tracing frames (Tachyon, ${RES}px AA${AA}) ..."
for d in "$SCENEDIR"/f*.dat; do
  n=$(basename "$d" .dat)
  "$TACHYON" "$d" -res $RES $RES -aasamples $AA -o "$FRAMES/frame_${n#f}.tga" -format TARGA >/dev/null 2>&1
done
ls "$FRAMES"/frame_*.tga | xargs -P 8 -I {} sh -c 'f="{}"; sips -s format png "$f" --out "${f%.tga}.png" >/dev/null 2>&1'
rm -f "$FRAMES"/*.tga

echo "[5/5] encoding MP4 ..."
swift engine/frames_to_mp4.swift "$FRAMES" frame_ "$FPS" "output/$OUTNAME" "$BITRATE"
echo "DONE  ->  output/$OUTNAME"
