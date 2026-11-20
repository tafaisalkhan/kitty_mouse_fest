extends Node2D
var failures:=0
var terrain: Node2D
var ended:=false
var section_transition:=false
var section_index:=0
var growth:=0
var simulation_mode:=true
var force_occluded:=false
var explosions:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func sight_clear(from: Vector2,to: Vector2) -> bool:
	if force_occluded: return false
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,1|4)).is_empty()
func encounter_mouse(_mouse: Node2D) -> void:
	pass
func detonate_world_bomb(point: Vector2,blast_radius: float) -> void:
	explosions+=1
	terrain.blast(point,blast_radius)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	terrain=preload("res://scripts/gameplay/SandTerrain.gd").new()
	terrain.render_visuals=false
	add_child(terrain)
	terrain.setup({"brush_radius":28,"chambers":[[390,500,40]],"rock_rects":[[300,650,180,40]],"solid_rects":[[540,650,80,40]]})
	var bomb=preload("res://scripts/obstacles/Obstacle.gd").new()
	add_child(bomb)
	bomb.setup({"id":"physical_bomb","type":"bomb","position":[390,500],"radius":25,"blast_radius":145})
	bomb.configure_chase([],terrain)
	for tick in 50: await get_tree().physics_frame
	check(not bomb.body.exploded and explosions==0,"a bomb resting on sand does not blast automatically")
	terrain.dig_segment(Vector2(390,520),Vector2(390,680))
	for tick in 150:
		await get_tree().physics_frame
		if bomb.activated: break
	for tick in 3: await get_tree().physics_frame
	check(bomb.activated and bomb.body.exploded and explosions==1,"digging releases a real bomb; stone impact detonates it once")
	check(terrain.cells.count(2)==0 and terrain.cells.count(3)>0,"impact blast opens breakable stone and preserves locked stone")
	bomb.queue_free()
	terrain.queue_free()
	await get_tree().physics_frame
	terrain=preload("res://scripts/gameplay/SandTerrain.gd").new()
	terrain.render_visuals=false
	add_child(terrain)
	terrain.setup({"brush_radius":28,"chambers":[[360,450,60],[360,610,65]]})
	var cat=preload("res://scripts/gameplay/Kitten.gd").new()
	cat.configure({"id":"kitty","position":[360,450],"radius":25,"mother":true})
	cat.freeze=true
	add_child(cat)
	var mouse=preload("res://scripts/gameplay/Mouse.gd").new()
	add_child(mouse)
	mouse.setup({"id":"mouse","position":[360,610],"radius":15,"required_growth":0,"growth":1,"section":0,"kind":"SMALL","flee_speed":32,"escape_distance":24},cat,terrain,self)
	mouse.set_body_palette(0)
	for tick in 50: await get_tree().physics_frame
	check(mouse.flee_count==0,"sealed sand blocks awareness of Kitty")
	var start_x: float=mouse.position.x
	terrain.dig_segment(Vector2(360,490),Vector2(360,620))
	var startled:=false
	for tick in 25:
		await get_tree().physics_frame
		startled=startled or mouse.velocity.y< -20
	check(mouse.fleeing and mouse.panic>=0.58 and mouse.flee_count>0,"opening sight to Kitty triggers visible fear")
	check(startled and absf(mouse.position.x-start_x)>5,"Kitty directly above causes a startle hop and sideways escape")
	check(mouse.quality_sprite.pose==2,"panic uses the frightened artwork pose")
	force_occluded=true
	for tick in 10: await get_tree().physics_frame
	check(mouse.fleeing,"briefly losing sight does not instantly cancel panic")
	print("BOMB AND PANIC RESULT: ",failures," failures")
	get_tree().quit(failures)
