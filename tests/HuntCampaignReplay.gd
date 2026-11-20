extends Node
const Levels=preload("res://scripts/generation/HuntLevels.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
var game: Node
var failures:=0
var report: Array=[]
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused=false
		if is_instance_valid(game):
			game.paused=false
			for child in game.overlay.get_children(): child.queue_free()
func run() -> void:
	var samples: Array=[1,8,20,40,70,100,150,500,1000]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--levels="):
			samples=[]
			for selected in argument.trim_prefix("--levels=").split(","): samples.append(int(selected))
	for number in samples:
		SaveManager.level_number=number
		game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
		game.test_mode=true
		game.level_override=Levels.create(number)
		add_child(game)
		for tick in 35: await get_tree().physics_frame
		var idle_safe: bool=game.mice_eaten==0 and not game.ended
		var result: Dictionary=await Tester.execute(game,game.data.solution,900)
		var ok: bool=result.verified and game.hunt_complete and idle_safe
		print("REPLAY ",number," ","PASS" if ok else "FAIL"," eaten=",game.mice_eaten,"/",game.mice.size()," section=",game.section_index," pos=",game.cat.position)
		if not ok: print("REPLAY DIAG growth=",game.growth," mice=",game.mice.map(func(mouse): return [mouse.position,mouse.eaten,mouse.required_growth]))
		if not ok: failures+=1
		report.append({"number":number,"passed":ok,"mice_eaten":game.mice_eaten,"screens":game.sections,"seconds":game.elapsed})
		game.queue_free()
		await get_tree().process_frame
	var file:=FileAccess.open("res://tests/hunt-normal-replay.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"normal_growth_and_camera_timing":true,"samples":report},"\t"))
	print("NORMAL HUNT REPLAY RESULT: ",failures," failures")
	get_tree().quit(failures)
