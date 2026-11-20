extends Node2D
var failures:=0
var hits:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var cat=preload("res://scripts/gameplay/Kitten.gd").new()
	cat.configure({"id":"test_cat","position":[350,430],"radius":25,"mother":true})
	cat.freeze=true
	add_child(cat)
	var laser=preload("res://scripts/obstacles/Obstacle.gd").new()
	add_child(laser)
	laser.setup({"id":"test_laser","type":"laser","position":[100,430],"direction":[1,0],"length":550,"warning_seconds":1,"active_seconds":1,"cooldown_seconds":1})
	laser.configure_chase([cat],null)
	laser.set_physics_process(false)
	laser.danger.connect(func(_body): hits+=1)
	for tick in 3: await get_tree().physics_frame
	laser.elapsed=0.5
	laser.update_laser()
	check(laser.laser_state=="warning" and hits==0,"warning beam cannot kill Kitty")
	laser.elapsed=1.5
	laser.update_laser()
	check(laser.laser_state=="active" and hits==1,"active unobstructed laser detects Kitty")
	laser.elapsed=2.5
	laser.update_laser()
	check(laser.laser_state=="cooldown" and hits==1,"cooldown beam cannot kill Kitty")
	var cover:=StaticBody2D.new()
	cover.collision_layer=1
	var collider:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(24,140)
	collider.shape=shape
	cover.position=Vector2(220,430)
	cover.add_child(collider)
	add_child(cover)
	for tick in 3: await get_tree().physics_frame
	laser.elapsed=1.5
	laser.update_laser()
	check(laser.laser_end.x<130 and hits==1,"solid cover stops the beam before Kitty")
	cover.queue_free()
	for tick in 3: await get_tree().physics_frame
	var button=preload("res://scripts/obstacles/Obstacle.gd").new()
	add_child(button)
	button.setup({"id":"button","type":"pressure_switch","position":[350,430],"targets":["test_laser"]})
	button.links={"test_laser":laser}
	button.on_enter(cat)
	laser.update_laser()
	check(laser.activated and laser.laser_state=="disabled" and hits==1,"a linked switch disables laser damage")
	var terrain=preload("res://scripts/gameplay/SandTerrain.gd").new()
	terrain.render_visuals=false
	add_child(terrain)
	terrain.setup({"rock_rects":[[200,650,40,40]],"solid_rects":[[350,650,40,40]]})
	terrain.blast(Vector2(295,670),150)
	var breakable:=0
	var locked:=0
	for cell in terrain.cells:
		if cell==2: breakable+=1
		if cell==3: locked+=1
	check(breakable==0 and locked==16,"bomb destroys breakable wall and preserves locked wall")
	var original:=SaveManager.progress.duplicate(true)
	var original_mode: bool=SaveManager.trial_mode
	var original_number: int=SaveManager.trial_number
	SaveManager.trial_mode=true
	SaveManager.trial_number=1
	SaveManager.complete(1,3,20,1)
	check(SaveManager.progress.highest_unlocked==original.highest_unlocked and SaveManager.progress.coins==original.coins and SaveManager.progress.completed==original.completed,"trial completion cannot overwrite regular progress or coins")
	check(SaveManager.progress.trial.completed.has("1"),"trial stars are saved in a separate record")
	SaveManager.progress=original
	SaveManager.trial_mode=original_mode
	SaveManager.trial_number=original_number
	SaveManager.atomic_save("user://savegame.json",original)
	print("TRIAL MECHANICS RESULT: ",failures," failures")
	get_tree().quit(failures)
