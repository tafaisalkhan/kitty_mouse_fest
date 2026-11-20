extends Node
var game: Node
var captured_second:=false
var captured_portal:=false
func _ready() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func _process(_delta: float) -> void:
	if is_instance_valid(game) and game.section_index==1 and not game.section_transition and not captured_second:
		captured_second=true
		capture("res://docs/trial-camera-second-room.png")
func run() -> void:
	Economy.support_shown=true
	Economy.daily_prompt_shown=true
	var menu=load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.3).timeout
	await capture("res://docs/trial-home.png")
	menu.show_page("Trial")
	await get_tree().create_timer(0.3).timeout
	await capture("res://docs/trial-selector.png")
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.trial_mode=true
	SaveManager.trial_number=3
	SaveManager.level_number=3
	game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.test_mode=true
	game.level_override=preload("res://scripts/generation/TrialLevels.gd").load_trial(3)
	add_child(game)
	await get_tree().create_timer(0.4).timeout
	await capture("res://docs/trial-laser-start.png")
	var result: Dictionary=await preload("res://scripts/generation/SolutionTester.gd").execute(game,game.data.solution,900)
	if result.verified:
		game.result_panel(true,3)
		await get_tree().create_timer(0.4).timeout
		await capture("res://docs/trial-clear.png")
	print("TRIAL PREVIEW ",result," camera_capture=",captured_second)
	get_tree().quit(0 if result.verified and captured_second else 1)
