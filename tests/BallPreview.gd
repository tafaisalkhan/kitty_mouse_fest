extends Node

func capture(path: String) -> void:
	await get_tree().create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Economy.support_shown=true
	Economy.daily_prompt_shown=true
	var menu=load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await capture("res://docs/ball-main-menu.png")
	menu.queue_free()
	await get_tree().process_frame
	var boot=load("res://scenes/menus/Boot.tscn").instantiate()
	add_child(boot)
	await capture("res://docs/ball-splash.png")
	boot.queue_free()
	await get_tree().process_frame
	var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.test_mode=true
	game.level_override=preload("res://scripts/generation/HuntLevels.gd").create(1)
	add_child(game)
	await capture("res://docs/ball-gameplay.png")
	print("BALL PREVIEW captured menu, splash and gameplay")
	get_tree().quit()
