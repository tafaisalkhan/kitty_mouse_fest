extends "res://scripts/gameplay/Gameplay.gd"
const HuntLevels=preload("res://scripts/generation/HuntLevels.gd")
var mice: Array=[]
var growth:=0
var mice_eaten:=0
var hunt_complete:=false
var failure_reason:="Avoid hazards and eat smaller mice first."
var cat: RigidBody2D
var starting_art_scale:=Vector2.ONE
var growth_from:=50.0
var growth_target:=50.0
var growth_age:=1.0
var last_section:=-1
var active_hazard_section:=-1
var surface_y:=330.0
var surface_goal_x:=-1.0
var standing_shape:=RectangleShape2D.new()
var steering_velocity:=0.0
var last_meal_age:=0.0
var landing_settle_time:=0.0
var grouped_mice: Dictionary={}
var next_burrow_thread: Thread
var next_burrow_number:=0
var tilt_control=preload("res://scripts/gameplay/TiltControl.gd").new()
var tilt_axis:=0.0
var cat_call_timer:=8.0
var prey_target: Node2D

func _ready() -> void:
	if level_override.is_empty() or level_override.get("mode","")!="mouse_hunt":
		level_override=preload("res://scripts/generation/TrialLevels.gd").load_trial(SaveManager.trial_number) if SaveManager.trial_mode else HuntLevels.create(SaveManager.level_number,SaveManager.daily_mode)
	if level_override.has("error"):
		super._ready()
		return
	level_override=level_override.duplicate(true)
	# Verification replays widen the authored route by Kitty's added radius,
	# using actual adjacent narrow strokes rather than changing the brush.
	level_override.reference_brush_radius=float(level_override.terrain.get("brush_radius",84))+50.0
	level_override.terrain.brush_radius=28.0
	level_override.start_surface_y=surface_y
	level_override.tutorial=level_override.get("tutorial","Dig small strokes. Widen Kitty's path. Eat SMALL first!") if level_override.get("trial",false) or level_override.get("endless",false) else "Dig small strokes. Widen Kitty's path. Eat SMALL first!"
	super._ready()
	if kittens.is_empty(): return
	cat=kittens[0]
	cat.mass=4.0
	cat.max_speed=480.0
	cat.max_side_speed=90.0
	cat.linear_damp=0.85
	cat.angular_damp=3.5
	cat.physics_material_override.bounce=0.22
	cat.physics_material_override.friction=0.85
	cat.visual.action_body=true
	starting_art_scale=cat.visual.art_scale*2.0
	set_cat_radius(50.0)
	prepare_start_surface()
	# The legacy goal is never visible or active in the hunting mode.
	mother_visual.hide()
	var unused_goal_visual:=mother_visual
	mother_visual=cat.visual
	unused_goal_visual.queue_free()
	starting_art_scale=cat.visual.art_scale
	var palette_start:=randi_range(0,5)
	for item in data.mice:
		var mouse=preload("res://scripts/gameplay/Mouse.gd").new()
		add_child(mouse)
		mouse.setup(item,cat,terrain,self)
		mouse.set_body_palette(palette_start+mice.size())
		mice.append(mouse)
		var group_id: String=item.get("group_id","")
		if not group_id.is_empty():
			mouse.show_label=false
			if not grouped_mice.has(group_id):
				var label:=UI.label(self,"",Rect2(0,0,240,36),20,Color("fff5d9"))
				label.z_index=7
				grouped_mice[group_id]={"members":[],"label":label}
			grouped_mice[group_id].members.append(mouse)
	for obstacle in obstacles.values():
		if obstacle.kind=="bee":
			var part:=floori((obstacle.position.y-190)/960.0)
			obstacle.config.nav_min_y=190+960*part
			obstacle.config.nav_max_y=1150+960*part
			obstacle.configure_chase(kittens,terrain,null)
	sync_active_hazards()
	if not simulation_mode and not test_mode: AudioManager.play_fx("start")
	if data.get("endless",false) and not test_mode: call_deferred("prefetch_next_burrow")

func prefetch_next_burrow() -> void:
	if SaveManager.daily_mode: return
	next_burrow_number=SaveManager.level_number+1
	var number:=next_burrow_number
	next_burrow_thread=Thread.new()
	next_burrow_thread.start(func():return preload("res://scripts/generation/EndlessBurrows.gd").build(number,number*104729))

