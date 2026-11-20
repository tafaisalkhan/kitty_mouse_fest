extends Node
func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(720,1280))
	call_deferred("run")
func capture(path: String) -> void:
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	var menu=load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await capture("res://docs/menu.png")
	remove_child(menu)
	menu.queue_free()
	SaveManager.level_number=4
	var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
	game.test_mode=true
	add_child(game)
	await capture("res://docs/level4.png")
	game.terrain.dig_segment(Vector2(245,310),Vector2(310,550))
	game.hint_visible=true
	await capture("res://docs/digging.png")
	remove_child(game)
	game.queue_free()
	SaveManager.level_number=6
	var showcase=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
	showcase.test_mode=true
	add_child(showcase)
	await capture("res://docs/showcase.png")
	showcase.terrain.dig_segment(Vector2(235,345),Vector2(289,490))
	await capture("res://docs/showcase-digging.png")
	get_tree().quit()
