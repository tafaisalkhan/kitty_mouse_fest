extends RefCounted

var angle:=0.0
var speed:=0.0
var direction:=1.0

func advance(delta: float,velocity: Vector2,on_ground: bool,reduced:=false) -> float:
	if reduced:
		angle=0.0
		speed=0.0
		return angle
	if on_ground:
		# Contact switches into the upright landing pose, so compression acts
		# vertically against the floor instead of tilting through the surface.
		speed=0.0
		angle=0.0
	else:
		if absf(velocity.x)>8: direction=signf(velocity.x)
		var target:=direction*clampf(absf(velocity.y)*0.007+absf(velocity.x)*0.008,1.5,4.5) if velocity.length()>65 else 0.0
		speed=move_toward(speed,target,delta*9)
		angle=wrapf(angle+speed*delta,-PI,PI)
	return angle
