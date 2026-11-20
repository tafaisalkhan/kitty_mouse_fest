extends Node
const Levels=preload("res://scripts/generation/HuntLevels.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://levels/hunt/manifest.json"))
	check(manifest.count==1000 and manifest.all_physics_verified,"manifest contains 1,000 physics-certified hunts")
	var signatures: Dictionary={}
	var modules: Dictionary={}
	var invalid: Array=[]
	for number in range(1,1001):
		var path:="res://levels/hunt/level_%04d.json"%number
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not Levels.valid_baked_layout(data,number) or not Validator.check_route(data).is_empty() or not data.verification.get("idle_start_verified",false): invalid.append(number)
		if data.kittens.size()!=1 or data.kittens[0].radius!=25 or not data.kittens[0].mother: invalid.append(number)
		for mouse in data.mice:
			if mouse.escape_route.size()<2: invalid.append(number)
			for point in mouse.escape_route:
				if point[1]<mouse.position[1] or point[0]<30 or point[0]>690: invalid.append(number)
		for module in data.modules: modules[module]=true
		signatures[JSON.stringify([data.terrain,data.mice,data.obstacles]).sha256_text()]=true
	check(invalid.is_empty(),"every published layout has valid growth, escape paths, starting state and proof "+str(invalid))
	check(signatures.size()==1000,"all 1,000 concrete layouts are distinct")
	check(modules.size()==7,"all seven hunting puzzle families are present")
	check(Levels.create(1).get("verified",false) and Levels.create(1000).get("verified",false),"active game reads packaged levels directly")
	var corrupt:=Levels.create(1).duplicate(true)
	corrupt.mice[0].position[0]+=10
	check(not Levels.valid_baked_layout(corrupt,1),"changed geometry invalidates its physics proof")
	check(Levels.create(1001).number==1001,"endless fallback continues beyond the offline campaign")
	print("HUNT CAMPAIGN CHECKS: ",failures," failures")
	get_tree().quit(failures)
