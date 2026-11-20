extends Node
func _ready() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	SaveManager.trial_mode=true
	SaveManager.trial_number=1
	var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.test_mode=true
	game.level_override=preload("res://scripts/generation/TrialLevels.gd").load_trial(1)
	add_child(game)
	await capture("res://docs/sand-depth-start.png")
	await preload("res://scripts/generation/SolutionTester.gd").dig_points(game,[[360,350],[250,520],[400,650],[320,805],[455,940],[360,1140]])
	await capture("res://docs/sand-depth-carved.png")
	print("SAND DEPTH PREVIEW: open sky holes, lit rim and extruded cut face rendered")
	get_tree().quit()
