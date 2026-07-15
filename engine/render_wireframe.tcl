# render_wireframe.tcl — one VMD session; for every frame's density grids, write
# a Tachyon scene: each chromosome as a coloured WIREFRAME isosurface + the
# overlap (>=2) region as a SOLID surface.  Env vars (set by render_movie.sh):
#   DXROOT SCENEDIR ZOOM ISO SPIN_DEG ARM_COLORS_RGB OVERLAP_RGB
set dxroot   $::env(DXROOT)
set scenedir $::env(SCENEDIR)
set zoom     $::env(ZOOM)
set iso      $::env(ISO)
set spin     $::env(SPIN_DEG)
set colspec  $::env(ARM_COLORS_RGB)
set ovspec   [split $::env(OVERLAP_RGB) ,]
set narm     [llength $colspec]

# arm colours -> ColorID 1..narm ; overlap -> ColorID 16
for {set i 0} {$i < $narm} {incr i} {
  set c [split [lindex $colspec $i] ,]
  color change rgb [expr {$i+1}] [lindex $c 0] [lindex $c 1] [lindex $c 2]
}
color change rgb 16 [lindex $ovspec 0] [lindex $ovspec 1] [lindex $ovspec 2]

color Display Background white
axes location off
display projection Orthographic
display depthcue off
display shadows off
display ambientocclusion on
display aoambient 0.9
display aodirect 0.3

set dirs [lsort [glob $dxroot/f*]]
set nf [llength $dirs]
set denom [expr {$nf > 1 ? $nf-1 : 1}]
set fi 0
foreach fd $dirs {
  set n [file tail $fd]
  set m [mol new $fd/arm0.dx type dx waitfor all]
  for {set k 1} {$k < $narm} {incr k} { mol addfile $fd/arm$k.dx type dx waitfor all }
  mol addfile $fd/shared.dx type dx waitfor all
  mol delrep 0 $m
  for {set k 0} {$k < $narm} {incr k} {
    mol representation Isosurface $iso $k 0 1 2 1
    mol color ColorID [expr {$k+1}]; mol selection {all}; mol material Opaque; mol addrep $m
  }
  mol representation Isosurface $iso $narm 0 0 1 1
  mol color ColorID 16; mol material AOShiny; mol addrep $m
  display resetview
  set yaw [expr {25.0 + $spin*double($fi)/$denom}]
  molinfo $m set rotate_matrix [list [transmult [transaxis x 12] [transaxis y $yaw]]]
  scale by $zoom
  render Tachyon $scenedir/$n.dat {true %s}
  mol delete $m
  incr fi
}
puts "rendered $nf scenes -> $scenedir"
quit