func collect_prefetched_burrow() -> void:
	if next_burrow_thread and not next_burrow_thread.is_alive():
		var result: Dictionary=next_burrow_thread.wait_to_finish()
		preload("res://scripts/generation/EndlessBurrows.gd").store_prefetched(next_burrow_number,result)
		next_burrow_thread=null

func _exit_tree() -> void:
	if next_burrow_thread and next_burrow_thread.is_started(): next_burrow_thread.wait_to_finish()

func prepare_start_surface() -> void:
	# Presentation/start behavior is applied at runtime; authored level files stay intact.
	for row in terrain.ROWS:
		var y: float=terrain.position.y+row*terrain.CELL
		if y>=surface_y+90: break
		for column in terrain.COLS:
			var index: int=row*terrain.COLS+column
			if y<surface_y: terrain.cells[index]=0
			elif terrain.cells[index] not in [2,3]: terrain.cells[index]=1
			terrain.dirty[Vector2i(column/terrain.CHUNK,row/terrain.CHUNK)]=true
	terrain.rebuild()
	terrain.removed=0
	cat.position=Vector2(float(data.get("start_x",360)),surface_y-cat.radius)
	cat.linear_velocity=Vector2.ZERO
	cat.angular_velocity=0.0
	cat.reset_physics_interpolation()

func begin_drag(point: Vector2) -> void:
	var before: int=terrain.removed
	super.begin_drag(point)
	if terrain.removed>before and section_index==0 and point.y>=190 and point.y<600:
		surface_goal_x=clampf(point.x,80,640)

func drag_to(point: Vector2) -> void:
	var before: int=terrain.removed
	super.drag_to(point)
	if terrain.removed>before and section_index==0 and point.y>=190 and point.y<600:
		surface_goal_x=clampf(point.x,80,640)

func walk_on_surface() -> void:
	var desired:=0.0
	if surface_goal_x>=0: desired=clampf((surface_goal_x-cat.position.x)*1.4,-24,24)
	cat.apply_central_force(Vector2(clampf((desired-cat.linear_velocity.x)*3,-100,100)*cat.mass,0))

func build_hud() -> void:
	super.build_hud()
	for child in hud.get_children():
		if child is Node2D and child.get_script()==load("res://scripts/gameplay/CatVisual.gd"):
			child.hide()
		if child is Label and child.text=="➜": child.hide()
	var objective:=hud.get_node_or_null("ObjectivePanel")
	if objective: objective.hide()
	if is_instance_valid(progress_label):
		progress_label.queue_free()
		progress_label=null

func _process(delta: float) -> void:
	super._process(delta)
	collect_prefetched_burrow()
	if simulation_mode or not is_instance_valid(cat): return
	for group in grouped_mice.values():
		var live: Array=group.members.filter(func(m):return not m.eaten)
		group.label.visible=not live.is_empty() and int(group.members[0].config.section)==section_index and not ended
		if live.is_empty(): continue
		var center:=Vector2.ZERO
		var top:=INF
		for mouse in live:
			center+=mouse.position
			top=minf(top,mouse.position.y-mouse.radius*1.8-34)
		center/=live.size()
		group.label.position=Vector2(center.x-120,top)
		group.label.text="%d SMALL%s"%[live.size()," !" if live.any(func(m):return m.fleeing) else ""]
	# Follow moving prey every rendered frame, including while Kitty rolls.
	if not ended: update_face_attention()
	if last_section!=section_index:
		last_section=section_index
		data.solution=data.section_solutions[section_index]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(cat): return
	if growth_age<0.45:
		growth_age=minf(0.45,growth_age+delta)
		var amount:=smoothstep(0,1,growth_age/0.45)
		set_cat_radius(lerpf(growth_from,growth_target,amount))
	if ended or paused or section_transition:
		tilt_control.reset()
		tilt_axis=0.0
		return
	tilt_axis=0.0
	if not simulation_mode and not test_mode and not paused:
		cat_call_timer-=delta
		if cat_call_timer<=0:
			cat_call_timer=randf_range(12.0,22.0)
			if cat.visual.eating_time<=0: AudioManager.play_fx("cat",randf_range(0.95,1.05))
	if active_hazard_section!=section_index: sync_active_hazards()
	var clearing: bool=data.get("endless",false) and mice.all(func(m):return int(m.config.section)!=section_index or m.eaten)
	if not cat.freeze:
		if clearing: steer_toward_base()
		elif section_index==0 and cat.supported and cat.position.y<surface_y: walk_on_surface()
		else: steer_toward_prey(delta)
	if mice_eaten>=mice.size():
		last_meal_age+=delta
		if last_meal_age>=0.5 and (simulation_mode or cat.visual.eating_time<=0): complete_hunt()
		return
	for mouse in mice:
		if int(mouse.config.section)==section_index and not mouse.eaten:
			if simulation_mode: elapsed+=delta
			return
	# Enter the next room through its central opening, rather than opening the
	# gate while Kitty is still at a side pocket outside the next room's entry.
	if clearing and section_index<sections-1 and absf(cat.position.x-360)>12: return
	if section_index==sections-1:
		last_meal_age+=delta
		if last_meal_age>=0.5 and (simulation_mode or cat.visual.eating_time<=0): complete_hunt()
		return
	super._physics_process(delta)

