extends Node2D
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var terrain=preload("res://scripts/gameplay/SandTerrain.gd").new()
	terrain.render_visuals=false
	add_child(terrain)
	terrain.setup({"brush_radius":28,"chambers":[[150,400,80],[360,400,65],[570,400,75]]})
	var kitty=preload("res://scripts/gameplay/Kitten.gd").new()
	kitty.configure({"id":"kitty","position":[150,400],"radius":50,"mass":4,"mother":true})
	add_child(kitty)
	var bomb=preload("res://scripts/obstacles/Obstacle.gd").new()
	add_child(bomb)
	bomb.setup({"id":"bomb","type":"bomb","position":[360,400],"radius":25})
	bomb.configure_chase([],terrain)
	var rock=preload("res://scripts/obstacles/Obstacle.gd").new()
	add_child(rock)
	rock.setup({"id":"rock","type":"falling_rock","position":[570,400],"radius":30})
	for tick in 150: await get_tree().physics_frame
	var bodies: Array=[kitty,bomb.body,rock.body]
	var before: Array=bodies.map(func(b):return b.global_position)
	check(bodies.all(func(b):return not b.can_sleep and not b.freeze),"all active loose bodies retain gravity after resting on sand")
	for i in bodies.size():
		# Three real narrow cuts remove support across the whole object width.
		for offset in [-40,0,40]:
			terrain.dig_segment(before[i]+Vector2(offset,20),before[i]+Vector2(offset,270))
	for tick in 100: await get_tree().physics_frame
	for i in bodies.size(): check(bodies[i].global_position.y>before[i].y+120,["Kitty","bomb","textured rock"][i]+" falls after its support is removed")
	check(not bomb.body.exploded,"a bomb falls normally through sand and waits for stone impact")
	print("LOOSE BODY PHYSICS RESULT: ",failures," failures")
	get_tree().quit(failures)
