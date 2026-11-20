extends Node
const Generator=preload("res://scripts/generation/LevelGenerator.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Loader=preload("res://scripts/gameplay/LevelLoader.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var schema_failures:=0
	var recipes: Dictionary={}
	for number in range(1,1001):
		var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Generator.recipe_path(number)))
		if int(recipe.get("number",0))!=number: schema_failures+=1
		if number<30:
			if not FileAccess.file_exists(recipe.source): schema_failures+=1
			continue
		var data:=Generator.candidate(number)
		if not Validator.validate(data).is_empty() or not Validator.check_route(data).is_empty():
			print("SCHEMA ",number," ",Validator.validate(data)," ",Validator.check_route(data))
			schema_failures+=1
		if data.sections!=int(recipe.screen_count) or data.kittens.size()!=int(recipe.kitten_count): schema_failures+=1
		if data.section_names.size()!=int(recipe.screen_count) or data.obstacles.is_empty(): schema_failures+=1
		recipes[JSON.stringify([recipe.screens,recipe.brush_radius,recipe.mirror,recipe.wheel_speed,recipe.layout_offset_x])]=true
	check(schema_failures==0,"all 1,000 recipes resolve and generated layouts pass schema/route checks")
	check(recipes.size()>900,"campaign recipes vary routes, mechanics, direction and difficulty settings")
	var retry:=Generator.candidate(500,-1,7)
	check(retry.sections==Generator.candidate(500).sections and retry.obstacles.size()==Generator.candidate(500).obstacles.size(),"retry preserves screen count and obstacles")
	var samples: Array=[30,49,60,99,100,199,200,249,250,399,400,499,500,750,999,1000]
	if "--campaign-all" in OS.get_cmdline_user_args(): samples=range(30,1001)
	var report: Array=[]
	for number in samples:
		var data: Dictionary=await LevelService.ensure_level(number)
		var ok:=not data.has("error") and Loader.cache_is_verified(data)
		check(ok,"complete physics rescue for campaign "+str(number))
		if ok:
			check(data.sections==Generator.candidate(number).sections,"planned screen count retained "+str(number))
			report.append({"number":number,"screens":data.sections,"kittens":data.kittens.size(),"obstacles":data.obstacles.size(),"attempts":LevelService.last_attempts,"seconds":data.verification.seconds})
	var file:=FileAccess.open("res://tests/campaign-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"schema_checked":1000,"unique_settings":recipes.size(),"physics_samples":report},"\t"))
	print("CAMPAIGN RESULT: ",failures," failures")
	get_tree().quit(failures)