func steer_with_tilt() -> void:
	# Apply a mass-scaled force and rolling torque strong enough to overcome sand friction, never move through terrain or cancel falling.
	var desired:=tilt_axis*240.0
	var acceleration:=clampf((desired-cat.linear_velocity.x)*10.0,-1150,1150)
	cat.apply_central_force(Vector2(acceleration*cat.mass,0))
	cat.apply_torque(tilt_axis*cat.mass*28000.0)
	steering_velocity=cat.linear_velocity.x

func steer_toward_base() -> void:
	var desired:=clampf((360-cat.position.x)*2.0,-60,60)
	cat.apply_central_force(Vector2(clampf((desired-cat.linear_velocity.x)*5,-240,240)*cat.mass,0))

func has_standing_clearance() -> bool:
	# Check head/torso room above the circular rolling collider. The bottom
	# part is covered by the circle, so floor contact cannot block unfolding.
	standing_shape.size=Vector2(cat.radius*2.6,cat.radius*2.1)
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=standing_shape
	query.transform=Transform2D(0,cat.global_position+Vector2(0,-cat.radius*0.6))
	query.collision_mask=1|4
	query.exclude=[cat.get_rid()]
	query.margin=0.2
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func sync_active_hazards() -> void:
	active_hazard_section=section_index
	for obstacle in obstacles.values():
		var active: bool=int(floor((obstacle.position.y-190)/960.0))==section_index and not obstacle.round_ended
		obstacle.set_physics_process(active)
		if obstacle.body is RigidBody2D: obstacle.body.set_deferred("freeze",not active)

func steer_toward_prey(delta: float) -> void:
	# Kitty eagerly rolls toward edible prey; excavation still determines
	# which passages exist, and gravity/terrain collisions control her descent.
	var target: Node2D=null
	var nearest:=800.0
	var clear_target:=false
	for mouse in mice:
		if mouse.eaten or mouse.required_growth>growth or int(mouse.config.section)!=section_index: continue
		var offset: Vector2=mouse.global_position-cat.global_position
		if offset.y < -180 or offset.y>820: continue
		var distance:=offset.length()
		var clear:=sight_clear(cat.global_position,mouse.global_position)
		if clear and (not clear_target or distance<nearest):
			target=mouse
			nearest=distance
			clear_target=true
		elif not clear_target and distance<nearest:
			target=mouse
			nearest=distance
	var desired:=0.0
	if target:
		prey_target=target
		var approach_x: float=target.position.x
		for mouse in mice:
			if mouse.eaten or mouse.required_growth<=growth or int(mouse.config.section)!=section_index: continue
			if mouse.position.distance_to(target.position)>cat.radius*2+mouse.radius+target.radius+35: continue
			# A larger cat needs room to approach food beside an oversized mouse.
			var away:=signf(target.position.x-mouse.position.x)
			if away==0: away=signf(cat.position.x-mouse.position.x)
			if away==0: away=1.0
			approach_x=target.position.x+away*(cat.radius*0.9+mouse.radius*0.2)
			break
		approach_x=clampf(approach_x,36+cat.radius,684-cat.radius)
		var max_speed:=220.0 if clear_target else 135.0
		desired=clampf((approach_x-cat.position.x)*4.0,-max_speed,max_speed)
	steering_velocity=move_toward(steering_velocity,desired,720*delta)
	var acceleration_limit:=1150.0
	var acceleration:=clampf((steering_velocity-cat.linear_velocity.x)*8.0,-acceleration_limit,acceleration_limit)
	cat.apply_central_force(Vector2(acceleration*cat.mass,0))
	if absf(steering_velocity)>5.0:
		cat.apply_torque(clampf(steering_velocity/220.0,-1.0,1.0)*cat.mass*26000.0)

