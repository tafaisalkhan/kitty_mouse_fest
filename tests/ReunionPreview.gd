extends Node
const Tester=preload("res://scripts/generation/SolutionTester.gd")
func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(720,1280))
	call_deferred("run")
func capture(path: String) -> void:
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	SaveManager.level_number=6
	SaveManager.daily_mode=false
	var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
	game.test_mode=true
	add_child(game)
	for frame in 90: await get_tree().physics_frame
	var outcome: Dictionary=await Tester.execute(game,game.data.solution)
	if not outcome.verified:
		push_error("Reunion preview needs a complete successful rescue")
		get_tree().quit(1)
		return
	for frame in 45: await get_tree().physics_frame
	if showcase_sparkles(game): print("PASS reunited family has sparkling eyes")
	else:
		push_error("Reunited family is missing sparkling eyes")
		get_tree().quit(1)
		return
	await capture("res://docs/reunion.png")
	game.result_panel(true,3)
	await capture("res://docs/victory.png")
	get_tree().quit()

func showcase_sparkles(game: Node) -> bool:
	if game.mother_visual.sparkle_time<=0: return false
	for kitten in game.kittens:
		if kitten.visual.sparkle_time<=0: return false
	return true
