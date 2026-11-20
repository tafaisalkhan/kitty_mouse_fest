extends Node
const Campaign=preload("res://scripts/generation/HuntCampaign.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
const Hash=preload("res://scripts/generation/LevelGenerator.gd")
var failures: Array=[]
var results: Array=[]
var sample_only:=false
var report_start:=1
var report_end:=1000
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	sample_only="--samples" in OS.get_cmdline_user_args()
	var numbers: Array=[1,5,8,20,40,70,100,150,200,250,400,500,750,999,1000] if sample_only else range(1,1001)
	var start:=1
	var finish:=1000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start="): start=int(arg.trim_prefix("--start="))
		if arg.begins_with("--end="): finish=int(arg.trim_prefix("--end="))
	if not sample_only: numbers=range(start,finish+1)
	report_start=start
	report_end=finish
	Engine.physics_ticks_per_second=480
	Engine.time_scale=8
	Engine.max_physics_steps_per_frame=64
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/hunt-bake"))
	var began:=Time.get_ticks_msec()
	for number in numbers:
		var success:=false
		var notes: Array=[]
		var output:="res://build/hunt-bake/level_%04d.json"%number
		if not sample_only and FileAccess.file_exists(output):
			var cached=JSON.parse_string(FileAccess.get_file_as_string(output))
			if cached is Dictionary and cached.get("hunt_generation_version",0)==Campaign.VERSION and cached.get("verification",{}).get("mechanics_verified",false) and cached.get("verified",false) and cached.get("recipe_hash","")==FileAccess.get_file_as_string(Campaign.recipe_path(number)).sha256_text() and cached.get("verification",{}).get("blueprint_hash","")==Hash.blueprint_hash(cached):
				results.append(cached.verification)
				continue
		for attempt in 5:
			var data:=Campaign.candidate(number,attempt)
			var errors:=Validator.validate(data)
			errors.append_array(Validator.check_route(data))
			if not errors.is_empty():
				notes.append({"attempt":attempt,"schema":Array(errors)})
				continue
			var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
			game.test_mode=true
			game.simulation_mode=true
			game.level_override=data
			add_child(game)
			for tick in 35: await get_tree().physics_frame
			var idle_safe: bool=game.mice_eaten==0 and not game.ended and game.section_index==0
			var outcome: Dictionary=await Tester.execute(game,data.solution,600)
			var mechanics_ok: bool=game.obstacles.values().all(func(item): return (item.kind!="gate" or item.activated) and (item.kind!="bee" or item.defeated))
			success=game.hunt_complete and outcome.verified and mechanics_ok and idle_safe
			if success:
				data.verified=true
				data.verification={"number":number,"hunt_generation_version":Campaign.VERSION,"engine":Engine.get_version_info().string,"seconds":game.elapsed,"mice_eaten":game.mice_eaten,"mouse_count":game.mice.size(),"screens":game.sections,"obstacles":game.obstacles.size(),"mechanics_verified":mechanics_ok,"idle_start_verified":idle_safe,"attempt":attempt,"blueprint_hash":Hash.blueprint_hash(data)}
				var file:=FileAccess.open(output,FileAccess.WRITE)
				file.store_string(JSON.stringify(data,"\t"))
				file.close()
				results.append(data.verification)
			else:
				notes.append({"attempt":attempt,"eaten":game.mice_eaten,"total":game.mice.size(),"section":game.section_index,"ended":game.ended,"cat":[game.cat.position.x,game.cat.position.y],"reason":game.failure_reason,"mice":game.mice.map(func(m): return [m.config.id,m.position.x,m.position.y,m.eaten])})
			game.queue_free()
			await get_tree().process_frame
			if success: break
		if not success: failures.append({"number":number,"attempts":notes})
		if sample_only or number%10==0 or not success:
			print("BAKE ",number," ","PASS" if success else "FAIL"," checked=",results.size()," failures=",failures.size()," wall_s=",(Time.get_ticks_msec()-began)/1000.0)
			write_report()
	write_report()
	print("HUNT BAKE RESULT: ",results.size()," passed, ",failures.size()," failed")
	get_tree().quit(0 if failures.is_empty() else 1)

func write_report() -> void:
	var path:="res://build/hunt-bake/samples-report.json" if sample_only else "res://build/hunt-bake/report-%04d-%04d.json"%[report_start,report_end]
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"sample_only":sample_only,"passed":results.size(),"failed":failures.size(),"failures":failures,"results":results},"\t"))
