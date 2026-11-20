extends RefCounted

const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Generator=preload("res://scripts/generation/LevelGenerator.gd")

static func load_level(number: int, daily:=false) -> Dictionary:
	var data: Variant
	if not daily:
		var path:="res://levels/easy/level_%03d.json"%number
		if not FileAccess.file_exists(path): path="res://levels/medium/level_%03d.json"%number
		if FileAccess.file_exists(path): data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if data==null:
		var path:=cache_path(number,daily)
		if FileAccess.file_exists(path):
			var json:=JSON.new()
			if json.parse(FileAccess.get_file_as_string(path))==OK and cache_is_verified(json.data): data=json.data
	if data==null: return {"needs_generation":true,"number":number,"daily":daily}
	var errors:=Validator.validate(data)
	if not errors.is_empty():
		push_error("Invalid level: "+str(errors))
		return {"error":"\n".join(errors)}
	return data

static func cache_path(number: int,daily:=false) -> String:
	var key: String="daily_"+Time.get_date_string_from_system() if daily else "level_%d"%number
	return "user://generated_levels/v%d/%s.json"%[Generator.VERSION,key]

static func cache_is_verified(value: Variant) -> bool:
	if not value is Dictionary or not Validator.validate(value).is_empty(): return false
	if value.has("recipe_hash") and value.recipe_hash!=Generator.recipe_hash(int(value.number)): return false
	if not value.get("verified",false) or not value.get("verification",{}) is Dictionary: return false
	var proof: Dictionary=value.get("verification",{})
	return proof.get("generation_version",0)==Generator.VERSION and proof.get("engine","")==Engine.get_version_info().string and proof.get("blueprint_hash","")==Generator.blueprint_hash(value)

