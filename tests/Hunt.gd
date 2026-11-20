extends Node
const Levels=preload("res://scripts/generation/HuntLevels.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
var failures:=0
var active_game: Node
var last_trace:=0
func _process(_delta: float) -> void:
	if "--trace" not in OS.get_cmdline_user_args() or not is_instance_valid(active_game): return
	if Time.get_ticks_msec()-last_trace<3000: return
	last_trace=Time.get_ticks_msec()
	print("LIVE ",active_game.data.number," section ",active_game.section_index," growth ",active_game.growth," kitty ",active_game.cat.position," radius ",active_game.cat.radius," mice ",active_game.mice.filter(func(m): return int(m.config.section)==active_game.section_index).map(func(m): return [m.position,m.eaten,m.required_growth]))
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func make_game(number: int):
	var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.test_mode=true
	game.simulation_mode=true
	game.level_override=Levels.create(number)
	add_child(game)
	active_game=game
	return game
func run() -> void:
	var schemas:=true
	for number in range(1,1001):
		var data:=Levels.create(number)
		if not Validator.validate(data).is_empty() or not Validator.check_route(data).is_empty(): schemas=false
	check(schemas,"hunting layout schemas and gravity routes for levels 1–1000")
	var impossible:=Levels.create(1)
	impossible.mice[0].required_growth=99
	check(not Validator.validate(impossible).is_empty(),"impossible starting prey size is rejected")
	var samples: Array=[1,2,3,4,5,6,10,15,23,30,100,500,1000]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="): samples=[int(argument.trim_prefix("--level="))]
	for number in samples:
		var game=make_game(number)
		await get_tree().physics_frame
		check(game.kittens.size()==1 and game.cat.visual.mother,"one playable Mom Kitty, no baby kittens")
		for tick in 8: await get_tree().physics_frame
		check(game.mice[0].flee_count==0,"sealed sand prevents mice seeing Kitty")
		var outcome: Dictionary=await Tester.execute(game,game.data.solution)
		if not game.hunt_complete: print("DIAG hunt ",number," eaten ",game.mice_eaten," growth ",game.growth," section ",game.section_index," ended ",game.ended," cat ",game.cat.position," mice ",game.mice.map(func(m): return [m.position,m.eaten,m.flee_count]))
		check(game.hunt_complete and outcome.verified,"complete dig-and-eat hunt "+str(number))
		check(game.growth==game.mice_eaten and game.cat.radius>50,"eating increases power, artwork and physical radius")
		var shape=game.cat.get_children().filter(func(child): return child is CollisionShape2D)[0]
		check(is_equal_approx(shape.shape.radius,game.cat.radius) and game.cat.visual.art_scale.x>game.starting_art_scale.x,"growth updates both collider and rendered artwork")
		check(game.mice.any(func(m): return m.flee_count>0),"mice see Kitty and attempt to escape")
		game.queue_free()
		await get_tree().process_frame
	var game=make_game(1)
	await get_tree().physics_frame
	check(game.growth==0 and game.cat.radius==50,"new hunt resets Kitty to starting size")
	game.mice[-1].required_growth=99
	game.mice[-1].config.kind="BIG"
	game.encounter_mouse(game.mice[-1])
	await get_tree().process_frame
	check(game.ended and not game.hunt_complete and game.mice_eaten==0,"oversized mouse fails level without growth or reward")
	check(game.cat.visual.defeated,"oversized prey shows defeated expression")
	check(game.mice.all(func(mouse): return mouse.celebrating and mouse.state=="celebrating"),"surviving mice celebrate after Kitty fails")
	game.queue_free()
	await get_tree().process_frame
	print("HUNT RESULT: ",failures," failures")
	get_tree().quit(failures)