func rescue_kitten(_kitten: Node2D) -> void:
	pass # Reaching a former rescue goal never completes a hunt.

func encounter_mouse(mouse: Node2D) -> void:
	if ended or mouse.eaten or mouse.get_meta("encounter_pending",false): return
	mouse.set_meta("encounter_pending",true)
	call_deferred("resolve_mouse",mouse)

func resolve_mouse(mouse: Node2D) -> void:
	if ended or not is_instance_valid(mouse) or mouse.eaten: return
	if growth<mouse.required_growth:
		failure_reason="That mouse needs SIZE %d. Eat small mice first!"%(mouse.required_growth+1)
		fail(cat)
		return
	cat.visual.react_eat()
	mouse.catch_mouse(cat.visual.mouth_world_position())
	mice_eaten+=1
	growth+=int(mouse.config.growth)
	cat.set_meta("growth",growth)
	cat.mass=4.0+growth*0.6
	growth_from=cat.radius
	growth_target=minf(77,50+growth*3)
	growth_age=0.0
	burst(mouse.position,Color("ffd879"))
	if not simulation_mode:
		AudioManager.play_fx("mouse_die")
		play_meal_sound(mouse.required_growth>0 or mice_eaten==mice.size())
	if mice_eaten==mice.size():
		last_meal_age=0.0
		landing_settle_time=0.0

func play_meal_sound(big_or_last: bool) -> void:
	await get_tree().create_timer(0.12).timeout
	if is_inside_tree(): AudioManager.play_fx("eat_big" if big_or_last else "eat")

func complete_hunt() -> void:
	if hunt_complete: return
	hunt_complete=true
	cat.rescue()
	rescued=1
	win()

func set_cat_radius(value: float) -> void:
	cat.radius=value
	for child in cat.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D: child.shape.radius=value
	cat.visual.radius=value
	cat.visual.art_scale=starting_art_scale*(value/50.0)
	cat.visual.queue_redraw()

func stop_hazards() -> void:
	super.stop_hazards()
	for mouse in mice: mouse.set_physics_process(false)

func fail(victim=null) -> void:
	if ended: return
	super.fail(victim)
	for mouse in mice: mouse.celebrate_escape()

func update_face_attention() -> void:
	if ended or not is_instance_valid(cat): return
	var danger:=nearby_attention(cat.global_position)
	if not danger.is_empty() and danger.kind=="danger" and cat.global_position.distance_to(danger.point)<120:
		cat.visual.food_interest=0.0
		cat.visual.focus_on(danger.point,"danger")
		return
	var nearest: Node2D=null
	var distance:=INF
	if is_instance_valid(prey_target) and not prey_target.eaten and int(prey_target.config.section)==section_index and prey_target.required_growth<=growth:
		nearest=prey_target
		distance=-1.0
	for mouse in mice:
		if mouse.eaten or int(mouse.config.section)!=section_index: continue
		if mouse.required_growth>growth: continue
		var candidate: float=cat.global_position.distance_to(mouse.global_position)
		if not sight_clear(cat.global_position,mouse.global_position): candidate+=5000
		if candidate<distance:
			nearest=mouse
			distance=candidate
	if nearest:
		cat.visual.focus_on(nearest.global_position,"object")
		cat.visual.food_interest=clampf((300-cat.global_position.distance_to(nearest.global_position))/220.0,0,1) if sight_clear(cat.global_position,nearest.global_position) else 0.0
	else:
		cat.visual.food_interest=0.0
		if dig_attention_time>0: cat.visual.focus_on(dig_attention_point,"dig")

