extends Node
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	for number in range(1,6):
		SaveManager.trial_mode=true
		SaveManager.trial_number=number
		var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
		game.test_mode=true
		game.level_override=preload("res://scripts/generation/TrialLevels.gd").load_trial(number)
		add_child(game)
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/trial-%02d-start.png"%number)
		print("GALLERY ",number," mice=",game.mice.size()," bombs=",game.bombs_left)
		game.queue_free()
		await get_tree().process_frame
	print("TRIAL GALLERY COMPLETE")
	get_tree().quit()
