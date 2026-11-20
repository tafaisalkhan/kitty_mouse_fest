extends Node
const Levels=preload("res://scripts/generation/EndlessBurrows.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
var failures: Array=[]
var results: Array=[]
var game: Node
var trace_time:=0
func _ready() -> void:
	call_deferred("run")
func _process(_delta: float) -> void:
	if get_tree().paused: get_tree().paused=false
	if is_instance_valid(game): game.paused=false
	if is_instance_valid(game) and Time.get_ticks_msec()-trace_time>4000:
		trace_time=Time.get_ticks_msec()
		print("BURROW LIVE ",game.data.name," part=",game.section_index," eaten=",game.mice_eaten," cat=",game.cat.position)
func run() -> void:
	var signatures: Dictionary={}
	var worst_us:=0
	for number in range(1,1001):
		if number%25==0: await get_tree().process_frame
		var started:=Time.get_ticks_usec()
		var data:=Levels.build(number,number*104729)
		worst_us=maxi(worst_us,Time.get_ticks_usec()-started)
		var errors:=Validator.validate(data)
		if not errors.is_empty(): failures.append({"schema":number,"errors":Array(errors)})
		var signature:=JSON.stringify([data.terrain,data.mice.map(func(m):return [m.position,m.kind]),data.module_families]).sha256_text()
		if signatures.has(signature): failures.append({"duplicate":number,"previous":signatures[signature]})
		signatures[signature]=number
	for number in [1001,10001,1000000,2147483648]:
		if not Validator.validate(Levels.build(number,number*104729)).is_empty(): failures.append({"high_level":number})
	print("BURROW SCHEMA 1000 distinct layouts; worst build us=",worst_us)
	if not failures.is_empty():
		print("BURROW SCHEMA FAIL ",failures)
		get_tree().quit(1)
		return
	var normal: bool="--normal" in OS.get_cmdline_user_args()
	if not normal:
		Engine.physics_ticks_per_second=480
		Engine.time_scale=8
		Engine.max_physics_steps_per_frame=64
	var cases: Array=[]
	for family in range(10):
		for mirror in [0,1]: cases.append({"number":3+family,"family":family,"mirror":mirror,"screens":1,"growth":0})
	for number in [8,25,70,180,1001,10001]: cases.append({"number":number,"family":-1,"mirror":-1,"screens":0,"growth":0})
	if normal: cases=[{"number":1,"family":0,"mirror":0,"screens":1,"growth":0},{"number":1001,"family":-1,"mirror":-1,"screens":0,"growth":0}]
	for item in cases:
		var data:=Levels.build(item.number,item.number*104729,item.family,item.mirror,item.screens)
		data.name="%d family %d mirror %d"%[item.number,item.family,item.mirror]
		game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
		game.test_mode=true
		game.simulation_mode=not normal
		game.level_override=data
		add_child(game)
		for tick in 35: await get_tree().physics_frame
		var idle: bool=not game.ended and game.mice_eaten==0 and absf(game.cat.position.x-data.start_x)<1
		var result: Dictionary=await Tester.execute(game,data.solution,900)
		var bombs: bool=game.obstacles.values().all(func(o):return o.kind!="bomb" or o.activated)
		var passed: bool=idle and result.verified and bombs and game.hunt_complete and game.mice_eaten==data.mice.size() and game.transition_count==data.sections-1
		results.append({"number":item.number,"family":item.family,"mirror":item.mirror,"sections":data.sections,"mice":data.mice.size(),"passed":passed,"normal":normal})
		print("BURROW ",item," ","PASS" if passed else "FAIL"," eaten=",game.mice_eaten,"/",data.mice.size()," bombs=",bombs)
		if not passed:
			failures.append({"case":item,"position":[game.cat.position.x,game.cat.position.y],"eaten":game.mice_eaten,"ended":game.ended,"section":game.section_index,"mice":game.mice.map(func(m):return [m.config.id,m.position,m.eaten])})
			print("BURROW DETAIL ",failures[-1])
		game.queue_free()
		await get_tree().process_frame
	FileAccess.open("res://build/endless-burrows-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"results":results,"failures":failures,"schema_count":1000,"worst_build_us":worst_us},"\t"))
	if failures.is_empty():
		var path:="res://levels/endless/verification.json"
		var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		proof.version=Levels.VERSION
		proof.engine=Engine.get_version_info().string
		proof.schema_count=1000
		proof.worst_build_us=worst_us
		proof["normal_results" if normal else "fast_results"]=results
		proof["normal_passed" if normal else "fast_passed"]=true
		proof.hashes={}
		for file in ["scripts/generation/EndlessBurrows.gd","scripts/generation/HuntLevels.gd","scripts/generation/TrialLevels.gd","scripts/generation/LevelValidator.gd","scripts/generation/SolutionTester.gd","scripts/gameplay/HuntGameplay.gd","scripts/gameplay/Gameplay.gd","scripts/gameplay/SandTerrain.gd","scripts/gameplay/Kitten.gd","scripts/gameplay/Mouse.gd","scripts/gameplay/CatVisual.gd","scripts/gameplay/BallElasticity.gd","scripts/gameplay/WorldArt.gd","scripts/obstacles/Obstacle.gd","scripts/obstacles/RollingBomb.gd","scripts/obstacles/BeeChase.gd","scripts/obstacles/PropSkins.gd","scripts/obstacles/RockVisual.gd","assets/obstacles/props-v2.png","assets/obstacles/mechanisms-v2.png","assets/obstacles/bomb-v2.png","assets/obstacles/props-v2.frames.json","assets/obstacles/mechanisms-v2.frames.json","assets/obstacles/bomb-v2.frames.json","assets/obstacles/prop_alpha.gdshader","assets/characters/cat_ball_face.gdshader","assets/characters/ball_eye_tracking.gdshaderinc","assets/terrain/sculpted_sand.gdshader"]:
			proof.hashes[file]=FileAccess.get_sha256("res://"+file)
		for module in ["laser","bee","rock_switch","portal","water"]:
			var file: String="levels/endless/modules/"+str(module)+".json"
			proof.hashes[file]=FileAccess.get_sha256("res://"+file)
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(proof,"\t"))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels/endless/examples"))
		for number in [1,2,3,4,5,6,7,8,9,10,1001,10001,1000000]:
			FileAccess.open("res://levels/endless/examples/level_%07d.json"%number,FileAccess.WRITE).store_string(JSON.stringify(Levels.build(number,number*104729),"\t"))
	print("BURROW RESULT: ",results.size()," checked, ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
