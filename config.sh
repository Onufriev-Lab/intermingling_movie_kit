#!/bin/zsh
# ============================================================================
# intermingling_movie_kit — configuration
# Edit the paths + parameters below, then run:  ./render_movie.sh
# ============================================================================

# ---- INPUT TRAJECTORY -------------------------------------------------------
# Any VMD-readable trajectory (.vtf, .dcd, .xtc, .trr, .lammpstrj, .trj, ...).
# ==> SET THIS to the path of YOUR trajectory (an absolute path is safest).
TRAJECTORY="/path/to/your/trajectory.vtf"
# Optional topology/structure file — needed for coordinate-only formats
# (e.g. .trj/.dcd that don't embed the structure). Leave "" for self-contained
# files such as VTF.
TOPOLOGY=""

# ---- WHICH FRAMES -----------------------------------------------------------
SLICE_START=0        # first frame to render (0-based)
SLICE_COUNT=300     # how many frames (<=0 = all).  300 @ 30 fps = 10 s
STRIDE=1             # take every STRIDE-th frame

# ---- CHROMOSOMES (territories) ---------------------------------------------
# One index range per chromosome/arm (0-based, inclusive), comma-separated.
# Default = Drosophila 6 arms:  2L  2R  3L  3R  4  X
ARM_RANGES="0-224,228-440,441-661,665-971,974-992,993-1176"
# One RGB colour per range (r,g,b in 0..1), space-separated. MUST match the
# number of ranges above.  (default: red orange yellow green cyan blue)
ARM_COLORS_RGB="1.0,0.0,0.0 1.0,0.5,0.0 0.95,0.85,0.0 0.0,0.8,0.0 0.0,0.8,0.85 0.15,0.2,1.0"
OVERLAP_RGB="0.0,0.0,0.0"      # colour of the >=2 overlap solid (black)

# ---- LOOK -------------------------------------------------------------------
ISO=2.0              # density iso-level = territory "thickness" (higher = thinner)
ZOOM=1.5             # camera zoom (larger = closer)
SPIN_DEG=0           # total extra camera yaw over the whole movie (0 = fixed camera)
DX=0.12              # density grid spacing (sim units); SMALLER = finer wireframe mesh, slower
SIGMA=0.18           # Gaussian width per bead (sim units); larger = smoother shells

# ---- INTERMINGLING METRIC (used by ./compute_intermingling.sh) -------------
# Reports the intermingling index I = (voxels with >=2 chromosomes) /
# (voxels with >=1 chromosome).  Independent of the rendering look above.
MET_R=0.2            # per-bead footprint radius (sim units) — coarse-graining scale
MET_DX=0.1           # metric voxel size (sim units)
NSAMPLE=0         # how many frames to MEASURE, spread evenly from first to last
                     # frame (stride ~ total/NSAMPLE). If NSAMPLE <=0 OR >= the
                     # trajectory length, every frame is measured. Always spans the
                     # WHOLE file (ignores SLICE_* above).

# ---- OUTPUT -----------------------------------------------------------------
# Defaults are tuned for a FAST, small, submission-friendly draft (480p, < 20 MB
# for a ~10 s clip). To make a sharper / publication-quality movie, raise RES
# (720 / 1000), AA (8-12) and BITRATE (and lower DX above for a finer mesh).
# See "Increasing the quality" in the README for a full quality-vs-speed guide.
RES=480              # pixels (square). 480 = fast draft; 720 / 1000 = higher quality
AA=4                 # Tachyon anti-alias samples (higher = smoother, slower)
FPS=30               # movie frame rate
BITRATE=4000000      # H.264 bitrate (~5 MB per 10 s at 480p; scales with length)
OUTNAME="intermingling_movie.mp4"

# ---- TOOLS ------------------------------------------------------------------
# VMD loads the trajectory and (via its bundled Tachyon) ray-traces the frames.
# If `vmd` is on your PATH this finds it automatically; otherwise SET the full
# path to your VMD binary, e.g.:
#   macOS : /Applications/VMD*.app/Contents/vmd/vmd_MACOSXARM64   (or ..._X86_64)
#   Linux : /usr/local/bin/vmd   (or wherever you installed it)
VMD="$(command -v vmd 2>/dev/null || echo vmd)"
# Tachyon ray tracer — auto-found inside the VMD app bundle (macOS). If this ends
# up empty, SET the full path to your 'tachyon' binary (e.g. on Linux it lives in
# the VMD lib dir: .../vmd/tachyon_LINUXAMD64).
TACHYON="$(/usr/bin/find /Applications -maxdepth 6 -iname 'tachyon_*' -type f 2>/dev/null | head -1)"
