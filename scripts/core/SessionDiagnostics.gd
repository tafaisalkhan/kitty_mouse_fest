extends Node

const PATH:="user://last_session.json"
var last_heartbeat:=0
var started_at:=""

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(PATH):
		var json:=JSON.new()
		if json.parse(FileAccess.get_file_as_string(PATH))==OK and json.data is Dictionary:
			if json.data.get("running",false):
				print("SESSION previous run interrupted: ",JSON.stringify(json.data))
	started_at=Time.get_datetime_string_from_system()
	print("SESSION started ",started_at," engine=",Engine.get_version_info().string)
	write_heartbeat(true)

func _process(_delta: float) -> void:
	if Time.get_ticks_msec()-last_heartbeat>=15000: write_heartbeat(true)

func write_heartbeat(running: bool) -> void:
	last_heartbeat=Time.get_ticks_msec()
	var state: Dictionary={"running":running,"started_at":started_at,"updated_at":Time.get_datetime_string_from_system(),"level":SaveManager.level_number,"uptime_seconds":Time.get_ticks_msec()/1000.0,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"static_memory_bytes":OS.get_static_memory_usage(),"effect_voices":AudioManager.effect_voices.size(),"physics_ticks":Engine.physics_ticks_per_second}
	var scene:=get_tree().current_scene
	state.scene=scene.scene_file_path if is_instance_valid(scene) else ""
	var file:=FileAccess.open(PATH,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state,"\t"))
		file.close()
	print("SESSION health ",JSON.stringify(state))

func _exit_tree() -> void:
	write_heartbeat(false)
