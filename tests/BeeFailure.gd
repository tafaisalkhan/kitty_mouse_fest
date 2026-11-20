extends Node

var failures:=0

func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var room:=Node2D.new()
	add_child(room)
	var sand=load("res://scripts/gameplay/SandTerrain.gd").new()
	room.add_child(sand)
	sand.setup({"grid_size":10,"brush_radius":45,"chambers":[[200,500,80],[450,500,80]]})
	var mom=load("res://scripts/gameplay/CatVisual.gd").new()
	mom.mother=true
	mom.radius=45
	mom.position=Vector2(450,500)
	room.add_child(mom)
	var bee=load("res://scripts/obstacles/Obstacle.gd").new()
	room.add_child(bee)
	bee.setup({"id":"bee","type":"bee","position":[200,500],"radius":18})
	bee.configure_chase([],sand,mom)
	var hits: Array=[]
	bee.danger.connect(func(victim): hits.append(victim); bee.stop_for_result())
	for tick in 30: await get_tree().physics_frame
	check(bee.bee_chase.target==null and hits.is_empty(),"sealed terrain protects Mom")
	sand.dig_segment(Vector2(200,500),Vector2(450,500))
	for tick in 180: await get_tree().physics_frame
	print("BEE position=",bee.position," target=",bee.bee_chase.target," state=",bee.bee_chase.state," hits=",hits.size())
	check(hits.size()==1 and hits[0]==mom,"bee navigates open tunnel and attacks Mom once")
	mom.position=Vector2(450,700)
	sand.dig_segment(Vector2(200,500),Vector2(200,700))
	sand.dig_segment(Vector2(200,700),mom.position)
	var hunter=load("res://scripts/obstacles/Obstacle.gd").new()
	room.add_child(hunter)
	hunter.setup({"id":"detour","type":"bee","position":[200,500],"radius":18,"chase_speed":85})
	hunter.configure_chase([],sand,mom)
	var detour_hits: Array=[]
	hunter.danger.connect(func(victim): detour_hits.append(victim); hunter.stop_for_result())
	for tick in 300: await get_tree().physics_frame
	check(detour_hits.size()==1 and detour_hits[0]==mom,"bee takes bent tunnel around sealed direct route to Mom")
	check(hunter.position.y>630,"cached slow bee still pursues aggressively around bends")
	var baby=load("res://scenes/gameplay/Kitten.tscn").instantiate()
	baby.configure({"id":"baby","position":[450,500],"radius":21})
	baby.freeze=true
	room.add_child(baby)
	var baby_hunter=load("res://scripts/obstacles/Obstacle.gd").new()
	room.add_child(baby_hunter)
	baby_hunter.setup({"id":"baby_hunter","type":"bee","position":[200,500],"radius":18})
	baby_hunter.configure_chase([baby],sand,mom)
	var baby_hits: Array=[]
	baby_hunter.danger.connect(func(victim): baby_hits.append(victim); baby_hunter.stop_for_result())
	for tick in 180: await get_tree().physics_frame
	check(baby_hits.size()==1 and baby_hits[0]==baby,"bee selects and catches nearer reachable baby with Mom also available")
	room.queue_free()
	await get_tree().process_frame
	for victim_kind in ["mom","kitten"]:
		SaveManager.level_number=1
		var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
		game.test_mode=true
		add_child(game)
		await get_tree().process_frame
		check(game.bombs_left==0 and game.hud.get_node_or_null("bomb")==null,"no bomb tool on a level without stone walls")
		game.fail(game.mother_visual if victim_kind=="mom" else game.kittens[0])
		game.fail(game.kittens[0])
		check(game.ended and game.failure_pending and game.overlay.get_child_count()==0,victim_kind+" hit ends play without immediate popup")
		if victim_kind=="mom":
			check(game.mother_visual.defeated and not game.kittens[0].visual.defeated and game.kittens[0].visual.crying,"Mom hit: only Mom defeated, baby crying")
		else:
			check(game.kittens[0].visual.defeated and not game.mother_visual.defeated and game.mother_visual.crying,"baby hit: only baby defeated, Mom crying")
		if OS.get_cmdline_user_args().has("--capture"):
			await get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/bee-reaction-"+victim_kind+".png")
		await get_tree().create_timer(2.4 if OS.get_cmdline_user_args().has("--capture") else 2.8).timeout
		check(not game.failure_popup_shown,"failure popup waits at least 2.8 seconds")
		await get_tree().create_timer(0.45).timeout
		check(game.failure_popup_shown and game.overlay.get_child_count()>0,"failure popup appears after three seconds")
		if OS.get_cmdline_user_args().has("--capture"):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/bee-failure-popup.png")
		game.queue_free()
		await get_tree().process_frame
	print("BEE FAILURE RESULT: ",failures," failures")
	get_tree().quit(failures)
