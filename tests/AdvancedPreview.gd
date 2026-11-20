extends Node
const Tester=preload("res://scripts/generation/SolutionTester.gd")
var game: Node
var captured_second:=false
var captured_phases: Dictionary={}
var capture_prefix:="advanced"
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused=false
		if is_instance_valid(game):
			game.paused=false
			for child in game.overlay.get_children(): child.queue_free()
	if is_instance_valid(game) and game.cue_phase in ["ready","opening","moving"] and not captured_phases.has(game.cue_phase):
		captured_phases[game.cue_phase]=true
		capture("res://docs/"+capture_prefix+"-"+game.cue_phase+".png")
	if is_instance_valid(game) and game.section_index==1 and not game.section_transition and not captured_second:
		captured_second=true
		capture("res://docs/"+capture_prefix+"-second-screen.png")
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	SaveManager.level_number=29
	if "--campaign-preview" in OS.get_cmdline_user_args():
		SaveManager.level_number=500
		capture_prefix="campaign"
	SaveManager.daily_mode=false
	game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
	game.test_mode=true
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	await capture("res://docs/"+capture_prefix+"-first-screen.png")
	var outcome: Dictionary=await Tester.execute(game,game.data.solution)
	print("LIVE ADVANCED ",outcome)
	await capture("res://docs/"+capture_prefix+"-rescue.png")
	get_tree().quit(0 if outcome.verified else 1)
