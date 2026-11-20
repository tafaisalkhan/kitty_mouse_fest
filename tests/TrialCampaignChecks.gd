extends Node
const Trials=preload("res://scripts/generation/TrialLevels.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
const MECHANICS_FILES=["scripts/gameplay/Gameplay.gd","scripts/gameplay/HuntGameplay.gd","scripts/gameplay/Kitten.gd","scripts/gameplay/CatVisual.gd","scripts/gameplay/Mouse.gd","scripts/gameplay/SandTerrain.gd","scripts/obstacles/Obstacle.gd","scripts/obstacles/RollingBomb.gd","scripts/obstacles/BeeChase.gd","scripts/generation/TrialLevels.gd","scripts/generation/LevelValidator.gd","scripts/generation/SolutionTester.gd"]
var failures: Array=[]
var results: Array=[]
var active_game: Node
var trace_time:=0
var captured_panic:=false
func _ready() -> void:
	call_deferred("run")
func _process(_delta: float) -> void:
	if get_tree().paused: get_tree().paused=false
	if is_instance_valid(active_game): active_game.paused=false
	if "--capture-bombs" in OS.get_cmdline_user_args() and not captured_panic and is_instance_valid(active_game):
		if active_game.mice.any(func(m):return m.fleeing and not m.eaten and m.panic>=0.58):
			captured_panic=true
			capture_named("res://docs/mouse-panic.png")
	if "--capture-groups" in OS.get_cmdline_user_args() and is_instance_valid(active_game) and not active_game.section_transition:
		var key:="group_capture_"+str(active_game.section_index)
		if not active_game.has_meta(key) and active_game.mice.any(func(m):return int(m.config.section)==active_game.section_index and m.config.has("group_id")):
			active_game.set_meta(key,true)
			capture_group(int(active_game.data.number))
	if "--trace" in OS.get_cmdline_user_args() and is_instance_valid(active_game) and Time.get_ticks_msec()-trace_time>3000:
		trace_time=Time.get_ticks_msec()
		print("TRIAL LIVE ",active_game.data.number," part=",active_game.section_index," eaten=",active_game.mice_eaten," cat=",active_game.cat.position)
func capture_group(number: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/trial-group-%d.png"%number)
func capture_named(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	var numbers: Array=range(1,Trials.COUNT+1)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="):
			numbers=[]
			for value in arg.trim_prefix("--levels=").split(","): numbers.append(int(value))
	var normal: bool="--normal" in OS.get_cmdline_user_args()
	if not normal:
		Engine.physics_ticks_per_second=480
		Engine.time_scale=8
		Engine.max_physics_steps_per_frame=64
	var signatures: Dictionary={}
	for number in range(1,Trials.COUNT+1):
		var source:=Trials.read_source(number)
		var errors:=Trials.validate_source(source)
		if not errors.is_empty(): failures.append({"number":number,"schema":Array(errors)})
		var signature: String=Trials.geometry_signature(source)
		if signatures.has(signature): failures.append({"duplicate_layout":number})
		signatures[signature]=true
	if not failures.is_empty():
		print("TRIAL SCHEMA FAIL ",failures)
		get_tree().quit(1)
		return
	for number in numbers:
		var source:=Trials.read_source(number)
		var data:=Trials.load_trial(number,false)
		active_game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
		active_game.test_mode=true
		active_game.simulation_mode=not normal
		active_game.level_override=data
		add_child(active_game)
		for tick in 40: await get_tree().physics_frame
		var idle_safe: bool=not active_game.ended and active_game.mice_eaten==0 and absf(active_game.cat.position.x-360)<1
		var no_blast_button: bool=not data.physical_bombs or (active_game.bombs_left==0 and (active_game.hud==null or active_game.hud.get_node_or_null("bomb")==null))
		if "--capture-bombs" in OS.get_cmdline_user_args() and number==2: await capture_named("res://docs/physical-bomb-level2.png")
		var result: Dictionary=await Tester.execute(active_game,data.solution,900)
		var events_ok:=true
		var event_results: Array=[]
		for requirement in data.required_events:
			var obstacle=active_game.obstacles[requirement.id]
			var ok:=false
			match requirement.event:
				"activated": ok=obstacle.activated
				"defeated": ok=obstacle.defeated
				"used": ok=obstacle.uses>0
				"detonated": ok=obstacle.kind=="bomb" and obstacle.activated and obstacle.body.exploded
				"fell": ok=obstacle.body.position.y>30
				"rotated": ok=absf(obstacle.body.rotation)>0.01
			events_ok=events_ok and ok
			event_results.append({"id":requirement.id,"event":requirement.event,"passed":ok})
		var bomb_holes_ok:=true
		for wall in data.trial_walls:
			if not wall.get("breakable",true): continue
			var center:=Vector2(wall.rect[0]+wall.rect[2]/2.0,wall.rect[1]+wall.rect[3]/2.0)
			var cell:=Vector2i((center-active_game.terrain.position)/active_game.terrain.CELL)
			bomb_holes_ok=bomb_holes_ok and active_game.terrain.cells[cell.y*active_game.terrain.COLS+cell.x]==0
		var camera_ok: bool=is_equal_approx(active_game.camera.position.y,640.0+960*(data.sections-1)) and active_game.transition_count==data.sections-1
		var landed: bool=active_game.cat.supported and active_game.last_meal_age>=0.9 and active_game.landing_settle_time>=0.35
		var passed: bool=no_blast_button and landed and result.verified and active_game.hunt_complete and idle_safe and events_ok and bomb_holes_ok and camera_ok and active_game.section_index==data.sections-1
		var proof: Dictionary={"passed":passed,"source_hash":Trials.source_hash(source),"engine":Engine.get_version_info().string,"profile":"kitty50-mouse22-bounce22-tongue1500","sections":data.sections,"mice_eaten":active_game.mice_eaten,"mouse_count":active_game.mice.size(),"idle_safe":idle_safe,"events":event_results,"normal_timing":normal,"seconds":active_game.elapsed}
		proof.layout_signature=Trials.geometry_signature(source)
		proof.no_blast_button=no_blast_button
		proof.landed_before_complete=landed
		proof.bomb_walls_open=bomb_holes_ok
		proof.camera_transitions=active_game.transition_count
		proof.camera_verified=camera_ok
		results.append({"number":number,"proof":proof})
		if passed:
			source.verification=proof
			FileAccess.open(Trials.path_for(number),FileAccess.WRITE).store_string(JSON.stringify(source,"\t"))
		else:
			failures.append({"number":number,"section":active_game.section_index,"eaten":active_game.mice_eaten,"position":[active_game.cat.position.x,active_game.cat.position.y],"ended":active_game.ended,"reason":active_game.failure_reason,"events":event_results,"mice":active_game.mice.map(func(m):return [m.config.id,m.position.x,m.position.y,m.eaten])})
		print("TRIAL ",number," ","PASS" if passed else "FAIL"," parts=",data.sections," eaten=",active_game.mice_eaten,"/",active_game.mice.size()," events=",events_ok)
		if not passed: print("DETAIL ",failures[-1])
		active_game.queue_free()
		await get_tree().process_frame
		FileAccess.open("res://build/trial-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"results":results},"\t"))
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://levels/trial/manifest.json"))
	var all_verified:=true
	for entry in manifest.levels:
		var saved:=Trials.read_source(int(entry.number))
		entry.verified=saved.get("verification",{}).get("passed",false) and saved.get("verification",{}).get("source_hash","")==Trials.source_hash(saved)
		entry.file_sha256=FileAccess.get_file_as_string(Trials.path_for(int(entry.number))).sha256_text()
		entry.layout_signature=Trials.geometry_signature(saved)
		all_verified=all_verified and entry.verified
	manifest.all_verified=all_verified
	manifest.profile="kitty50-mouse22-bounce22-tongue1500"
	manifest.mechanics_files={}
	for path in MECHANICS_FILES: manifest.mechanics_files[path]=FileAccess.get_sha256("res://"+path)
	FileAccess.open("res://levels/trial/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("TRIAL CAMPAIGN RESULT: ",results.size()," checked, ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
