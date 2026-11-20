extends Node
const Generator=preload("res://scripts/generation/LevelGenerator.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var previous_boosters: Dictionary=SaveManager.progress.boosters.duplicate(true)
	SaveManager.progress.boosters={"bombs":0,"hints":0}
	for number in [26,27,28,29]:
		var data:=Generator.advanced_candidate(number)
		check(Validator.validate(data).is_empty(),"advanced schema "+str(number))
		var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
		game.test_mode=true
		game.simulation_mode=true
		game.level_override=data
		add_child(game)
		await get_tree().physics_frame
		game.kittens[0].position=Vector2(333,1120)
		game.kittens[0].freeze=true
		for tick in 3: await get_tree().physics_frame
		check(game.section_index==0,"camera waits for every kitten at ledge")
		game.kittens[0].position=Vector2(333,300)
		game.kittens[0].freeze=false
		game.terrain.dig_segment(Vector2(360,480 if number>=28 else 650),Vector2(360,600 if number>=28 else 740))
		await get_tree().physics_frame
		var cell:=Vector2i((Vector2(360,550 if number>=28 else 700)-game.terrain.position)/game.terrain.CELL)
		check(game.terrain.cells[cell.y*game.terrain.COLS+cell.x]==2,"ordinary digging preserves stone")
		check(game.has_visible_stone(),"bomb tool has a visible stone target")
		check(not game.use_bomb(Vector2(360,1660)),"bomb cannot target a hidden lower screen")
		if number==26:
			game.use_bomb(Vector2(135,790))
			check(game.obstacles.bee_left.defeated,"bomb blast defeats nearby bee")
		var outcome: Dictionary=await Tester.execute(game,data.solution)
		if not outcome.verified: print("DIAG ",number," section ",game.section_index," ended ",game.ended," cats ",game.kittens.map(func(k): return [k.position,k.linear_velocity,k.supported]))
		check(outcome.verified,"complete multi-screen rescue "+str(number)+" "+str(outcome))
		check(game.section_index==game.sections-1,"camera advances through every section")
		check(game.bombs_left==int(data.bombs)-data.solution_bombs.size()-(1 if number==26 else 0),"bomb inventory accounts for wall and bee blasts")
		check(game.transition_count==game.sections-1,"one complete base transition per section")
		if number>=28:
			check(game.obstacles.gate_0.activated,"kittens open the route's first gate with its switch")
			check(game.obstacles.trap_bee.defeated,"released stone defeats the bee in its trap")
			if number==29: check(game.obstacles.gate_4.activated,"final garden switch opens its gate")
		check(not game.use_bomb(Vector2(360,700)),"ended level cannot spend extra bombs")
		if outcome.verified:
			var file:=FileAccess.open("res://levels/medium/level_%03d.json"%number,FileAccess.WRITE)
			file.store_string(JSON.stringify(data,"\t"))
		game.queue_free()
		await get_tree().process_frame
	# A falling stone enters a bee's actual physics area.
	var room:=Node2D.new()
	add_child(room)
	var bee=load("res://scripts/obstacles/Obstacle.gd").new()
	room.add_child(bee)
	bee.setup({"id":"bee","type":"bee","position":[360,650],"radius":24,"chase":false,"patrol_width":0,"patrol_speed":0})
	var rock=load("res://scripts/obstacles/Obstacle.gd").new()
	room.add_child(rock)
	rock.setup({"id":"rock","type":"falling_rock","position":[360,450],"radius":36})
	for tick in 80: await get_tree().physics_frame
	check(bee.defeated and not bee.enabled,"falling stone kills bee on contact")
	room.queue_free()
	await get_tree().process_frame
	var plant=load("res://scripts/obstacles/Obstacle.gd").new()
	add_child(plant)
	plant.setup({"id":"plant","type":"dangerous_plant","position":[360,650],"radius":33})
	plant.elapsed=2.5
	plant.enabled=false
	var kitten=load("res://scripts/gameplay/Kitten.gd").new()
	kitten.configure({"position":[360,650],"radius":27})
	kitten.freeze=true
	add_child(kitten)
	var hits: Array=[]
	plant.danger.connect(func(target): hits.append(target))
	for tick in 10: await get_tree().physics_frame
	check(hits.is_empty(),"closed plant permits an overlapping kitten")
	for tick in 100: await get_tree().physics_frame
	check(hits.has(kitten),"plant opening detects kitten already inside")
	plant.queue_free()
	kitten.queue_free()
	SaveManager.progress.boosters=previous_boosters
	print("ADVANCED RESULT: ",failures," failures")
	get_tree().quit(failures)
