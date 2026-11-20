extends Node2D
const UI=preload("res://scripts/core/UI.gd")
const Visual=preload("res://scripts/gameplay/CatVisual.gd")
var failures:=0
var gallery_cats: Array=[]
var gallery_mice: Array=[]
var running_gallery:=false
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func _process(delta: float) -> void:
	if not running_gallery: return
	for i in gallery_cats.size():
		var cat=gallery_cats[i]
		if i==0: cat.set_physics_motion(Vector2(35,0),true)
		elif i==1: cat.set_physics_motion(Vector2(75,330),false)
		else:
			cat.set_physics_motion(Vector2.ZERO,true)
			cat.impact=0.35
			cat.landing_time=0.2
		cat.time+=delta
		cat.advance_animation(delta)
		cat.queue_redraw()
	for i in gallery_mice.size():
		var mouse=gallery_mice[i]
		if i==1:
			mouse.fleeing=true
			mouse.panic=0.85

func run() -> void:
	var visual:=Visual.new()
	visual.mother=true
	visual.action_body=true
	add_child(visual)
	visual.set_process(false)
	visual.set_physics_motion(Vector2(50,330),false)
	for tick in 60: visual.advance_animation(1.0/60)
	check(visual.curl_amount>0.95 and visual.locomotion_state=="curled","Kitty keeps her ball shape while falling")
	visual.set_physics_motion(Vector2.ZERO,true)
	visual.react_collision(320)
	for tick in 15: visual.advance_animation(1.0/60)
	check(visual.curl_amount>0.95 and visual.is_curled_pose(),"landing keeps Kitty round with a squash reaction")
	for tick in 30: visual.advance_animation(1.0/60)
	visual.focus_on(Vector2(140,60),"object")
	visual.advance_animation(1.0/60)
	check(visual.is_curled_pose() and visual.gaze_target.length()>0,"round Kitty watches prey")
	visual.react_eat()
	visual.advance_animation(1.0/60)
	check(visual.eating_time>0 and visual.locomotion_state=="eating","eating plays a separate mouth reaction")
	check(visual.get_eating_stage()=="mouth_open","eating starts with an open mouth")
	for tick in 16: visual.advance_animation(1.0/60)
	check(visual.get_eating_stage()=="chewing","eating transitions to chewing")
	for tick in 22: visual.advance_animation(1.0/60)
	check(visual.get_eating_stage()=="tongue_lick" and visual.sparkle_time>0,"eating finishes with tongue and shining eyes")
	visual.set_physics_motion(Vector2.ZERO,true)
	visual.can_stand=false
	for tick in 60: visual.advance_animation(1.0/60)
	check(visual.curl_amount>0.95 and visual.locomotion_state=="curled","ground contact cannot unfold Kitty without standing room")
	visual.can_stand=true
	for tick in 20: visual.advance_animation(1.0/60)
	check(visual.curl_amount>0.95 and visual.is_curled_pose(),"Kitty stays a ball even with open standing room")
	for tick in 60: visual.advance_animation(1.0/60)
	check(visual.get_eating_stage()=="idle" and visual.quality_sprite.pose!=3,"tongue disappears when eating finishes")
	visual.queue_free()
	await get_tree().process_frame
	var game=load("res://scenes/gameplay/Gameplay.tscn").instantiate()
	game.test_mode=true
	game.simulation_mode=true
	game.level_override=preload("res://scripts/generation/TrialLevels.gd").load_trial(2)
	add_child(game)
	var palette_choices: Dictionary={}
	for prey in game.mice: palette_choices[prey.palette_index]=true
	check(palette_choices.size()>=3,"each section has varied mouse colors independent of size")
	var mouse=game.mice[0]
	var left:=false
	var right:=false
	var safe:=true
	var original_cat_x: float=game.cat.position.x
	game.begin_drag(Vector2(600,190)) # touching empty sky must not start movement
	game.dragging=false
	for tick in 360:
		await get_tree().physics_frame
		left=left or mouse.position.x<mouse.origin.x-2
		right=right or mouse.position.x>mouse.origin.x+2
		safe=safe and game.terrain.circle_is_empty(mouse.position,mouse.radius-1)
	check(mouse.state=="patrolling","idle mouse stays calm while Kitty is hidden behind sand")
	check(safe and mouse.position.y>mouse.origin.y+5 and mouse.supported,"mouse falls onto its burrow floor without crossing sand")
	check(game.mice_eaten==0 and game.cat.radius==50,"idle patrol does not auto-complete or grow Kitty")
	check(game.cat.supported and absf(game.cat.position.y-(game.surface_y-game.cat.radius))<3,"Kitty starts on top of the sand outside any hole")
	check(absf(game.cat.position.x-original_cat_x)<0.75 and absf(game.cat.linear_velocity.x)<1,"Kitty stays still at level start, including a touch in empty sky")
	game.begin_drag(Vector2(600,310))
	game.dragging=false
	var last_horizontal_speed: float=game.cat.linear_velocity.x
	var largest_velocity_step:=0.0
	for tick in 120:
		await get_tree().physics_frame
		largest_velocity_step=maxf(largest_velocity_step,absf(game.cat.linear_velocity.x-last_horizontal_speed))
		last_horizontal_speed=game.cat.linear_velocity.x
	check(game.cat.position.x>original_cat_x+10 and absf(game.cat.linear_velocity.x)<=25,"actual digging starts slow, heavy surface rolling")
	check(largest_velocity_step<5,"surface acceleration stays gradual without a launch or snap")
	game.cat.freeze=true
	# Verify two-way rolling on a flat ledge, independent of a bowl-shaped burrow.
	var patrol_mouse=game.mice[0]
	var saved_mouse_position: Vector2=patrol_mouse.position
	var saved_origin: Vector2=patrol_mouse.origin
	var saved_cat_position: Vector2=Vector2(360,game.surface_y-game.cat.radius)
	game.cat.position=Vector2(600,255)
	var ledge:=StaticBody2D.new()
	ledge.collision_layer=4
	var ledge_shape:=CollisionShape2D.new()
	var ledge_box:=RectangleShape2D.new()
	ledge_box.size=Vector2(160,10)
	ledge_shape.shape=ledge_box
	ledge.add_child(ledge_shape)
	ledge.position=Vector2(120,235)
	game.add_child(ledge)
	patrol_mouse.position=Vector2(120,230-patrol_mouse.radius)
	patrol_mouse.origin=patrol_mouse.position
	patrol_mouse.patrol_anchor=patrol_mouse.position
	patrol_mouse.velocity=Vector2.ZERO
	left=false
	right=false
	var patrol_min:=INF
	var patrol_max:=-INF
	for tick in 480:
		await get_tree().physics_frame
		patrol_min=minf(patrol_min,patrol_mouse.position.x)
		patrol_max=maxf(patrol_max,patrol_mouse.position.x)
		left=left or patrol_mouse.position.x<118
		right=right or patrol_mouse.position.x>122
	print("PATROL DIAG ",patrol_min," ",patrol_max," ",patrol_mouse.position," anchor ",patrol_mouse.patrol_anchor," ended ",game.ended)
	check(left and right,"mouse ball rolls both ways on a supported flat ledge")
	ledge.queue_free()
	patrol_mouse.position=saved_mouse_position
	patrol_mouse.origin=saved_origin
	patrol_mouse.patrol_anchor=saved_mouse_position
	patrol_mouse.velocity=Vector2.ZERO
	game.cat.position=saved_cat_position
	var ceiling:=StaticBody2D.new()
	ceiling.collision_layer=4
	var shape:=CollisionShape2D.new()
	var rectangle:=RectangleShape2D.new()
	rectangle.size=Vector2(game.cat.radius*4,6)
	shape.shape=rectangle
	ceiling.add_child(shape)
	ceiling.position=game.cat.position-Vector2(0,game.cat.radius*1.2)
	game.add_child(ceiling)
	for tick in 3: await get_tree().physics_frame
	check(not game.has_standing_clearance(),"low ceiling is detected while the rolling collider still fits")
	ceiling.queue_free()
	for tick in 3: await get_tree().physics_frame
	check(game.has_standing_clearance(),"removing the ceiling restores standing clearance")
	var settled_y: float=mouse.position.y
	game.terrain.dig_segment(mouse.position,mouse.position+Vector2(0,140))
	for tick in 40: await get_tree().physics_frame
	check(mouse.position.y>settled_y+60,"mouse falls when the player digs away its support")
	check(game.terrain.circle_is_empty(mouse.position,mouse.radius-1),"falling mouse collides with the new floor")
	game.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		build_gallery()
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/character-actions.png")
	print("CHARACTER ACTIONS RESULT: ",failures," failures")
	get_tree().quit(failures)

