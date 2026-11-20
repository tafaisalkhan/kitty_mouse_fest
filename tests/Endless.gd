extends Node
const Generator=preload("res://scripts/generation/LevelGenerator.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Loader=preload("res://scripts/gameplay/LevelLoader.gd")
var failures:=0
var results: Array=[]

func check(value: bool,text: String) -> void:
	print("PASS " if value else "FAIL ",text)
	if not value: failures+=1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	for n in range(26,1026):
		var candidate:=Generator.candidate(n)
		check(Validator.validate(candidate).is_empty() and Validator.check_route(candidate).is_empty(),"candidate schema and route %d"%n)
	check(JSON.stringify(Generator.candidate(1000000))==JSON.stringify(Generator.candidate(1000000)),"high-level deterministic generation")
	check(Generator.candidate(40).sections==Generator.candidate(40,-1,1).sections and Generator.candidate(40).obstacles.size()==Generator.candidate(40,-1,1).obstacles.size(),"campaign retry retains screens and mechanics")
	var old:=SaveManager.progress.duplicate(true)
	SaveManager.daily_mode=false
	SaveManager.complete(200,3,20,1)
	check(SaveManager.progress.highest_unlocked>=201,"unlock after 200")
	SaveManager.complete(10000,3,20,1)
	check(SaveManager.read_valid("user://savegame.json",old).highest_unlocked>=10001,"save and reload after 10000")
	var menu=load("res://scenes/menus/LevelSelect.tscn").instantiate()
	add_child(menu)
	check(menu.world_index>=500,"level selection opens current endless world")
	remove_child(menu)
	menu.queue_free()
	SaveManager.progress=old
	SaveManager.atomic_save("user://savegame.json",old)
	var old_ticks:=Engine.physics_ticks_per_second
	var old_scale:=Engine.time_scale
	var baseline:=Generator.candidate(26)
	check(not Loader.cache_is_verified(baseline),"unverified candidates cannot be loaded from cache")
	# Authored levels 26–29 are covered by Advanced; these exercise generation.
	for n in [31,40,41,99,100,199,200,201,202,999,1000,1001,10000,123456,1000000]:
		var started:=Time.get_ticks_msec()
		var data: Dictionary=await LevelService.ensure_level(n)
		var valid:=not data.has("error") and Loader.cache_is_verified(data)
		check(valid,"runtime physics verification %d"%n)
		if valid:
			check(Loader.cache_is_verified(Loader.load_level(n)),"verified level cache replays %d"%n)
			var corrupt:=data.duplicate(true)
			corrupt.mother.position[0]+=20
			check(not Loader.cache_is_verified(corrupt),"reject altered verification cache %d"%n)
			results.append({"level":n,"verified":true,"attempts":LevelService.last_attempts,"seed":data.get("seed",n),"topology":data.get("topology","deep_rescue"),"seconds":data.verification.seconds,"generation_ms":Time.get_ticks_msec()-started})
		check(Engine.physics_ticks_per_second==old_ticks and Engine.time_scale==old_scale,"normal physics timing restored %d"%n)
	var daily: Dictionary=await LevelService.ensure_level(25,true)
	check(Loader.cache_is_verified(daily),"daily challenge is physics verified")
	SaveManager.level_number=900001
	SaveManager.daily_mode=false
	var playable=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
	playable.test_mode=true
	add_child(playable)
	while playable.loading: await get_tree().process_frame
	check(not playable.data.has("error") and is_instance_valid(playable.terrain) and playable.data.number==900001,"gameplay loads and verifies a new endless level")
	remove_child(playable)
	playable.queue_free()
	await get_tree().process_frame
	var report:=FileAccess.open("res://tests/endless-verification.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":failures,"samples":results},"\t"))
	report.close()
	print("ENDLESS RESULT: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
