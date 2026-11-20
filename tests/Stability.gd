extends Node

const Tester=preload("res://scripts/generation/SolutionTester.gd")
var failures:=0
var samples: Array=[]
var live:=false
var deliberate_pause:=false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	live=OS.get_cmdline_user_args().has("--live")
	get_tree().current_scene=null
	call_deferred("run")

func _process(_delta: float) -> void:
	# A hidden test window can lose focus while the user works elsewhere.
	if get_tree().paused and not deliberate_pause:
		var game:=get_tree().current_scene
		if is_instance_valid(game): resume_game(game)

func check(value: bool,text: String) -> void:
	print("PASS " if value else "FAIL ",text)
	if not value: failures+=1

func spawn(level: int) -> Node:
	SaveManager.level_number=level
	SaveManager.daily_mode=false
	var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
	game.test_mode=true
	get_tree().root.add_child(game)
	get_tree().current_scene=game
	await get_tree().process_frame
	return game

func resume_game(game: Node) -> void:
	for child in game.overlay.get_children():
		if child is Button and child.text=="RESUME":
			child.pressed.emit()
			return
	get_tree().paused=false
	game.paused=false

func run() -> void:
	var start:=Time.get_ticks_msec()
	for i in 1000: AudioManager.play_fx("rescue")
	check(AudioManager.effect_voices.size()==12 and AudioManager.get_child_count()==13,"sound burst stays within 12 reusable voices")
	var cycles:=32 if not live else 12
	for cycle in cycles:
		var level: int=[6,5,4,3,2,1][cycle%6]
		var game: Node=await spawn(level)
		for tick in 60: await get_tree().physics_frame
		if cycle%4==0:
			deliberate_pause=true
			game.pause_game()
			await get_tree().process_frame
			check(get_tree().paused,"pause during long-play test")
			resume_game(game)
			deliberate_pause=false
		if cycle%3==0:
			# Exercise the real restart button and SceneTree reload lifecycle.
			game.hud.get_node("restart").pressed.emit()
			for frame in 3: await get_tree().process_frame
			game=get_tree().current_scene
			game.test_mode=true
			check(is_instance_valid(game.terrain),"restart reloads active gameplay")
		var outcome: Dictionary=await Tester.execute(game,game.data.solution)
		check(outcome.verified,"long-play rescue %d"%cycle)
		if outcome.verified: game.result_panel(true,3)
		for frame in 45:
			AudioManager.play_fx("rescue" if frame%2==0 else "bounce")
			await get_tree().process_frame
		get_tree().current_scene=null
		game.queue_free()
		for frame in 3: await get_tree().process_frame
		var sample: Dictionary={"cycle":cycle,"memory":OS.get_static_memory_usage(),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"voices":AudioManager.get_child_count()}
		samples.append(sample)
		check(sample.voices==13,"audio node count remains bounded %d"%cycle)
		if cycle%4==0: print("SOAK ",JSON.stringify(sample))
	if not live:
		var fresh: Dictionary=await LevelService.ensure_level(700007)
		check(not fresh.has("error") and fresh.get("verified",false),"tiny hidden viewport still verifies a complete rescue")
	if live:
		var game: Node=await spawn(6)
		while Time.get_ticks_msec()-start<120000:
			AudioManager.play_fx("dig")
			await get_tree().process_frame
		check(is_instance_valid(game) and is_inside_tree(),"two-minute real-time graphics and audio run survives")
		get_tree().current_scene=null
		game.queue_free()
		await get_tree().process_frame
	var growth: int=int(samples[-1].memory)-int(samples[mini(5,samples.size()-1)].memory)
	var node_growth: int=int(samples[-1].nodes)-int(samples[mini(5,samples.size()-1)].nodes)
	check(growth<8*1024*1024,"memory remains bounded after warm-up")
	check(node_growth<=4,"no accumulating scene nodes after restarts")
	var report:=FileAccess.open("res://tests/stability-live.json" if live else "res://tests/stability.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":failures,"cycles":cycles,"wall_seconds":(Time.get_ticks_msec()-start)/1000.0,"memory_growth":growth,"node_growth":node_growth,"samples":samples},"\t"))
	report.close()
	print("STABILITY RESULT: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
