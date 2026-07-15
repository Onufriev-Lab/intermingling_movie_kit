#!/usr/bin/env python3
# compute_intermingling.py  <trajectory> <out.csv> <arm_ranges> <R> <dx> [nsample]
#
# Computes the chromosome intermingling index for each analysed frame:
#
#   I = (voxels occupied by >=2 chromosomes) / (voxels occupied by >=1 chromosome)
#
# Each bead occupies every voxel within radius R of it (grid spacing dx); a voxel
# is "intermingled" when >=2 arms occupy it.  I is a dimensionless volume fraction.
#
#   trajectory : ordered VTF (or the "timestep"-delimited coord dump); each atom
#                line is "x y z", frames separated by a line starting "timestep".
#   arm_ranges : "0-224,228-440,441-661,665-971,974-992,993-1176"  (0-based, incl.)
#   R, dx      : footprint radius and voxel size (simulation units)
#   nsample    : if >0, sample this many frames at a uniform stride across the
#                whole trajectory (like the paper's 1000); if omitted/<=0, use
#                every frame.
import sys, math

traj, out_csv = sys.argv[1], sys.argv[2]
arms = [tuple(int(x) for x in p.split('-')) for p in sys.argv[3].split(',')]
R, dx = float(sys.argv[4]), float(sys.argv[5])
nsample = int(sys.argv[6]) if len(sys.argv) > 6 else 0
rr = int(round(R/dx))
offs = [(i, j, k) for i in range(-rr, rr+1) for j in range(-rr, rr+1) for k in range(-rr, rr+1)
        if i*i + j*j + k*k <= rr*rr]

def frac(coords):
    # per-frame origin -> small, non-negative voxel indices (robust packing)
    minx = miny = minz = 1e18
    for a, b in arms:
        for i in range(a, b+1):
            if i < len(coords):
                x, y, z = coords[i]
                if x < minx: minx = x
                if y < miny: miny = y
                if z < minz: minz = z
    if minx > 1e17: return 0.0
    ox = int(minx/dx)-rr-1; oy = int(miny/dx)-rr-1; oz = int(minz/dx)-rr-1
    counter = {}
    for (a, b) in arms:
        occ = set()
        for i in range(a, b+1):
            if i >= len(coords): continue
            x, y, z = coords[i]
            vi = int(round(x/dx))-ox; vj = int(round(y/dx))-oy; vk = int(round(z/dx))-oz
            for (di, dj, dk) in offs:
                occ.add(((vi+di) & 4095) << 24 | ((vj+dj) & 4095) << 12 | ((vk+dk) & 4095))
        for key in occ: counter[key] = counter.get(key, 0) + 1
    occupied = len(counter)
    shared = sum(1 for c in counter.values() if c >= 2)
    return shared/occupied if occupied else 0.0

# ---- which frames ----
targets = None
if nsample > 0:
    total = sum(1 for line in open(traj) if line[:8] == 'timestep')
    if total <= 0: sys.exit("compute_intermingling: no frames found in " + traj)
    if 1 < nsample < total:                     # subsample only when it actually thins
        targets = set(round(i*(total-1)/(nsample-1)) for i in range(nsample))
    # nsample >= total (or total <= 1): analyse every frame (targets stays None)

# ---- stream the trajectory, compute I on the selected frames ----
rows = []; fi = -1; cur = []; collect = False; started = False
for line in open(traj):
    if line[:8] == 'timestep':
        if collect and cur: rows.append((fi, frac(cur)))
        fi += 1; cur = []; started = True
        collect = (targets is None) or (fi in targets)
        continue
    if not started or not collect: continue
    t = line.split()
    if len(t) == 3:
        try: cur.append((float(t[0]), float(t[1]), float(t[2])))
        except ValueError: pass
if collect and cur: rows.append((fi, frac(cur)))
if not rows: sys.exit("compute_intermingling: no coordinates parsed from " + traj)

# ---- write per-frame CSV ----
with open(out_csv, 'w') as f:
    f.write("frame,intermingling\n")
    for fr, v in rows: f.write(f"{fr},{v:.5f}\n")

# ---- summary ----
vals = [v for _, v in rows]; n = len(vals); m = sum(vals)/n
sd = math.sqrt(sum((x-m)**2 for x in vals)/n)
sem = sd/math.sqrt(n)
print(f"frames analysed : {n}")
print(f"<intermingling> : {m:.4f}")
print(f"std             : {sd:.4f}")
print(f"SEM             : {sem:.5f}")
print(f"min / max       : {min(vals):.4f} / {max(vals):.4f}")
print(f"per-frame CSV   : {out_csv}")