func result_panel(success: bool,stars:=0) -> void:
	if success:
		panel("TRIAL %d CLEARED!"%SaveManager.trial_number if SaveManager.trial_mode else "HUNT COMPLETE!",Rect2(65,235,590,825))
		animate_stars(stars,true)
		var mom=load("res://scripts/gameplay/CatVisual.gd").new()
		mom.mother=true
		mom.action_body=true
		mom.radius=78
		mom.position=Vector2(360,550)
		overlay.add_child(mom)
		mom.celebrate()
		UI.label(overlay,"%d mice eaten · SIZE %d"%[mice_eaten,growth+1],Rect2(95,645,530,44),27)
		if SaveManager.trial_mode: UI.label(overlay,"Trial stars saved · Main progress unchanged",Rect2(95,685,530,50),21)
		else:
			UI.image(overlay,"res://assets/ui/coin.png",Rect2(286,689,38,38))
			var reward_label:=UI.label(overlay,"+%d"%reward_coins,Rect2(334,685,140,45),30,Color("ffe45e"))
			reward_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var next_btn:=UI.button(overlay,"TRIAL SELECT" if SaveManager.trial_mode and SaveManager.trial_number==preload("res://scripts/generation/TrialLevels.gd").COUNT else "NEXT TRIAL" if SaveManager.trial_mode else "NEXT HUNT",Rect2(145,745,430,68),next_hunt,Color("65ab60"))
		var retry_btn:=UI.button(overlay,"RETRY",Rect2(145,835,430,65),restart)
		var menu_btn:=UI.button(overlay,"MAIN MENU",Rect2(145,925,430,65),func(): get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn"),Color("3298bd"))
		var win_buttons: Array[Button]=[next_btn,retry_btn,menu_btn]
		if not rewards_animated and not SaveManager.trial_mode:
			rewards_animated=true
			fly_reward_coins(win_buttons)
	else:
		panel("HUNT FAILED",Rect2(80,275,560,720))
		animate_stars(0,false)
		var reason:=UI.label(overlay,failure_reason,Rect2(100,490,520,85),24)
		reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var retry_btn:=UI.button(overlay,"RETRY (%d COINS)"%Economy.RETRY_COST,Rect2(130,595,460,64),func(): pass,Color("65ab60"))
		retry_btn.add_theme_font_size_override("font_size",25)
		var hint_btn:=UI.button(overlay,"SHOW SAFE PATH (%d COINS)"%Economy.RETRY_COST,Rect2(130,675,460,64),func(): pass)
		hint_btn.add_theme_font_size_override("font_size",24)
		var ad_btn:=UI.button(overlay,"WATCH AD (+%d COINS)"%Economy.AD_COIN_REWARD,Rect2(130,755,460,64),func(): pass,Color("55ce17"))
		ad_btn.add_theme_font_size_override("font_size",24)
		ad_btn.visible=not AdsService.no_fill_this_launch
		var refresh_fail_buttons:=func():
			var coins:=int(SaveManager.progress.get("coins",0))
			retry_btn.disabled=coins<Economy.RETRY_COST
			hint_btn.disabled=coins<Economy.RETRY_COST
			if is_instance_valid(coin_label): coin_label.text=str(coins)
			if ad_btn.visible:
				ad_btn.disabled=not AdsService.rewarded_ready
				ad_btn.text="WATCH AD (+%d COINS)"%Economy.AD_COIN_REWARD if AdsService.rewarded_ready else "AD LOADING..."
		retry_btn.pressed.connect(func():
			if Economy.spend_coins(Economy.RETRY_COST):
				if is_instance_valid(coin_label): coin_label.text=str(SaveManager.progress.get("coins",0))
				restart()
			else: refresh_fail_buttons.call())
		hint_btn.pressed.connect(func():
			if Economy.spend_coins(Economy.RETRY_COST):
				if is_instance_valid(coin_label): coin_label.text=str(SaveManager.progress.get("coins",0))
				restart_with_hint()
			else: refresh_fail_buttons.call())
		ad_btn.pressed.connect(func():
			AdsService.request_reward(func():
				Economy.add_coins(Economy.AD_COIN_REWARD)
				refresh_fail_buttons.call()))
		refresh_fail_buttons.call()
		UI.button(overlay,"MAIN MENU",Rect2(130,855 if ad_btn.visible else 775,460,64),func(): get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn"),Color("3298bd"))

func next_hunt() -> void:
	SaveManager.daily_mode=false
	if SaveManager.trial_mode:
		if SaveManager.trial_number>=preload("res://scripts/generation/TrialLevels.gd").COUNT:
			SaveManager.set_meta("open_trial",true)
			get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
			return
		SaveManager.trial_number+=1
		SaveManager.level_number=SaveManager.trial_number
	else: SaveManager.level_number+=1
	restart()
