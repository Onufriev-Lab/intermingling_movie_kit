# dump_coords.tcl — load ANY VMD-readable trajectory and write the selected
# frames' atom coordinates to a plain text file that gen_density.py can read.
# Driven by env vars set in render_movie.sh:
#   TRAJ TOPOLOGY COORDS START LAST STRIDE
set trj    $::env(TRAJ)
set out    $::env(COORDS)
set start  $::env(START)
set last   $::env(LAST)
set stride $::env(STRIDE)
set top ""
if {[info exists ::env(TOPOLOGY)]} { set top $::env(TOPOLOGY) }

if {$top ne "" && $top ne "-"} {
  mol new $top waitfor all
  mol addfile $trj first $start last $last step $stride waitfor all
} else {
  mol new $trj first $start last $last step $stride waitfor all
}
set sel [atomselect top all]
set nf  [molinfo top get numframes]
set fp  [open $out w]
for {set f 0} {$f < $nf} {incr f} {
  $sel frame $f
  puts $fp "timestep"
  foreach c [$sel get {x y z}] { puts $fp $c }
}
close $fp
puts "dumped $nf frames -> $out"
quit
