extends Node

const DEFAULT_SETTINGS = {"music":true,"effects":true,"music_volume":0.35,"effects_volume":0.7,"vibration":true,"left_handed":false,"reduce_motion":false,"language":"en","challenge_notifications":false}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var progress: Dictionary = {"version":1,"highest_unlocked":1,"completed":{},"total_rescued":0,"daily":{},"coins":0,"daily_streak":{},"boosters":{"bombs":0,"hints":0},"chest_date":"","trial":{"highest_unlocked":1,"completed":{}}}
var level_number: int = 1
var daily_mode := false
var trial_mode:=false
var trial_number:=1

func _ready() -> void:
	settings = read_valid("user://settings.json", DEFAULT_SETTINGS)
	progress = read_valid("user://savegame.json", progress)
	level_number = int(progress.highest_unlocked)

func read_valid(path: String, defaults: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	if not FileAccess.file_exists(path):
		return result
	var json:=JSON.new()
	var parse_error:=json.parse(FileAccess.get_file_as_string(path))
	var value = json.data if parse_error==OK else null
	if not value is Dictionary:
		push_warning("Corrupt save ignored: " + path)
		return result
	for key in defaults:
		if value.has(key) and typeof(value[key]) == typeof(defaults[key]):
			result[key] = value[key]
		elif value.has(key) and defaults[key] is int and value[key] is float:
			result[key] = int(value[key])
	if result.has("highest_unlocked"): result.highest_unlocked=maxi(1,int(result.highest_unlocked))
	return result

func atomic_save(path: String, value: Dictionary) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	file.close()
	# Keep a last-good backup before replacing the primary file.
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(temp, path) == OK

func save_settings() -> void:
	atomic_save("user://settings.json", settings)
	AudioManager.apply_settings()

func complete(number: int, stars: int, seconds: float, count: int) -> int:
	var reward:=0
	if trial_mode:
		var trial: Dictionary=progress.get("trial",{"highest_unlocked":1,"completed":{}})
		var completed: Dictionary=trial.get("completed",{})
		var old: Dictionary=completed.get(str(trial_number),{})
		completed[str(trial_number)]={"stars":maxi(stars,int(old.get("stars",0))),"time":minf(seconds,float(old.get("time",1e9)))}
		trial.completed=completed
		trial.highest_unlocked=mini(5,maxi(int(trial.get("highest_unlocked",1)),trial_number+1))
		progress.trial=trial
		atomic_save("user://savegame.json",progress)
		return 0
	if daily_mode:
		if not progress.daily.has(Time.get_date_string_from_system()): reward=100+stars*25
		progress.daily[Time.get_date_string_from_system()] = {"stars":stars,"time":seconds}
	else:
		var key := str(number)
		var old: Dictionary = progress.completed.get(key, {})
		reward=(50 if old.is_empty() else 0)+maxi(0,stars-int(old.get("stars",0)))*25
		progress.completed[key] = {"stars":maxi(stars, int(old.get("stars", 0))),"time":minf(seconds, float(old.get("time", 1e9)))}
		progress.highest_unlocked = maxi(int(progress.highest_unlocked), number + 1)
	progress.total_rescued += count
	progress.coins=int(progress.get("coins",0))+reward
	atomic_save("user://savegame.json", progress)
	return reward

func stars_total() -> int:
	var total := 0
	for item in progress.completed.values():
		if item is Dictionary:
			total += int(item.get("stars",0))
	return total

func reset_progress() -> void:
	progress = {"version":1,"highest_unlocked":1,"completed":{},"total_rescued":0,"daily":{},"coins":0,"daily_streak":{},"boosters":{"bombs":0,"hints":0},"chest_date":""}
	level_number = 1
	progress.trial={"highest_unlocked":1,"completed":{}}
	atomic_save("user://savegame.json", progress)

