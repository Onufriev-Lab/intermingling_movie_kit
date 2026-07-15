#!/usr/bin/env python3
# gen_density.py <coords_file> <out_root> <arm_ranges> <dx> <sigma>
#
# Builds, for every frame, one Gaussian density grid per chromosome (arm) plus a
# "shared" grid marking where >=2 chromosomes overlap (the intermingling volume).
# A single COMMON grid is used for all frames so the movie does not jump/scale.
#
#   coords_file : frames separated by a line starting "timestep", each atom "x y z"
#   arm_ranges  : "0-224,228-440,441-661,665-971,974-992,993-1176" (0-based, incl.)
#   dx          : grid spacing;  sigma : Gaussian width (simulation units)
import sys, os, math
from collections import Counter

coords_file, out_root = sys.argv[1], sys.argv[2]
arms = []
for part in sys.argv[3].split(','):
    a, b = part.split('-'); arms.append((int(a), int(b)))
dxg = float(sys.argv[4]); sigma = float(sys.argv[5]); margin = 0.5
narm = len(arms)

# --- read frames ---
frames = []; cur = []
for line in open(coords_file):
    if line[:8] == 'timestep':
        if cur: frames.append(cur); cur = []
        continue
    t = line.split()
    if len(t) == 3:
        try: cur.append((float(t[0]), float(t[1]), float(t[2])))
        except ValueError: pass
if cur: frames.append(cur)
if not frames: sys.exit("gen_density: no frames parsed from " + coords_file)

# --- common bounds over all frames (0.3-99.7 percentile => robust to outliers) ---
def _pc(a, p):
    s = sorted(a); return s[min(len(s)-1, max(0, int(p*(len(s)-1))))]
xs = []; ys = []; zs = []
for co in frames:
    for a, b in arms:
        for i in range(a, b+1):
            if i < len(co): xs.append(co[i][0]); ys.append(co[i][1]); zs.append(co[i][2])
ox, oy, oz = _pc(xs, 0.003)-margin, _pc(ys, 0.003)-margin, _pc(zs, 0.003)-margin
NX = int((_pc(xs, 0.997)+margin-ox)/dxg)+1
NY = int((_pc(ys, 0.997)+margin-oy)/dxg)+1
NZ = int((_pc(zs, 0.997)+margin-oz)/dxg)+1
N = NX*NY*NZ; rad = int(3*sigma/dxg)+1; inv = 1.0/(2*sigma*sigma)

def idx(i, j, k): return (i*NY+j)*NZ+k
def writedx(fn, g):
    with open(fn, 'w') as f:
        f.write(f"object 1 class gridpositions counts {NX} {NY} {NZ}\norigin {ox} {oy} {oz}\n")
        f.write(f"delta {dxg} 0 0\ndelta 0 {dxg} 0\ndelta 0 0 {dxg}\n")
        f.write(f"object 2 class gridconnections counts {NX} {NY} {NZ}\n")
        f.write(f"object 3 class array type double rank 0 items {N} data follows\n")
        b = []
        for v in range(N):
            b.append(f"{g[v]:.3f}")
            if len(b) == 3: f.write(" ".join(b)+"\n"); b = []
        if b: f.write(" ".join(b)+"\n")
        f.write('attribute "dep" string "positions"\nobject "d" class field\n')

for fidx, co in enumerate(frames):
    fdir = f"{out_root}/f{fidx:04d}"; os.makedirs(fdir, exist_ok=True)
    grids = [[0.0]*N for _ in range(narm)]; touched = [set() for _ in range(narm)]
    for ai, (a, b) in enumerate(arms):
        g = grids[ai]; ts = touched[ai]
        for i in range(a, b+1):
            if i >= len(co): continue
            x, y, z = co[i]
            cix = int((x-ox)/dxg); ciy = int((y-oy)/dxg); ciz = int((z-oz)/dxg)
            for ix in range(max(0, cix-rad), min(NX, cix+rad+1)):
                vx = ox+ix*dxg
                for iy in range(max(0, ciy-rad), min(NY, ciy+rad+1)):
                    vy = oy+iy*dxg
                    for iz in range(max(0, ciz-rad), min(NZ, ciz+rad+1)):
                        ii = idx(ix, iy, iz)
                        g[ii] += math.exp(-((vx-x)**2+(vy-y)**2+(oz+iz*dxg-z)**2)*inv); ts.add(ii)
    cnt = Counter()
    for ts in touched:
        for v in ts: cnt[v] += 1
    shared = [0.0]*N
    for v, c in cnt.items():
        if c >= 2:
            vals = sorted((grids[k][v] for k in range(narm)), reverse=True)
            shared[v] = vals[1]                       # 2nd-largest density = where >=2 overlap
    for k in range(narm): writedx(f"{fdir}/arm{k}.dx", grids[k])
    writedx(f"{fdir}/shared.dx", shared)
print(f"gen_density: {len(frames)} frames, {narm} arms, grid {NX}x{NY}x{NZ}")
