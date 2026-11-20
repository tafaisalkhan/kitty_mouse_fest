extends Node
const Spring=preload("res://scripts/gameplay/BallElasticity.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	var spring=Spring.new()
	var shape:=Vector2.ONE
	for i in 40: shape=spring.advance(1.0/60,620,false)
	check(shape.y>1.10 and shape.x<0.93,"falling ball stretches tall and narrows")
	check(absf(shape.x*shape.y-1)<0.001,"stretch preserves apparent area")
	spring.land(620)
	shape=spring.advance(1.0/60,0,true)
	check(shape.x>1.25 and shape.y<0.80,"hard landing visibly presses ball wide and flat")
	var rebounded:=false
	for i in 120:
		shape=spring.advance(1.0/60,0,true)
		rebounded=rebounded or shape.y>1.01
	check(rebounded,"compressed ball rebounds through its round shape")
	check(shape.distance_to(Vector2.ONE)<0.001,"spring settles back to its original size")
	spring.land(500)
	check(spring.advance(1.0/60,500,false,true)==Vector2.ONE,"reduce motion disables squash and stretch")
	var art=preload("res://scripts/gameplay/QualitySprite.gd").new()
	add_child(art)
	art.deform_around_floor(Vector2(1.3,0.75),24)
	check(is_equal_approx(art.position.y+24*art.scale.y,24),"bottom stays planted while a supported ball squashes")
	print("BALL ELASTICITY RESULT: ",failures," failures")
	get_tree().quit(failures)
