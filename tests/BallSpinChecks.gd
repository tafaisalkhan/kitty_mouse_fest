extends Node
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	var spin=preload("res://scripts/gameplay/BallSpin.gd").new()
	for tick in 60: spin.advance(1.0/60,Vector2.ZERO,true)
	check(spin.angle==0 and spin.speed==0,"supported ball starts still")
	for tick in 40: spin.advance(1.0/60,Vector2(0,420),false)
	check(absf(spin.angle)>0.8,"a straight drop visibly rotates the ball")
	for tick in 90: spin.advance(1.0/60,Vector2.ZERO,true)
	check(spin.angle==0 and spin.speed==0,"landing settles rotation and stops spinning")
	for tick in 40: spin.advance(1.0/60,Vector2(-80,400),false)
	check(spin.speed<0,"leftward drop rotates in the matching direction")
	check(spin.advance(1.0/60,Vector2(80,400),false,true)==0,"reduce motion disables falling rotation")
	print("BALL SPIN RESULT: ",failures," failures")
	get_tree().quit(failures)
