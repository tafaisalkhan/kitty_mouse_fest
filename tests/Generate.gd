extends Node
const Generator=preload("res://scripts/generation/LevelGenerator.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var report: Array=[]
	var signatures: Dictionary={}
	for number in range(6,26):
		var data:=Generator.candidate(number)
		var signature:=JSON.stringify(data.solution).sha256_text()
		var errors:=Validator.validate(data)
		errors.append_array(Validator.check_route(data))
		if signatures.has(signature): errors.append("Duplicate topology coordinates")
		signatures[signature]=true
		if not errors.is_empty():
			report.append({"level":number,"verified":false,"errors":Array(errors)})
			continue
		var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
		game.test_mode=true
		game.level_override=data
		add_child(game)
		for tick in 60: await get_tree().physics_frame
		var result: Dictionary=await Tester.execute(game,data.solution)
		result.level=number
		result.seed=data.seed
		result.signature=signature
		report.append(result)
		print("GENERATED ",number," verified=",result.verified)
		if result.verified:
			data.verified=true
			data.verification={"engine":Engine.get_version_info().string,"route_signature":signature,"seconds":result.seconds}
			var file:=FileAccess.open("res://levels/medium/level_%03d.json"%number,FileAccess.WRITE)
			file.store_string(JSON.stringify(data,"\t"))
			file.close()
		remove_child(game)
		game.queue_free()
		await get_tree().process_frame
	var output:=FileAccess.open("res://tests/generated-verification.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	get_tree().quit()
