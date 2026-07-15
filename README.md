# Intermingling Movie Kit

Turn a coarse-grained chromosome trajectory into a movie in the **intermingling
wiremesh** representation: each chromosome (arm) drawn as a coloured **wireframe
territory**, and every region where **≥2 chromosomes overlap** filled as a
**solid black volume** (the intermingling volume). It's the moving version of
the still panels — one state, playing through time.

Works on macOS. Needs **VMD** installed (it provides the Tachyon ray tracer);
everything else (`python3`, `sips`, `swift`) is built into macOS. No ffmpeg.

---

## Run order

```
EDIT   ->  config.sh            (your trajectory, chromosome ranges, look)

RUN    ->  ./preview_frame.sh   (one still -> output/preview.png; tune ISO/ZOOM/colours)
RUN    ->  ./render_movie.sh    (the full movie -> output/intermingling_movie.mp4)

RUN    ->  ./compute_intermingling.sh   (optional — report the index; no rendering)
```

`render_movie.sh` does everything automatically:
1. **extract** the chosen frames' coordinates from your trajectory (via VMD, so
   any format works),
2. **build** a Gaussian density grid for every chromosome + a "shared" grid
   marking the ≥2-overlap voxels (`gen_density.py`),
3. **render** each frame — coloured wireframe isosurfaces + solid black overlap —
   ray-traced with Tachyon,
4. **encode** the PNG frames into an MP4 in `output/`.

Preview first with `./preview_frame.sh` (a single high-AA still) so you can dial
in `ISO`, `ZOOM` and colours before committing to the full render.

> **Run one render at a time.** All scripts share the `work/` scratch folder and
> wipe it when they start, so launching a second render (or the same one twice)
> while one is still going will clobber the first and can leave you with a
> truncated / 1-frame movie. Let a render finish before starting another.

---

## Files

| File | Role | You edit? |
|------|------|-----------|
| `config.sh` | trajectory path, frame range, chromosome ranges + colours, look, tools | **yes** |
| `preview_frame.sh` | **run me first** — one still to tune the look | no |
| `render_movie.sh` | **run me** — the full movie | no |
| `compute_intermingling.sh` | **run me** — report the intermingling index (no render) | no |
| `engine/compute_intermingling.py` | the metric: voxel occupancy → shared/occupied | no |
| `view_interactive.vmd` | open the look in the VMD GUI (after a preview) | no |
| `engine/dump_coords.tcl` | VMD loads the trajectory & writes per-frame coordinates | no |
| `engine/gen_density.py` | density grids per chromosome + the ≥2-overlap grid | no |
| `engine/render_wireframe.tcl` | writes the Tachyon scene for every frame | no |
| `engine/frames_to_mp4.swift` | PNG sequence → MP4 encoder | no |
| `work/` | scratch (coords, grids, frames) — safe to delete | — |
| `output/` | the finished `.mp4` and `preview.png` | — |

---

## Adapting to your simulation

Everything is in **`config.sh`**:

- **Input file.** Set `TRAJECTORY`. Any VMD-readable format works (`.vtf`,
  `.dcd`, `.xtc`, `.trr`, `.lammpstrj`, `.trj`, …). For **coordinate-only**
  formats that don't embed the structure (e.g. some `.trj`/`.dcd`), also set
  `TOPOLOGY` to a structure/topology file (`.psf`, `.parm7`, `.pdb`, …); VMD
  loads that first, then the trajectory. Self-contained files like VTF need no
  topology.

- **Which frames.** `SLICE_START`, `SLICE_COUNT` (`<=0` = all), `STRIDE`.
  300 frames at `FPS=30` gives a 10-second movie.

- **Chromosomes / territories.** `ARM_RANGES` is one 0-based, inclusive index
  range per chromosome, comma-separated
  (default = *Drosophila* 6 arms: 2L, 2R, 3L, 3R, 4, X). `ARM_COLORS_RGB` is one
  `r,g,b` colour per range (space-separated) — **must have the same count** as
  `ARM_RANGES`. `OVERLAP_RGB` is the colour of the ≥2 overlap solid (black by
  default). To use a different genome, just list its chromosome index ranges and
  as many colours.

- **Look.** `ISO` = density iso-level (higher → thinner territory shells);
  `ZOOM` = camera zoom; `SPIN_DEG` = extra camera yaw over the movie (0 = fixed
  camera; e.g. 360 = one full turn); `DX`/`SIGMA` = density grid spacing and
  Gaussian width.

- **Output.** `RES`, `AA` (anti-aliasing), `FPS`, `BITRATE`, `OUTNAME`.

- **Tools.** `VMD` and `TACHYON` are auto-detected; override the paths if needed.

---

## Increasing the quality (quality vs. speed)

The defaults are a **fast 480p draft** (small file, quick). To make a sharper /
publication-quality movie, raise these in `config.sh` — quality and render time
trade off:

| Knob (config.sh) | What it controls | Draft (default) | Good | Print / talk |
|---|---|---|---|---|
| `RES` | frame resolution (px) | 480 | 720 | 1000–1500 |
| `AA`  | anti-aliasing — smoothness of the wireframe lines | 4 | 8 | 12 |
| `BITRATE` | video compression — crispness of the thin lines | 4 Mbps | 8 Mbps | 16–24 Mbps |
| `DX`  | density-grid spacing — **mesh detail** (smaller = finer, slower) | 0.12 | 0.10 | 0.08 |
| `FPS` (+ frames) | motion smoothness | 30 | 30 | 30–60 |

