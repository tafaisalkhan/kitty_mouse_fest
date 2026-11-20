extends Node
const Levels=preload("res://scripts/generation/EndlessBurrows.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var original:=SaveManager.progress.duplicate(true)
	SaveManager.level_number=17
	SaveManager.trial_mode=false
	SaveManager.daily_mode=false
	var ticks:=Engine.physics_ticks_per_second
	var scale:=Engine.time_scale
	var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	add_child(game)
	for frame in 180:
		await get_tree().process_frame
		if Levels.memory.has("18"): break
	check(game.data.endless and game.data.number==17,"ordinary campaign play selects the new endless burrows")
	check(Levels.memory.has("18"),"the next level is prepared in a worker while the current one plays")
	check(Engine.physics_ticks_per_second==ticks and Engine.time_scale==scale,"prefetch never speeds up or pauses gameplay physics")
	check(SaveManager.progress==original,"generation preserves progress and coins")
	check(JSON.stringify(Levels.create(18))==JSON.stringify(Levels.build(18,18*104729)),"prefetched and regenerated JSON produce the same level")
	game.queue_free()
	await get_tree().process_frame
	SaveManager.complete(10001,2,30,1)
	check(int(SaveManager.progress.highest_unlocked)>=10002,"campaign progression continues beyond level 1000")
	SaveManager.progress=original
	SaveManager.atomic_save("user://savegame.json",original)
	print("ENDLESS INTEGRATION RESULT: ",failures," failures")
	get_tree().quit(failures)
