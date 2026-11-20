extends Node

const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Generator=preload("res://scripts/generation/LevelGenerator.gd")
const Loader=preload("res://scripts/gameplay/LevelLoader.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
var failures:=0
var results: Array=[]

func check(value: bool, text: String) -> void:
	print("PASS " if value else "FAIL ",text)
	if not value: failures+=1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	check(not Validator.validate({}).is_empty(),"reject missing JSON fields")
	check(not Validator.validate("invalid").is_empty(),"reject wrong root type")
	var invalid:=Generator.candidate(2)
	invalid.schema_version=99
	check(not Validator.validate(invalid).is_empty(),"reject unsupported schema")
	invalid=Generator.candidate(2)
	invalid.kittens.append(invalid.kittens[0].duplicate(true))
	check(not Validator.validate(invalid).is_empty(),"reject duplicate IDs")
	for n in range(1,201):
		var candidate:=Generator.candidate(n)
		check(Validator.validate(candidate).is_empty(),"candidate schema %d"%n)
		if n==30: check(JSON.stringify(candidate)==JSON.stringify(Generator.candidate(n)),"deterministic generation")
	var old_settings:=SaveManager.settings.duplicate(true)
	SaveManager.settings.music=false
	SaveManager.save_settings()
	check(SaveManager.read_valid("user://settings.json",SaveManager.DEFAULT_SETTINGS).music==false,"settings persist")
	SaveManager.settings=old_settings
	SaveManager.save_settings()
	var file:=FileAccess.open("user://broken.json",FileAccess.WRITE)
	file.store_string("{bad")
	file.close()
	check(SaveManager.read_valid("user://broken.json",{"test":true}).test,"corruption fallback")
	var original_progress:=SaveManager.progress.duplicate(true)
	SaveManager.daily_mode=false
	SaveManager.complete(1,3,20,1)
	check(SaveManager.progress.highest_unlocked>=2,"sequential unlock")
	check(SaveManager.read_valid("user://savegame.json",original_progress).completed.has("1"),"progress persists")
	SaveManager.progress=original_progress
	SaveManager.atomic_save("user://savegame.json",original_progress)
	for scene in ["MainMenu","Settings","LevelSelect"]:
		var menu=load("res://scenes/menus/"+scene+".tscn").instantiate()
		add_child(menu)
		await get_tree().process_frame
		check(menu.content.get_child_count()>0,"menu "+scene)
		remove_child(menu)
		menu.queue_free()
	for n in range(1,26):
		SaveManager.level_number=n
		SaveManager.daily_mode=false
		var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
		game.test_mode=true
		add_child(game)
		await get_tree().physics_frame
		var initial_cells: PackedByteArray=game.terrain.cells.duplicate()
		for tick in 90: await get_tree().physics_frame
		check(game.kittens[0].position.y<390,"sand supports kitten %d"%n)
		var solution: Array=game.data.solution
		var outcome: Dictionary=await Tester.execute(game,solution)
		check(game.terrain.removed>0,"terrain digging %d"%n)
		var success: bool=outcome.verified
		check(success,"complete physics rescue %d (%d/%d)"%[n,game.rescued,game.kittens.size()])
		if success:
			for tick in 45: await get_tree().physics_frame
			for kitten in game.kittens:
				check(kitten.visible and kitten.freeze and kitten.position.distance_to(kitten.family_target)<5,"rescued kitten stays with mother %d"%n)
				check(kitten.z_index<game.mother_visual.z_index,"kitten is behind mother %d"%n)
		for kitten in game.kittens: print(" kitten position ",kitten.position," velocity ",kitten.linear_velocity)
		results.append({"level":n,"verified":success,"rescued":game.rescued,"count":game.kittens.size(),"seconds":game.elapsed})
		remove_child(game)
		game.queue_free()
		await get_tree().process_frame
		var restart=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
		restart.test_mode=true
		add_child(restart)
		check(restart.terrain.cells==initial_cells,"restart exact terrain %d"%n)
		remove_child(restart)
		restart.queue_free()
		await get_tree().process_frame
	await mechanics_tests()
	await bee_chase_test()
	var report:=FileAccess.open("res://tests/verification.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"results":results,"failures":failures},"\t"))
	report.close()
	print("RESULT: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)

func bee_chase_test() -> void:
	var room:=Node2D.new()
	add_child(room)
	var sand=load("res://scripts/gameplay/SandTerrain.gd").new()
	room.add_child(sand)
	sand.setup({"grid_size":10,"brush_radius":45,"chambers":[[200,500,80],[450,500,80]]})
	var bee=load("res://scripts/obstacles/Obstacle.gd").new()
	room.add_child(bee)
	bee.setup({"id":"chaser","type":"bee","position":[200,500],"radius":18,"chase_speed":110})
	var kitten=load("res://scenes/gameplay/Kitten.tscn").instantiate()
	kitten.configure({"id":"target","position":[450,500],"radius":21})
	kitten.freeze=true
	room.add_child(kitten)
	bee.configure_chase([kitten],sand)
	for tick in 30: await get_tree().physics_frame
	check(bee.bee_chase.target==null and bee.position.x<280,"bee cannot chase through sealed sand")
	sand.dig_segment(Vector2(200,500),Vector2(450,500))
	var before: float=bee.position.distance_to(kitten.position)
	for tick in 60: await get_tree().physics_frame
	check(bee.bee_chase.target==kitten and bee.position.distance_to(kitten.position)<before-35,"bee pursues kitten after tunnel opens")
	sand.dig_segment(Vector2(450,500),Vector2(450,620))
	kitten.position=Vector2(450,620)
	for tick in 120: await get_tree().physics_frame
	check(bee.bee_chase.target==kitten and bee.position.y>510,"bee follows moving kitten around tunnel bend")
	kitten.rescue()
	for tick in 3: await get_tree().physics_frame
	check(bee.bee_chase.target==null,"bee ignores rescued kitten")
	bee.stop_for_result()
	var stopped: Vector2=bee.position
	for tick in 30: await get_tree().physics_frame
	check(bee.position.distance_to(stopped)<0.1,"bee stops at level end")
	remove_child(room)
	room.queue_free()
	await get_tree().process_frame

func mechanics_tests() -> void:
	for kind in ["bee","spikes","dangerous_plant","rotating_wheel","falling_rock","pressure_switch","portal","fan","water","moving_platform"]:
		var room:=Node2D.new()
		add_child(room)
		var obstacle=load("res://scripts/obstacles/Obstacle.gd").new()
		room.add_child(obstacle)
		obstacle.setup({"id":"test","type":kind,"position":[360,500],"radius":35})
		var kitten=load("res://scenes/gameplay/Kitten.tscn").instantiate()
		kitten.configure({"id":"cat","position":[360,500],"radius":21})
		room.add_child(kitten)
		var triggered: Array=[]
		obstacle.danger.connect(func(_body): triggered.append(true))
		if kind=="portal":
			var exit=load("res://scripts/obstacles/Obstacle.gd").new()
			room.add_child(exit)
			exit.setup({"id":"exit","type":"portal","position":[550,500]})
			obstacle.config.linked_to="exit"
			obstacle.links={"exit":exit}
		if kind=="pressure_switch":
			var gate=load("res://scripts/obstacles/Obstacle.gd").new()
			room.add_child(gate)
			gate.setup({"id":"gate","type":"gate","position":[550,500]})
			obstacle.config.target="gate"
			obstacle.links={"gate":gate}
		for tick in 12: await get_tree().physics_frame
		match kind:
			"bee","spikes","dangerous_plant": check(not triggered.is_empty(),kind+" contact hazard")
			"rotating_wheel": check(obstacle.body.get_child_count()==2 and absf(obstacle.body.rotation)>0, "wheel rotates with two physical paddles")
			"falling_rock": check(obstacle.body.position.y>0,"rock falls with gravity")
			"pressure_switch": check(obstacle.activated and obstacle.links.gate.activated,"switch opens linked gate")
			"portal": check(kitten.position.x>500,"portal teleport and cooldown")
			"fan": check(kitten.linear_velocity.y<0,"fan upward force")
			"water": check(kitten.linear_velocity.y<150,"water buoyancy and drag")
			"moving_platform": check(absf(obstacle.body.position.x)>0,"platform physical motion")
		remove_child(room)
		room.queue_free()
		await get_tree().process_frame
