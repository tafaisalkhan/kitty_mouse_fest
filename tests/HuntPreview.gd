extends Node
const Tester=preload("res://scripts/generation/SolutionTester.gd")
var game: Node
var captured_growth:=false
var captured_panic:=false
var prefix:="hunt"
var last_debug:=0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func _process(_delta: float) -> void:
	if is_instance_valid(game) and Time.get_ticks_msec()-last_debug>5000:
		last_debug=Time.get_ticks_msec()
		print("PREVIEW STATE section=",game.section_index," eaten=",game.mice_eaten," ended=",game.ended," paused=",game.paused," pos=",game.cat.position," elapsed=",game.elapsed)
		capture("res://docs/"+prefix+"-current.png")
	if get_tree().paused:
		get_tree().paused=false
		if is_instance_valid(game):
			game.paused=false
			for child in game.overlay.get_children(): child.queue_free()
	if is_instance_valid(game) and game.growth==1 and not captured_growth:
		captured_growth=true
		capture("res://docs/"+prefix+"-growth.png")
	if is_instance_valid(game) and not captured_panic and game.mice.any(func(mouse): return mouse.panic>0.35):
		captured_panic=true
		capture("res://docs/"+prefix+"-panic.png")
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	if "--phase2-preview" in OS.get_cmdline_user_args(): prefix="hunt-phase2"
	Economy.support_shown=true
	Economy.daily_prompt_shown=true
	var menu=load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.4).timeout
	await capture("res://docs/"+prefix+"-menu.png")
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.level_number=500 if prefix=="hunt-phase2" else 1
	game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.test_mode=true
	add_child(game)
	await get_tree().create_timer(0.4).timeout
	await capture("res://docs/"+prefix+"-start.png")
	var outcome: Dictionary=await Tester.execute(game,game.data.solution)
	print("LIVE HUNT ",outcome)
	await get_tree().create_timer(0.7).timeout
	game.result_panel(true,3)
	await get_tree().create_timer(0.7).timeout
	await capture("res://docs/"+prefix+"-win.png")
	game.queue_free()
	await get_tree().process_frame
	game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.test_mode=true
	add_child(game)
	await get_tree().process_frame
	game.encounter_mouse(game.mice[-1])
	await get_tree().create_timer(0.8).timeout
	await capture("res://docs/"+prefix+"-mice-celebrate.png")
	await get_tree().create_timer(2.6).timeout
	await capture("res://docs/"+prefix+"-fail.png")
	get_tree().quit(0 if outcome.verified else 1)
