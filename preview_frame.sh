#!/bin/zsh
# ============================================================================
# preview_frame.sh  --  render ONE still frame (middle of the chosen slice) so
# you can tune ISO / ZOOM / colours quickly before the full movie.
# Output: output/preview.png
# ============================================================================
set -e
DIR=${0:a:h}; cd "$DIR"
source ./config.sh
[ -f "$TRAJECTORY" ] || { echo "!! TRAJECTORY not found: $TRAJECTORY  (edit config.sh)"; exit 1; }

COORDS=work/preview_coords.txt
DXROOT=work/preview_dx; SCENEDIR=work/preview_scenes
rm -rf "$DXROOT" "$SCENEDIR" "$COORDS"; mkdir -p "$DXROOT" "$SCENEDIR" output

# one frame at the middle of the requested slice
if [ "$SLICE_COUNT" -le 0 ]; then MID=$SLICE_START; else MID=$(( SLICE_START + (SLICE_COUNT/2)*STRIDE )); fi
echo "previewing frame $MID ..."
TRAJ="$TRAJECTORY" TOPOLOGY="$TOPOLOGY" COORDS="$COORDS" START="$MID" LAST="$MID" STRIDE=1 \
  "$VMD" -dispdev text -e engine/dump_coords.tcl >/dev/null 2>&1
python3 engine/gen_density.py "$COORDS" "$DXROOT" "$ARM_RANGES" "$DX" "$SIGMA"
DXROOT="$DXROOT" SCENEDIR="$SCENEDIR" ZOOM="$ZOOM" ISO="$ISO" SPIN_DEG=0 \
  ARM_COLORS_RGB="$ARM_COLORS_RGB" OVERLAP_RGB="$OVERLAP_RGB" \
  "$VMD" -dispdev text -e engine/render_wireframe.tcl >/dev/null 2>&1
"$TACHYON" "$SCENEDIR"/f0000.dat -res $RES $RES -aasamples 8 -o work/preview.tga -format TARGA >/dev/null 2>&1
sips -s format png work/preview.tga --out output/preview.png >/dev/null 2>&1
rm -f work/preview.tga
echo "DONE  ->  output/preview.png"
