#!/bin/zsh
# ============================================================================
# compute_intermingling.sh  --  report the intermingling index of a trajectory
# (no rendering).  Uses TRAJECTORY / ARM_RANGES / TOPOLOGY from config.sh and
# the metric parameters MET_R, MET_DX, NSAMPLE.
#
# Output:  output/intermingling.csv   (per-frame:  frame,intermingling)
#          + a printed <intermingling> +/- std summary.
#
# Optional: pass a trajectory path as the 1st argument to override config.sh.
# ============================================================================
set -e
DIR=${0:a:h}; cd "$DIR"
source ./config.sh
: ${MET_R:=0.2}; : ${MET_DX:=0.1}; : ${NSAMPLE:=1000}
[ -n "$1" ] && TRAJECTORY="$1"
[ -f "$TRAJECTORY" ] || { echo "!! TRAJECTORY not found: $TRAJECTORY  (edit config.sh or pass a path)"; exit 1; }
mkdir -p output work
CSV="output/intermingling.csv"

case "$TRAJECTORY" in
  *.vtf|*.VTF)
    SRC="$TRAJECTORY" ;;                       # VTF: parsed directly (streaming, low memory)
  *)
    echo "converting $TRAJECTORY via VMD ..."  # any other format: dump coords first
    SRC=work/metric_coords.txt
    TRAJ="$TRAJECTORY" TOPOLOGY="$TOPOLOGY" COORDS="$SRC" START=0 LAST=-1 STRIDE=1 \
      "$VMD" -dispdev text -e engine/dump_coords.tcl >/dev/null 2>&1 ;;
esac

echo "computing intermingling (R=$MET_R, dx=$MET_DX, nsample=$NSAMPLE) ..."
python3 engine/compute_intermingling.py "$SRC" "$CSV" "$ARM_RANGES" "$MET_R" "$MET_DX" "$NSAMPLE"
