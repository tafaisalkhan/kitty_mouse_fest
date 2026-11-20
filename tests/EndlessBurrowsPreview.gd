extends Node
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	Economy.support_shown=true
	Economy.daily_prompt_shown=true
	SaveManager.trial_mode=false
	for number in [1,2,3,4,5,1001]:
		SaveManager.level_number=number
		var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
		game.test_mode=true
		game.level_override=preload("res://scripts/generation/EndlessBurrows.gd").create(number)
		add_child(game)
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/endless-level-%d.png"%number)
		print("BURROW PREVIEW ",number," families=",game.data.module_families)
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()
