extends Node

signal generation_finished
const Generator=preload("res://scripts/generation/LevelGenerator.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const Loader=preload("res://scripts/gameplay/LevelLoader.gd")
const Tester=preload("res://scripts/generation/SolutionTester.gd")
var generating:=false
var saved_ticks:=60
var saved_scale:=1.0
var saved_steps:=8
var last_attempts:=0
var recent_signatures: Array[String]=[]

func ensure_level(number: int,daily:=false) -> Dictionary:
	while generating: await generation_finished
	var existing:=Loader.load_level(number,daily)
	if not existing.get("needs_generation",false): return existing
	generating=true
	last_attempts=0
	saved_ticks=Engine.physics_ticks_per_second
	saved_scale=Engine.time_scale
	saved_steps=Engine.max_physics_steps_per_frame
	# More fixed ticks per real second, with the same 1/60 simulated step.
	# The isolated validation world never shares colliders with the player.
	var multiplier:=4 if OS.get_name()=="Android" else 12
	Engine.physics_ticks_per_second=60*multiplier
	Engine.time_scale=float(multiplier)
	Engine.max_physics_steps_per_frame=maxi(saved_steps,multiplier*8)
	var result: Dictionary={"error":"Could not prepare this rescue. Please retry."}
	var fixed_seed: int=Time.get_date_string_from_system().hash() if daily else -1
	for attempt in 8:
		last_attempts=attempt+1
		var candidate:=Generator.candidate(number,fixed_seed,attempt)
		if daily: candidate.name="Daily Rescue"
		var errors:=Validator.validate(candidate)
		errors.append_array(Validator.check_route(candidate))
		if not errors.is_empty(): continue
		var signature:=JSON.stringify([candidate.terrain,candidate.solution,candidate.obstacles]).sha256_text()
		if recent_signatures.has(signature): continue
		var viewport:=SubViewport.new()
		# Physics uses world coordinates, not render-target dimensions. No need
		# to allocate a full-screen GPU surface for an invisible simulation.
		viewport.size=Vector2i(1,1)
		viewport.disable_3d=true
		viewport.world_2d=World2D.new()
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var game=load("res://scenes/gameplay/RescueGameplay.tscn").instantiate()
		game.test_mode=true
		game.simulation_mode=true
		game.level_override=candidate
		viewport.add_child(game)
		for tick in 90: await get_tree().physics_frame
		var outcome: Dictionary=await Tester.execute(game,candidate.solution,1200)
		viewport.queue_free()
		await get_tree().process_frame
		if not outcome.verified: continue
		candidate.verified=true
		candidate.verification={"generation_version":Generator.VERSION,"engine":Engine.get_version_info().string,"blueprint_hash":Generator.blueprint_hash(candidate),"seconds":outcome.seconds,"rescued":outcome.rescued,"count":outcome.count,"attempt":attempt}
		var cache:=Loader.cache_path(number,daily)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache.get_base_dir()))
		if not SaveManager.atomic_save(cache,candidate):
			result={"error":"Unable to save your new level. Check available storage and retry."}
			break
		result=candidate
		recent_signatures.append(signature)
		if recent_signatures.size()>64: recent_signatures.pop_front()
		break
	restore_timing()
	generating=false
	generation_finished.emit()
	return result

func restore_timing() -> void:
	Engine.time_scale=saved_scale
	Engine.physics_ticks_per_second=saved_ticks
	Engine.max_physics_steps_per_frame=saved_steps

func _exit_tree() -> void:
	if generating: restore_timing()
