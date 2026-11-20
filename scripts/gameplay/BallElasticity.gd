extends RefCounted

# Visual spring only: collision circles and gameplay sizes never change.
var deformation:=0.0
var spring_velocity:=0.0
var cooldown:=0.0
var spring_stiffness:=240.0
var spring_damping:=17.0
var air_stretch:=0.14
var impact_compression:=0.28

func land(speed: float) -> void:
	if speed<80 or cooldown>0: return
	var strength:=clampf(speed/620.0,0.15,1.0)
	deformation=-lerpf(0.08,impact_compression,strength)
	spring_velocity=-strength*0.7
	cooldown=0.10

func advance(delta: float,fall_speed: float,on_ground: bool,reduced:=false) -> Vector2:
	if reduced:
		deformation=0.0
		spring_velocity=0.0
		cooldown=0.0
		return Vector2.ONE
	cooldown=maxf(0,cooldown-delta)
	var target:=clampf(fall_speed/620.0,0,1)*air_stretch if not on_ground else 0.0
	# Small substeps keep the damped spring stable during uneven frame times.
	var remaining:=minf(delta,0.1)
	while remaining>0:
		var step:=minf(remaining,1.0/120.0)
		spring_velocity+=((target-deformation)*spring_stiffness-spring_velocity*spring_damping)*step
		deformation=clampf(deformation+spring_velocity*step,-0.32,0.18)
		remaining-=step
	var height:=1.0+deformation
	return Vector2(1.0/height,height)