func build_gallery() -> void:
	var bg:=ColorRect.new()
	bg.color=Color("244f7d")
	bg.size=Vector2(720,1280)
	add_child(bg)
	UI.label(self,"CUTE CHARACTERS",Rect2(40,65,640,70),44)
	for i in 3:
		var x:=125+i*235
		var cat:=Visual.new()
		cat.mother=true
		cat.action_body=true
		cat.radius=65
		cat.position=Vector2(x,370)
		add_child(cat)
		cat.set_process(false)
		gallery_cats.append(cat)
		UI.label(self,["ROLLING","FALLING","LANDING"][i],Rect2(x-100,485,200,45),24)
		var mouse=preload("res://scripts/gameplay/Mouse.gd").new()
		mouse.config={"kind":"SMALL" if i<2 else "BIG"}
		mouse.preview_mode=true
		mouse.radius=43
		mouse.position=Vector2(x,820)
		mouse.origin=mouse.position
		mouse.show_label=false
		if i==2: mouse.celebrate_escape()
		add_child(mouse)
		gallery_mice.append(mouse)
		UI.label(self,["IDLE PATROL","PANIC","HAPPY ESCAPE"][i],Rect2(x-105,965,210,45),23)
	UI.label(self,"Front-facing mice · paws · ears · tails\nKitty unfolds when she lands",Rect2(50,1090,620,100),26)
	running_gallery=true
