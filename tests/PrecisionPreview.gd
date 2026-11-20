extends Node
func capture(path: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.test_mode=true
	game.level_override=preload("res://scripts/generation/HuntLevels.gd").create(1)
	add_child(game)
	await capture("res://docs/big-kitty-start.png")
	await preload("res://scripts/generation/SolutionTester.gd").dig_stroke(game,[[360,350],[405,474]])
	await capture("res://docs/precise-dig-stroke.png")
	print("PRECISION PREVIEW captured large Kitty and one narrow drag")
	get_tree().quit()