Rules of thumb:
- **Sharper / less jagged** → raise `RES` **and** `AA` (biggest visual impact,
  and the biggest cost: doubling `RES` ≈ 4× the ray-trace time; `AA` scales
  roughly linearly).
- **Fewer compression artifacts** (thin lines going muddy) → raise `BITRATE`.
  Keep it high whenever `RES` is high, or the fine mesh smears.
- **Finer wireframe mesh** → lower `DX` (e.g. `0.10` or `0.08`); denser, smoother
  shells, but the density step gets slower. (`ISO` sets the shell *thickness*,
  not detail; `SIGMA` its smoothness.)
- **Smoother motion** → raise `FPS` and render more frames (or lower `STRIDE`).
- Bigger `RES`/`BITRATE`/frame-count ⇒ bigger file. Keep the 480p draft for a
  small (<20 MB) submission clip; use the higher settings for a supplementary
  high-res version.

A ready **print-quality** OUTPUT block (paste over the OUTPUT section in
`config.sh`, and set `DX=0.09` in the LOOK section):

```
RES=1200
AA=10
BITRATE=20000000
```

Always `./preview_frame.sh` after changing these — it renders one still at your
current settings so you can judge quality before the full render.

## How the representation is built (method)

For every frame, each chromosome's bead coordinates are convolved with an
isotropic Gaussian (width `SIGMA`) onto a common cubic grid of spacing `DX`,
giving a smooth density field per chromosome. Drawing a fixed iso-level contour
(`ISO`) of that field as a wireframe mesh gives each chromosome's visible
**territory**. The **overlap** field is formed by taking, at each voxel, the
*second-largest* of the per-chromosome densities — i.e. the region where at least
two territories are simultaneously above `ISO` — and is rendered as a solid
surface. A **single common grid** is used for all frames so the structure does
not jump or rescale during playback; the camera is fixed (orthographic) unless
`SPIN_DEG` is set.

This is the same construction used for the intermingling figures/panels; see the
project's `METHODS_intermingling` for the quantitative metric that accompanies it.

---

## Intermingling index (the metric)

`./compute_intermingling.sh` reports the **number** behind the pictures, straight
from a trajectory — no rendering. For every analysed frame it lays down a cubic
grid of spacing `MET_DX`, gives each bead a spherical footprint of radius `MET_R`
(a voxel is "occupied" by a chromosome if a bead of it lies within `MET_R`), and
computes

```
I = (voxels occupied by >=2 chromosomes) / (voxels occupied by >=1 chromosome)
```

— the fraction of the chromatin-occupied volume where territories overlap
(dimensionless, in [0,1]). It writes `output/intermingling.csv` (per-frame) and
prints `<intermingling> ± std` (plus SEM, min, max).

- **`NSAMPLE` = how many frames to measure, spread evenly from the first to the
  last frame of the file.** The tool counts the total frames `T`; if
  `NSAMPLE < T` it measures frames `0, ~T/NSAMPLE, ~2T/NSAMPLE, …, T-1` (stride
  ≈ `T/NSAMPLE`) — the CSV's `frame` column lists exactly which. If
  `NSAMPLE >= T` **or** `NSAMPLE <= 0`, every frame is measured.
  *Why sample:* consecutive MD frames are nearly identical, so an evenly-spaced
  set gives the trajectory average far faster than doing all frames.
  *Examples:* `T=109,183, NSAMPLE=1000` → every ~109th frame (1000 rows);
  `T=300, NSAMPLE=1000` → all 300; `NSAMPLE=0` → every frame.
  This is always over the **whole file** you point at (it ignores the movie's
  `SLICE_*` settings; to measure a portion, point it at a file of just that
  portion).
- Defaults `MET_R = 0.2`, `MET_DX = 0.1` (simulation units) reproduce the values
  reported in the paper. `MET_R` is the coarse-graining scale — the analogue of
  the cryosection thickness in cryo-FISH.
- VTF trajectories are streamed directly (low memory); other formats are
  auto-converted via VMD (set `TOPOLOGY` if the format is coordinate-only).
- Override the input on the command line:
  `./compute_intermingling.sh /path/to/other.vtf`

Note: this metric grid (`MET_DX`/`MET_R`, hard-sphere occupancy) is deliberately
distinct from the rendering grid (`DX`/`SIGMA`, Gaussian density) used to draw
the wireframes above.

---

## Output

- `output/preview.png` — a single still for tuning.
- `output/<OUTNAME>` — the movie (default `intermingling_movie.mp4`).

Typical timing (default 480 px, AA 4): ~1 s per frame; ~a few minutes for a
300-frame (10 s) movie. Raise `RES`/`AA` for print-quality, lower them for quick
drafts (see "Increasing the quality" above).

---

## Requirements

- **macOS** — the frame encoder uses the built-in `swift` (AVFoundation) and
  `sips`; `python3` ships with macOS. No ffmpeg needed.
- **VMD** — provides the trajectory loader and the Tachyon ray tracer:
  <https://www.ks.uiuc.edu/Research/vmd/>. Point `VMD`/`TACHYON` in `config.sh`
  at your install if they aren't auto-detected.

## Before you run

Edit `config.sh`: set `TRAJECTORY` to your trajectory (any VMD-readable format),
and set `ARM_RANGES` / `ARM_COLORS_RGB` for your chromosomes. Then
`./preview_frame.sh` to check the look, and `./render_movie.sh` for the movie
(or `./compute_intermingling.sh` for just the index). No trajectory is bundled —
bring your own.

## Citation

If this kit is useful in your work, please cite the associated publication and
the Onufriev Lab. (Wireframe rendering via VMD + Tachyon; Humphrey, Dalke &
Schulten, *J. Mol. Graphics* 1996.)
