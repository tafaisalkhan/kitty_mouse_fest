extends Node2D

const UI=preload("res://scripts/core/UI.gd")
const Loader=preload("res://scripts/gameplay/LevelLoader.gd")
var data: Dictionary
var terrain: Node2D
var kittens: Array=[]
var obstacles: Dictionary={}
var rescued:=0
var elapsed:=0.0
var ended:=false
var paused:=false
var dragging:=false
var pointer_id:=-1
var previous:=Vector2.ZERO
var dig_distance:=0.0
var hint_visible:=false
var hud: Control
var overlay: Control
var progress_label: Label
var time_label: Label
var debug_mode:=false
var dig_sound_timer:=0.0
var particles: Array=[]
var mother_visual: Node2D
var test_mode:=false
var foreground: Node2D
var level_override: Dictionary={}
var world_frame: Node2D
var simulation_mode:=false
var loading:=false
var failure_pending:=false
var failure_popup_shown:=false
var coin_label: Label
var reward_coins:=0
var displayed_coins:=0
var rewards_animated:=false
var section_index:=0
var sections:=1
var camera_offset:=0.0
var section_transition:=false
var camera: Camera2D
var section_gate: StaticBody2D
var bombs_left:=0
var bomb_armed:=false
var bomb_label: Label
var section_label: Label
var blasts: Array=[]
var free_bombs_left:=0
var face_attention_clock:=0.0
var dig_attention_time:=0.0
var dig_attention_point:=Vector2.ZERO
var base_visual: Node2D
var section_cue: Control
var cue_phase:="idle"
var transition_count:=0

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	data=level_override if not level_override.is_empty() else Loader.load_level(SaveManager.level_number,SaveManager.daily_mode)
	if data.get("needs_generation",false):
		loading=true
		var loading_screen:=CanvasLayer.new()
		add_child(loading_screen)
		UI.label(loading_screen,"A new rescue awaits…",Rect2(50,475,620,80),40)
		UI.label(loading_screen,"Preparing your next adventure",Rect2(50,570,620,60),25)
		data=await LevelService.ensure_level(SaveManager.level_number,SaveManager.daily_mode)
		loading_screen.queue_free()
		loading=false
	if data.has("error"):
		UI.label(self,"Level unavailable\n"+data.error,Rect2(40,300,640,400),24)
		UI.button(self,"MAIN MENU",Rect2(140,800,440,70),func(): get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn"))
		return
	sections=int(data.get("sections",1))
	free_bombs_left=int(data.get("bombs",2)) if not data.terrain.get("rock_rects",[]).is_empty() else 0
	bombs_left=free_bombs_left+int(SaveManager.progress.boosters.get("bombs",0)) if free_bombs_left>0 else 0
	if data.get("trial",false): bombs_left=free_bombs_left
	if data.get("physical_bombs",false):
		free_bombs_left=0
		bombs_left=0
	camera=Camera2D.new()
	camera.position=Vector2(360,640)
	camera.position_smoothing_enabled=false
	add_child(camera)
	camera.enabled=true
	PhysicsServer2D.area_set_param(get_world_2d().space,PhysicsServer2D.AREA_PARAM_GRAVITY,float(data.world.gravity))
	var world_art=load("res://scripts/gameplay/WorldArt.gd").new()
	world_art.level_data=data
	add_child(world_art)
	terrain=load("res://scripts/gameplay/SandTerrain.gd").new()
	add_child(terrain)
	terrain.render_visuals=not simulation_mode
	terrain.setup(data.terrain)
	for rect in [Rect2(0,190,30,960*sections),Rect2(690,190,30,960*sections),Rect2(0,1150+960*(sections-1),720,40)]:
		var wall:=StaticBody2D.new()
		var shape:=CollisionShape2D.new()
		var box:=RectangleShape2D.new()
		box.size=rect.size
		shape.shape=box
		wall.position=rect.get_center()
		wall.add_child(shape)
		add_child(wall)
	for item in data.obstacles:
		var obstacle=load("res://scripts/obstacles/Obstacle.gd").new()
		add_child(obstacle)
		obstacle.setup(item)
		obstacle.danger.connect(fail)
		obstacles[item.id]=obstacle
	for obstacle in obstacles.values(): obstacle.links=obstacles
	var mother_pos:=Vector2(data.mother.position[0],data.mother.position[1])
	mother_visual=load("res://scripts/gameplay/CatVisual.gd").new()
	mother_visual.mother=true
	mother_visual.radius=78
	mother_visual.position=mother_pos+Vector2(0,22)
	mother_visual.z_index=3
	add_child(mother_visual)
	mother_visual.set_process(not simulation_mode)
	var rescue_area:=Area2D.new()
	rescue_area.position=mother_pos
	rescue_area.collision_layer=0
	rescue_area.collision_mask=2
	var circle:=CircleShape2D.new()
	circle.radius=data.mother.get("rescue_radius",80)
	var shape:=CollisionShape2D.new()
	shape.shape=circle
	rescue_area.add_child(shape)
	add_child(rescue_area)
	rescue_area.body_entered.connect(rescue_kitten)
	for item in data.kittens:
		var kitten=load("res://scenes/gameplay/Kitten.tscn").instantiate()
		kitten.configure(item)
		kitten.muted=simulation_mode
		kitten.loss_y=1270+960*(sections-1)
		kitten.lost.connect(fail)
		add_child(kitten)
		kitten.visual.set_process(not simulation_mode)
		kittens.append(kitten)
	for obstacle in obstacles.values(): obstacle.configure_chase(kittens,terrain,mother_visual)
	world_frame=load("res://scripts/gameplay/WorldArt.gd").new()
	world_frame.foreground_pass=true
	world_frame.level_data=data
	world_frame.z_index=5
	add_child(world_frame)
	if sections>1: build_section_gate()
	if not simulation_mode:
		build_hud()
		PlatformServices.service_event.connect(platform_event)
	foreground=Node2D.new()
	foreground.z_index=10
	foreground.draw.connect(draw_foreground)
	add_child(foreground)
	hint_visible=SaveManager.get_meta("hint_next",false)
	SaveManager.remove_meta("hint_next")
	if not simulation_mode: apply_safe_area()
	get_tree().auto_accept_quit=false

func apply_safe_area() -> void:
	if OS.get_name()!="Android": return
	var safe:=DisplayServer.get_display_safe_area()
	var window_size:=DisplayServer.window_get_size()
	if window_size.x<=0 or window_size.y<=0: return
	var ratio:=Vector2(720.0/window_size.x,1280.0/window_size.y)
	var top:=maxf(0,safe.position.y*ratio.y-35)
	# The board remains fully visible; only the HUD moves inside system insets.
	hud.position.y=top
	if is_instance_valid(progress_label):
		progress_label.position.y=minf(1190,safe.end.y*ratio.y-top-70)

func build_hud() -> void:
	var layer:=CanvasLayer.new()
	add_child(layer)
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	if sections>1:
		var sky:=ColorRect.new()
		sky.color=Color("279bd0")
		sky.size=Vector2(720,190)
		sky.mouse_filter=Control.MOUSE_FILTER_IGNORE
		hud.add_child(sky)
		section_label=UI.label(hud,"PART 1 / %d"%sections,Rect2(500,83,175,26),18,Color("ffe780"))
	if bombs_left>0:
		game_button("bomb",Rect2(28,1040,78,78),func(): bomb_armed=not bomb_armed if bombs_left>0 else false,Color("db7840"))
		bomb_label=UI.label(hud,"%d BOMBS"%bombs_left,Rect2(7,1120,120,34),20,Color("ffd479"))
	game_button("restart",Rect2(18,18,78,78),restart,Color("219fe2"))
	game_button("settings",Rect2(105,18,78,78),pause_game,Color("eea527"))
	displayed_coins=int(SaveManager.progress.get("coins",0))
	coin_label=UI.wallet(hud,Vector2(500,115),displayed_coins)
	var title:=Panel.new()
	title.position=Vector2(237,21)
	title.size=Vector2(250,67)
	var wood:=UI.box(Color("a95522"),24)
	wood.border_color=Color("f9b65f")
	wood.set_border_width_all(4)
	title.add_theme_stylebox_override("panel",wood)
	hud.add_child(title)
	var level_title:="DAILY" if SaveManager.daily_mode else "Level %d"%SaveManager.level_number
	if SaveManager.trial_mode: level_title="TRIAL %d"%SaveManager.trial_number
	var title_text:=UI.label(hud,level_title,Rect2(240,23,244,61),maxi(22,36-maxi(0,level_title.length()-9)*2),Color("ffe98a"))
	title_text.add_theme_color_override("font_outline_color",Color("5e2b10"))
	var hint_x:=22 if SaveManager.settings.left_handed else 600
	game_button("hint",Rect2(hint_x,18,78,78),toggle_hint,Color("efb92b"))
	time_label=UI.label(hud,"",Rect2(513,47,88,32),19)
	var objective:=Panel.new()
	objective.name="ObjectivePanel"
	objective.position=Vector2(161,105)
	objective.size=Vector2(315,73)
	var cream:=UI.box(Color("fff0c3"),21)
	cream.border_color=Color("ffd378")
	cream.set_border_width_all(2)
	objective.add_theme_stylebox_override("panel",cream)
	hud.add_child(objective)
	for i in mini(5,data.kittens.size()):
		var icon=load("res://scripts/gameplay/CatVisual.gd").new()
		icon.variant=int(data.kittens[i].get("variant",0))
		icon.radius=20
		icon.position=Vector2(190+i*36,143)
		hud.add_child(icon)
	UI.label(hud,"➜",Rect2(376,118,35,46),32,Color("639469"))
	var mom_icon=load("res://scripts/gameplay/CatVisual.gd").new()
	mom_icon.mother=true
	mom_icon.radius=31
	mom_icon.position=Vector2(437,140)
	hud.add_child(mom_icon)
	progress_label=UI.label(hud,"",Rect2(50,1205,620,44),24)
	overlay=Control.new()
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.process_mode=Node.PROCESS_MODE_ALWAYS
	layer.add_child(overlay)

func game_button(kind: String,rect: Rect2,action: Callable,color: Color) -> void:
	var button=load("res://scripts/core/GameButton.gd").new()
	button.name=kind
	button.kind=kind
	button.base=color
	button.position=rect.position
	button.size=rect.size
	button.pressed.connect(func(): AudioManager.play_fx(); action.call())
	hud.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if ended or paused or loading or section_transition: return
	if event is InputEventKey and event.pressed and event.keycode==KEY_F3:
		debug_mode=not debug_mode
		terrain.debug_chunks=debug_mode
		get_tree().debug_collisions_hint=debug_mode
		return
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id<0:
			pointer_id=event.index
			begin_drag(event.position)
		elif not event.pressed and event.index==pointer_id:
			dragging=false
			pointer_id=-1
	elif event is InputEventScreenDrag and event.index==pointer_id:
		drag_to(event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: begin_drag(event.position)
		else: dragging=false
	elif event is InputEventMouseMotion and dragging and pointer_id<0:
		drag_to(event.position)

func _input(event: InputEvent) -> void:
	# Release must clear a drag even when the finger ends over a HUD button.
	if event is InputEventScreenTouch and not event.pressed and event.index==pointer_id:
		dragging=false
		pointer_id=-1
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		dragging=false

func begin_drag(point: Vector2) -> void:
	if ended or section_transition: return
	if point.y<190 or point.y>1150: return
	point.y+=camera_offset
	if bomb_armed:
		use_bomb(point)
		return
	for obstacle in obstacles.values():
		if obstacle.kind=="rotating_wheel" and obstacle.config.get("interactive",false) and point.distance_to(obstacle.position)<22:
			obstacle.config.speed=-float(obstacle.config.get("speed",0.6))
			return
	dragging=true
	previous=point
	drag_to(point-Vector2(0,camera_offset))

func drag_to(point: Vector2) -> void:
	if not dragging or ended or section_transition: return
	point=point.clamp(Vector2(30,190),Vector2(690,1149))
	point.y+=camera_offset
	var removed: int=terrain.dig_segment(previous,point)
	if removed>0:
		dig_attention_point=point
		dig_attention_time=1.0
		world_frame.queue_redraw()
		dig_distance+=previous.distance_to(point)
		if not simulation_mode and dig_sound_timer<=0:
			AudioManager.play_fx("dig")
			dig_sound_timer=0.12
		for i in mini(5,ceili(removed/3.0)):
			particles.append({"p":point+Vector2(randf_range(-8,8),randf_range(-3,3)),"v":Vector2(randf_range(-35,35),randf_range(-40,5)),"life":0.45,"radius":randf_range(1.0,2.0),"color":Color("ffdd82")})
	previous=point

func _process(delta: float) -> void:
	if loading or data.is_empty() or data.has("error") or simulation_mode: return
	var bomb_button:=hud.get_node_or_null("bomb") if is_instance_valid(hud) else null
	if bomb_button:
		var show_bomb: bool=bombs_left>0 and (data.get("trial",false) or has_visible_stone()) and not ended and not section_transition
		bomb_button.visible=show_bomb
		bomb_label.visible=show_bomb
		if not show_bomb: bomb_armed=false
	dig_attention_time=maxf(0,dig_attention_time-delta)
	if not ended:
		face_attention_clock-=delta
		if face_attention_clock<=0:
			face_attention_clock=0.12
			update_face_attention()
	if not ended: elapsed+=delta
	dig_sound_timer-=delta
	if is_instance_valid(progress_label):
		progress_label.text="♥  %d / %d kittens home"%[rescued,kittens.size()]
	if is_instance_valid(time_label):
		time_label.text="%02d:%02d"%[int(elapsed)/60,int(elapsed)%60]
	for i in range(particles.size()-1,-1,-1):
		particles[i].life-=delta
		particles[i].v.y+=400*delta
		particles[i].p+=particles[i].v*delta
		if particles[i].life<=0: particles.remove_at(i)
	for i in range(blasts.size()-1,-1,-1):
		blasts[i].age+=delta
		if blasts[i].age>=0.6: blasts.remove_at(i)
	queue_redraw()
	if foreground: foreground.queue_redraw()

func _physics_process(delta: float) -> void:
	if simulation_mode and not ended: elapsed+=delta
	if ended or section_transition or section_index>=sections-1: return
	var arrivals:=0
	var base_y:=1150+960*section_index
	for kitten in kittens:
		if kitten.rescued or (kitten.position.y>=base_y-180 and kitten.supported and absf(kitten.linear_velocity.y)<90): arrivals+=1
	if is_instance_valid(base_visual): base_visual.set_arrivals(arrivals)
	if arrivals==kittens.size(): advance_section()

func build_section_gate() -> void:
	section_gate=StaticBody2D.new()
	section_gate.position=Vector2(360,1150+960*section_index)
	section_gate.collision_layer=4
	section_gate.collision_mask=2|4
	var shape:=CollisionShape2D.new()
	var box:=RectangleShape2D.new()
	box.size=Vector2(660,16)
	shape.shape=box
	section_gate.add_child(shape)
	add_child(section_gate)
	base_visual=load("res://scripts/gameplay/SectionBase.gd").new()
	base_visual.number=section_index+1
	base_visual.total=kittens.size()
	section_gate.add_child(base_visual)

func section_name(index: int) -> String:
	var names: Array=data.get("section_names",[])
	return String(names[index]) if index<names.size() else "THE NEXT RESCUE"

func show_section_cue(title: String,detail: String) -> void:
	if not is_instance_valid(section_cue):
		section_cue=Control.new()
		section_cue.z_index=25
		section_cue.mouse_filter=Control.MOUSE_FILTER_IGNORE
		hud.get_parent().add_child(section_cue)
	for child in section_cue.get_children():
		section_cue.remove_child(child)
		child.queue_free()
	var plate:=Panel.new()
	plate.position=Vector2(85,430)
	plate.size=Vector2(550,190)
	var style:=UI.box(Color("51408c"),26)
	style.border_color=Color("ffd86b")
	style.set_border_width_all(4)
	plate.add_theme_stylebox_override("panel",style)
	section_cue.add_child(plate)
	var label:=UI.label(section_cue,title,Rect2(105,453,510,65),40)
	label.add_theme_font_override("font",UI.title_font())
	UI.label(section_cue,detail,Rect2(110,530,500,65),25)

func advance_section() -> void:
	section_transition=true
	dragging=false
	bomb_armed=false
	pointer_id=-1
	var old_gate:=section_gate
	var old_visual:=base_visual
	for kitten in kittens: kitten.set_deferred("freeze",true)
	for obstacle in obstacles.values():
		obstacle.set_physics_process(false)
		if obstacle.body is RigidBody2D: obstacle.body.set_deferred("freeze",true)
	var next_index:=section_index+1
	cue_phase="ready"
	if not simulation_mode:
		show_section_cue("BASE %d REACHED!"%(section_index+1),"NEXT: "+section_name(next_index))
		AudioManager.play_fx("rescue")
		await get_tree().create_timer(0.35 if SaveManager.settings.reduce_motion else 0.65,false).timeout
		if not is_inside_tree() or ended: return
	cue_phase="opening"
	if not simulation_mode and not SaveManager.settings.reduce_motion:
		var gate_tween:=create_tween()
		gate_tween.tween_property(old_visual,"opening",1.0,0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await gate_tween.finished
		if not is_inside_tree() or ended: return
	else: old_visual.opening=1.0
	section_index=next_index
	camera_offset=960.0*section_index
	cue_phase="moving"
	if not simulation_mode: show_section_cue("GOING DEEPER...",section_name(section_index))
	if not simulation_mode and not SaveManager.settings.reduce_motion:
		var tween:=create_tween()
		tween.tween_property(camera,"position:y",640+camera_offset,1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	else: camera.position.y=640+camera_offset
	if not is_inside_tree() or ended: return
	old_gate.queue_free()
	section_gate=null
	base_visual=null
	if section_index<sections-1: build_section_gate()
	for kitten in kittens:
		if not kitten.rescued: kitten.set_deferred("freeze",false)
	for obstacle in obstacles.values():
		if not obstacle.round_ended:
			obstacle.set_physics_process(true)
			if obstacle.body is RigidBody2D: obstacle.body.set_deferred("freeze",false)
	if is_instance_valid(section_label): section_label.text="PART %d / %d"%[section_index+1,sections]
	if is_instance_valid(section_cue): section_cue.queue_free()
	section_cue=null
	transition_count+=1
	cue_phase="idle"
	section_transition=false

func use_bomb(point: Vector2) -> bool:
	if data.get("physical_bombs",false) or ended or paused or section_transition or bombs_left<=0: return false
	if point.y<190+camera_offset or point.y>1150+camera_offset: return false
	if point.x<30 or point.x>690: return false
	if free_bombs_left>0: free_bombs_left-=1
	elif not Economy.consume_booster("bombs"): return false
	bombs_left-=1
	bomb_armed=false
	if is_instance_valid(bomb_label): bomb_label.text="%d BOMBS"%bombs_left
	return detonate_world_bomb(point,115)

func detonate_world_bomb(point: Vector2,blast_radius:=145.0) -> bool:
	if ended: return false
	terrain.blast(point,blast_radius)
	if not simulation_mode: blasts.append({"point":point,"age":0.0,"radius":blast_radius})
	for obstacle in obstacles.values():
		if obstacle.kind=="bee" and obstacle.global_position.distance_to(point)<blast_radius+obstacle.radius: obstacle.defeat()
	burst(point,Color("ffbd47"))
	if not simulation_mode: AudioManager.play_fx("boom")
	world_frame.queue_redraw()
	return true

func has_visible_stone() -> bool:
	for stone in data.terrain.get("rock_rects",[]):
		if stone[1]+stone[3]<190+camera_offset or stone[1]>1150+camera_offset: continue
		var start:=Vector2i((Vector2(stone[0],stone[1])-terrain.position)/terrain.CELL)
		var end:=Vector2i((Vector2(stone[0]+stone[2],stone[1]+stone[3])-terrain.position)/terrain.CELL)
		for y in range(maxi(0,start.y),mini(terrain.ROWS,end.y+1)):
			for x in range(maxi(0,start.x),mini(terrain.COLS,end.x+1)):
				if terrain.cells[y*terrain.COLS+x]==2: return true
	return false

func rescue_kitten(kitten: Node2D) -> void:
	if ended or not kitten.has_method("rescue") or kitten.rescued: return
	kitten.rescue()
	var index:=kittens.find(kitten)
	kitten.join_family(mother_visual.position+family_offset(index,kittens.size(),82.0))
	mother_visual.celebrate()
	rescued+=1
	if not simulation_mode: AudioManager.play_fx("rescue")
	burst(mother_visual.position,Color("ffa6c8"))
	if not SaveManager.settings.reduce_motion:
		var tween:=create_tween()
		tween.tween_property(mother_visual,"scale",Vector2(1.15,1.15),0.12)
		tween.tween_property(mother_visual,"scale",Vector2.ONE,0.22)
	if rescued==kittens.size(): win()

func family_offset(index: int,count: int,spread: float) -> Vector2:
	var angle: float=-PI/2 if count<=1 else lerpf(-PI+0.30,-0.30,float(index)/float(count-1))
	return Vector2(cos(angle)*spread,sin(angle)*spread-24)

func stop_hazards() -> void:
	for obstacle in obstacles.values(): obstacle.stop_for_result()

func burst(point: Vector2,color: Color) -> void:
	if simulation_mode: return
	for i in 35:
		particles.append({"p":point,"v":Vector2(randf_range(-160,160),randf_range(-250,-50)),"life":randf_range(0.5,1.4),"color":color})

func fail(_victim=null) -> void:
	if ended: return
	ended=true
	failure_pending=true
	if is_instance_valid(section_cue): section_cue.queue_free()
	section_cue=null
	dragging=false
	pointer_id=-1
	stop_hazards()
	if not simulation_mode: AudioManager.play_fx("fail")
	if not simulation_mode and SaveManager.settings.vibration: Input.vibrate_handheld(90)
	var victim: Node=_victim if is_instance_valid(_victim) else kittens[0]
	if victim==mother_visual: mother_visual.defeat()
	else: mother_visual.cry()
	for kitten in kittens:
		kitten.set_deferred("freeze",true)
		kitten.set_physics_process(false)
		if kitten==victim: kitten.visual.defeat()
		else: kitten.visual.cry()
	if not simulation_mode: show_failure_after_reaction()

func show_failure_after_reaction() -> void:
	await get_tree().create_timer(3.0,false).timeout
	if is_inside_tree() and failure_pending:
		failure_pending=false
		failure_popup_shown=true
		result_panel(false)

func win() -> void:
	if ended: return
	ended=true
	dragging=false
	stop_hazards()
	mother_visual.celebrate()
	for kitten in kittens:
		if kitten.rescued: kitten.visual.celebrate()
	if not simulation_mode: AudioManager.play_fx("win")
	var stars:=3
	if elapsed>data.objectives.get("target_time_seconds",60): stars-=1
	if dig_distance>data.objectives.get("target_dig_distance",1200): stars-=1
	if not test_mode:
		reward_coins=SaveManager.complete(SaveManager.level_number,stars,elapsed,kittens.size())
		show_win_after_reunion(stars)

func show_win_after_reunion(stars: int) -> void:
	await get_tree().create_timer(1.25).timeout
	if is_inside_tree(): result_panel(true,stars)

func panel(title: String,rect:=Rect2(70,335,580,615)) -> void:
	for child in overlay.get_children(): child.queue_free()
	var shade:=ColorRect.new()
	shade.color=Color(0.08,0.09,0.16,0.72)
	shade.size=Vector2(720,1280)
	overlay.add_child(shade)
	var bg:=Panel.new()
	bg.position=rect.position
	bg.size=rect.size
	bg.add_theme_stylebox_override("panel",UI.box(Color("fff0cd"),35))
	overlay.add_child(bg)
	var heading_color:=Color("ff9e9e") if "FAILED" in title else Color("ffe368")
	var heading_outline:=Color("5c1f2e") if "FAILED" in title else Color("7a3b18")
	var heading:=UI.label(overlay,title,Rect2(rect.position+Vector2(20,24),Vector2(rect.size.x-40,70)),43,heading_color)
	heading.add_theme_font_override("font",UI.title_font())
	heading.add_theme_color_override("font_outline_color",heading_outline)
	heading.add_theme_constant_override("outline_size",9)
	# Pop the card into view while the background shade stays stationary.
	bg.pivot_offset=bg.size/2
	if not SaveManager.settings.reduce_motion:
		bg.scale=Vector2.ONE*0.82
		var intro:=create_tween()
		intro.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		intro.tween_property(bg,"scale",Vector2.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func result_panel(success: bool,stars:=0) -> void:
	if success:
		panel("TOGETHER AGAIN!",Rect2(65,235,590,825))
		animate_stars(stars,true)
		show_happy_family(overlay,Vector2(360,555))
		UI.label(overlay,"%d happy kittens  ·  %.1f seconds"%[rescued,elapsed],Rect2(100,640,520,42),25,Color("fff8e5"))
		UI.image(overlay,"res://assets/ui/coin.png",Rect2(286,682,42,42))
		var reward_label:=UI.label(overlay,"+%d"%reward_coins,Rect2(338,679,140,45),31,Color("ffe45e"))
		reward_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		UI.button(overlay,"NEXT LEVEL",Rect2(145,735,430,68),func(): SaveManager.daily_mode=false; SaveManager.level_number+=1; restart(),Color("65ab60"))
		UI.button(overlay,"RETRY",Rect2(145,825,430,65),restart)
		UI.button(overlay,"LEVEL SELECT",Rect2(145,915,430,65),func(): get_tree().change_scene_to_file("res://scenes/menus/LevelSelect.tscn"),Color("3298bd"))
		if not rewards_animated:
			rewards_animated=true
			fly_reward_coins()
		return
	panel("LEVEL FAILED",Rect2(80,275,560,720))
	animate_stars(0,false)
	UI.label(overlay,"A safer path is waiting.",Rect2(100,490,520,45),26,Color("fff8e5"))
	UI.label(overlay,"%d kittens rescued  ·  %.1f seconds"%[rescued,elapsed],Rect2(100,535,520,42),22,Color("ffd8dc"))
	var retry_hint_btn:=UI.button(overlay,"RETRY WITH HINT (%d COINS)"%Economy.RETRY_COST,Rect2(130,595,460,64),func(): pass,Color("ae83c9"))
	retry_hint_btn.add_theme_font_size_override("font_size",24)
	var retry_btn:=UI.button(overlay,"RETRY (%d COINS)"%Economy.RETRY_COST,Rect2(130,675,460,64),func(): pass)
	retry_btn.add_theme_font_size_override("font_size",25)
	var ad_btn:=UI.button(overlay,"WATCH AD (+%d COINS)"%Economy.AD_COIN_REWARD,Rect2(130,755,460,64),func(): pass,Color("55ce17"))
	ad_btn.add_theme_font_size_override("font_size",24)
	ad_btn.visible=not AdsService.no_fill_this_launch
	var refresh_fail_buttons:=func():
		var coins:=int(SaveManager.progress.get("coins",0))
		retry_hint_btn.disabled=coins<Economy.RETRY_COST
		retry_btn.disabled=coins<Economy.RETRY_COST
		if is_instance_valid(coin_label): coin_label.text=str(coins)
		if ad_btn.visible:
			ad_btn.disabled=not AdsService.rewarded_ready
			ad_btn.text="WATCH AD (+%d COINS)"%Economy.AD_COIN_REWARD if AdsService.rewarded_ready else "AD LOADING..."
	retry_hint_btn.pressed.connect(func():
		if Economy.spend_coins(Economy.RETRY_COST):
			if is_instance_valid(coin_label): coin_label.text=str(SaveManager.progress.get("coins",0))
			restart_with_hint()
		else: refresh_fail_buttons.call())
	retry_btn.pressed.connect(func():
		if Economy.spend_coins(Economy.RETRY_COST):
			if is_instance_valid(coin_label): coin_label.text=str(SaveManager.progress.get("coins",0))
			restart()
		else: refresh_fail_buttons.call())
	ad_btn.pressed.connect(func():
		AdsService.request_reward(func():
			Economy.add_coins(Economy.AD_COIN_REWARD)
			refresh_fail_buttons.call()))
	refresh_fail_buttons.call()
	UI.button(overlay,"LEVEL SELECT",Rect2(130,855 if ad_btn.visible else 775,460,64),func(): get_tree().change_scene_to_file("res://scenes/menus/LevelSelect.tscn"),Color("3298bd"))

func animate_stars(stars: int,success: bool) -> void:
	for i in 3:
		var star:=UI.image(overlay,"res://assets/ui/star.png",Rect2(232+i*90,340 if success else 425,76,76))
		star.pivot_offset=Vector2(38,38)
		if i>=stars: star.modulate=Color(0.38,0.32,0.27,0.42)
		if not SaveManager.settings.reduce_motion:
			star.scale=Vector2.ZERO
			var tween:=create_tween()
			tween.tween_interval(0.15+i*0.18)
			tween.tween_property(star,"scale",Vector2.ONE,0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if i<stars: tween.tween_callback(func(): AudioManager.play_fx("star"))

func fly_reward_coins() -> void:
	if reward_coins<=0 or not is_instance_valid(coin_label): return
	if SaveManager.settings.reduce_motion:
		coin_label.text=str(SaveManager.progress.coins)
		return
	for i in 10:
		var coin:=UI.image(overlay,"res://assets/ui/coin.png",Rect2(310,680,46,46))
		coin.pivot_offset=Vector2(23,23)
		var end_point:=hud.position+Vector2(505,120)
		var tween:=create_tween()
		tween.tween_interval(0.7+i*0.07)
		tween.tween_property(coin,"position",Vector2(240+(i%5)*45,610-(i%3)*25),0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin,"position",end_point,0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func():
			coin.queue_free()
			coin_label.text=str(displayed_coins+int(ceil(reward_coins*float(i+1)/10.0)))
			AudioManager.play_fx("coin"))

func show_happy_family(parent: Node,center: Vector2) -> void:
	var group:=Node2D.new()
	group.position=center
	parent.add_child(group)
	for i in kittens.size():
		var child=load("res://scripts/gameplay/CatVisual.gd").new()
		child.variant=kittens[i].visual.variant
		child.radius=33
		child.position=family_offset(i,kittens.size(),88.0)
		child.z_index=1
		group.add_child(child)
		child.celebrate()
	var mom=load("res://scripts/gameplay/CatVisual.gd").new()
	mom.mother=true
	mom.radius=80
	mom.z_index=2
	group.add_child(mom)
	mom.celebrate()

func restart_with_hint() -> void:
	SaveManager.set_meta("hint_next",true)
	restart()

func restart() -> void:
	if ended: AdsService.level_transition()
	get_tree().paused=false
	get_tree().reload_current_scene()

func pause_game() -> void:
	if ended or paused or section_transition: return
	paused=true
	dragging=false
	get_tree().paused=true
	panel("SETTINGS",Rect2(70,160,580,945))
	for i in 3:
		var key: String=["music","effects","vibration"][i]
		var setting_label:=UI.label(overlay,["Music","Sound effects","Vibration"][i],Rect2(110,270+i*80,300,60),30,Color("fff8e5"))
		setting_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var toggle:=CheckButton.new()
		toggle.position=Vector2(500,275+i*80)
		toggle.size=Vector2(110,55)
		toggle.button_pressed=SaveManager.settings[key]
		toggle.toggled.connect(func(value): SaveManager.settings[key]=value; SaveManager.save_settings())
		overlay.add_child(toggle)
	UI.button(overlay,"RATE",Rect2(105,540,240,65),PlatformServices.rate_game,Color("5596dd"))
	UI.button(overlay,"SHARE",Rect2(375,540,240,65),PlatformServices.share_game,Color("5596dd"))
	var coffee:=UI.button(overlay,"COFFEE",Rect2(105,630,240,65),PlatformServices.buy_coffee,Color("c27c4d"))
	coffee.name="CoffeeSupport"
	coffee.disabled=PlatformServices.coffee_price.is_empty()
	UI.button(overlay,"RESTORE",Rect2(375,630,240,65),PlatformServices.restore_purchases,Color("8568c2"))
	UI.button(overlay,"RESUME",Rect2(145,735,430,70),func():
		get_tree().paused=false
		paused=false
		for child in overlay.get_children(): child.queue_free(),Color("65ab60"))
	UI.button(overlay,"RESTART",Rect2(145,830,430,70),restart)
	UI.button(overlay,"MAIN MENU",Rect2(145,925,430,70),func(): get_tree().paused=false; get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn"),Color("3298bd"))

func _notification(what: int) -> void:
	if test_mode: return
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_WM_GO_BACK_REQUEST or what==NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(overlay): pause_game()

func _draw() -> void:
	pass

func draw_foreground() -> void:
	for blast in blasts:
		var age: float=blast.age/0.6
		foreground.draw_circle(blast.point,30+age*(float(blast.get("radius",125))-30),Color(1,0.72,0.2,(1-age)*0.35))
		foreground.draw_arc(blast.point,25+age*(float(blast.get("radius",130))-25),0,TAU,48,Color(1,0.92,0.65,1-age),6*(1-age),true)
	if bomb_armed:
		foreground.draw_string(UI.game_font(),Vector2(60,1080+camera_offset),"TAP STONE TO BLAST",HORIZONTAL_ALIGNMENT_CENTER,600,25,Color("fff2cf"))
		for stone in data.terrain.get("rock_rects",[]):
			var rect:=Rect2(stone[0],stone[1],stone[2],stone[3])
			var cell:=Vector2i((rect.get_center()-terrain.position)/terrain.CELL)
			if cell.y>=0 and cell.y<terrain.ROWS and terrain.cells[cell.y*terrain.COLS+cell.x]==2:
				foreground.draw_rect(rect.grow(6),Color("fff1a1"),false,4)
	if hint_visible and data.has("solution"):
		var path: Array=data.solution
		for i in range(1,path.size()):
			foreground.draw_dashed_line(Vector2(path[i-1][0],path[i-1][1]),Vector2(path[i][0],path[i][1]),Color(1,1,0.8,0.8),4,12)
	for particle in particles:
		var particle_color: Color=particle.color
		if particle.has("radius"): particle_color.a*=clampf(particle.life/0.15,0,1)
		foreground.draw_circle(particle.p,float(particle.get("radius",3)),particle_color)
	if debug_mode:
		foreground.draw_string(UI.game_font(),Vector2(40,1175),"FPS %d | chunks %d | cells %d"%[Engine.get_frames_per_second(),terrain.bodies.size(),terrain.removed],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.GREEN)
		for key in terrain.bodies:
			foreground.draw_rect(Rect2(Vector2(key)*terrain.CELL*terrain.CHUNK+terrain.position,Vector2.ONE*terrain.CELL*terrain.CHUNK),Color(0.2,1,0.6,0.6),false,1)
		for kitten in kittens:
			foreground.draw_line(kitten.position,kitten.position+kitten.linear_velocity*0.15,Color.GREEN,2)

func toggle_hint() -> void:
	if hint_visible:
		hint_visible=false
		return
	if Economy.consume_booster("hints"):
		hint_visible=true
		return
	AdsService.request_reward(func(): hint_visible=true)

func platform_event(kind: String,payload: String) -> void:
	if not is_instance_valid(overlay): return
	if kind=="coffee_price":
		var button:=overlay.get_node_or_null("CoffeeSupport")
		if button: button.disabled=false
	elif paused and kind in ["message","restore_complete","coffee_purchased"]:
		var notice:=overlay.get_node_or_null("NativeStatus")
		if notice==null:
			notice=UI.label(overlay,"",Rect2(95,1000,530,65),20,Color("fff8e5"))
			notice.name="NativeStatus"
		notice.text="Thank you for supporting Kitty Hunt!" if kind=="coffee_purchased" else payload
		notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func sight_clear(from: Vector2,to: Vector2,excluded: Array[RID]=[]) -> bool:
	var ray:=PhysicsRayQueryParameters2D.create(from,to,1|4)
	ray.exclude=excluded
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func nearby_attention(point: Vector2) -> Dictionary:
	var best: Dictionary={}
	var best_score:=INF
	for obstacle in obstacles.values():
		if obstacle.round_ended: continue
		var target_point: Vector2=obstacle.body.global_position if is_instance_valid(obstacle.body) else obstacle.global_position
		var distance:=point.distance_to(target_point)
		if distance>260: continue
		var dangerous: bool=(obstacle.kind in ["bee","spikes","dangerous_plant"] and obstacle.enabled)
		if obstacle.kind=="falling_rock" and obstacle.body.linear_velocity.length()>70: dangerous=true
		if not dangerous and distance>175: continue
		var excluded: Array[RID]=[]
		if obstacle.body is PhysicsBody2D: excluded.append(obstacle.body.get_rid())
		if not sight_clear(point,target_point,excluded): continue
		var score:=distance if dangerous else distance+300
		if score<best_score:
			best_score=score
			best={"point":target_point,"kind":"danger" if dangerous else "object","strength":clampf(1.2-distance/400.0,0.35,1.0)}
	return best

func update_face_attention() -> void:
	if ended or not is_instance_valid(mother_visual): return
	for kitten in kittens:
		if kitten.rescued or kitten.visual.defeated or kitten.visual.crying: continue
		var attention:=nearby_attention(kitten.global_position)
		if not attention.is_empty() and attention.kind=="danger":
			kitten.visual.focus_on(attention.point,attention.kind,attention.strength)
		elif dig_attention_time>0 and kitten.position.distance_to(dig_attention_point)<360:
			kitten.visual.focus_on(dig_attention_point,"dig")
		elif not attention.is_empty(): kitten.visual.focus_on(attention.point,"object")
		elif kitten.position.distance_to(mother_visual.position)<420 and sight_clear(kitten.global_position,mother_visual.global_position):
			kitten.visual.focus_on(mother_visual.global_position,"mom")
	var mom_attention:=nearby_attention(mother_visual.global_position)
	if not mom_attention.is_empty() and mom_attention.kind=="danger":
		mother_visual.focus_on(mom_attention.point,"danger",mom_attention.strength)
	else:
		var nearest: Node2D=null
		var distance:=INF
		for kitten in kittens:
			var candidate: float=kitten.position.distance_squared_to(mother_visual.position)
			if not kitten.rescued and candidate<distance:
				nearest=kitten
				distance=candidate
		if nearest: mother_visual.look_toward(nearest.global_position)
