extends Node
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	Engine.physics_ticks_per_second=480
	Engine.time_scale=8
	Engine.max_physics_steps_per_frame=64
	for require_base in [false,true]:
		var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
		game.test_mode=true
		game.simulation_mode=true
		game.level_override=preload("res://scripts/generation/TrialLevels.gd").load_trial(1)
		game.level_override.finish_at_base=require_base
		add_child(game)
		for tick in 5: await get_tree().physics_frame
		# Create an unsupported vertical drop, then resolve the ordered meals.
		for y in range(350,1150,20): game.terrain.carve(Vector2(360,y)-game.terrain.position,105,true)
		game.terrain.rebuild()
		for mouse in game.mice: game.resolve_mouse(mouse)
		check(not game.ended,"last mouse does not immediately complete hunt; base="+str(require_base))
		for tick in 8: await get_tree().physics_frame
		check(not game.cat.supported and not game.ended,"Kitty keeps falling after the last meal; base="+str(require_base))
		var premature:=false
		for tick in 900:
			await get_tree().physics_frame
			if game.ended:
				premature=not game.cat.supported or game.last_meal_age<0.9 or game.landing_settle_time<0.35
				break
		check(game.hunt_complete and not premature,"success waits for meal and stable landing; base="+str(require_base))
		game.queue_free()
		await get_tree().process_frame
	print("HUNT LANDING RESULT: ",failures," failures")
	get_tree().quit(failures)
