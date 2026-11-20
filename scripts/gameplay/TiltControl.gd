extends RefCounted
# Portrait phone: Android reports upward acceleration, so downhill is -X.
const DEAD_ZONE:=0.055
const FULL_TILT:=0.45
var filtered:=0.0
var available:=false
func sample(gravity: Vector3,accelerometer: Vector3,delta: float) -> float:
 var sensor:=gravity if gravity.length_squared()>1.0 else accelerometer
 available=sensor.length_squared()>1.0
 var downhill: float=-sensor.x/maxf(sensor.length(),1.0) if available else 0.0
 filtered=lerpf(filtered,clampf(downhill,-1,1),1.0-exp(-10.0*delta))
 var amount:=maxf(0,absf(filtered)-DEAD_ZONE)/(FULL_TILT-DEAD_ZONE)
 return signf(filtered)*clampf(amount,0,1)
func reset() -> void:
 filtered=0.0
