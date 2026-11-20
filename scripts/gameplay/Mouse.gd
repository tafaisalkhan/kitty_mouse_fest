extends CharacterBody2D
const UI=preload("res://scripts/core/UI.gd")
var config: Dictionary
var origin:=Vector2.ZERO
var radius:=15.0
var required_growth:=0
var eaten:=false
var fleeing:=false
var state:="hiding"
var kitty: Node2D
var terrain: Node2D
var game: Node2D
var time:=0.0
var flee_count:=0
var preview_mode:=false
var show_label:=true
var facing:=1.0
var panic:=0.0
var alarm_memory:=0.0
var startle_cooldown:=0.0
var escape_anchor:=Vector2.ZERO
var celebrating:=false
var escape_index:=0
var patrol_anchor:=Vector2.ZERO
var patrol_distance:=7.0
var walking:=false
var quality_sprite: Node2D
var supported:=false
var roll_angle:=0.0
var ball_collider: CollisionShape2D
const BODY_PALETTE=[Color("7ddd48"),Color("66beff"),Color("c397ef"),Color("ffb968"),Color("ef91c4"),Color("67d6be")]
var palette_index:=0
var palette_material: ShaderMaterial
var elasticity=preload("res://scripts/gameplay/BallElasticity.gd").new()
var elastic_scale:=Vector2.ONE
var pupil_gaze:=Vector2.ZERO
var ball_spin=preload("res://scripts/gameplay/BallSpin.gd").new()

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF if preview_mode else Node.PHYSICS_INTERPOLATION_MODE_ON
	quality_sprite=preload("res://scripts/gameplay/QualitySprite.gd").new()
	add_child(quality_sprite)
	quality_sprite.configure("res://assets/characters/mouse-ball.png",3,2)
	quality_sprite.hide()
	palette_material=ShaderMaterial.new()
	palette_material.shader=preload("res://assets/characters/mouse_palette.gdshader")
	quality_sprite.set_atlas_material(palette_material)
	set_body_palette(randi_range(0,BODY_PALETTE.size()-1))
	collision_layer=8
	collision_mask=1|4|8
	motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	ball_collider=CollisionShape2D.new()
	var circle:=CircleShape2D.new()
	circle.radius=radius
	ball_collider.shape=circle
	add_child(ball_collider)

func _process(delta: float) -> void:
	var spin_angle: float=ball_spin.advance(delta,velocity,supported or preview_mode or celebrating,SaveManager.settings.get("reduce_motion",false))
	if is_instance_valid(quality_sprite): quality_sprite.rotation=spin_angle
	var desired_gaze:=Vector2.ZERO
	if is_instance_valid(kitty): desired_gaze=(kitty.global_position-global_position).rotated(-spin_angle).normalized()*Vector2(0.060,0.050)
	pupil_gaze=pupil_gaze.lerp(desired_gaze,1-exp(-delta*12))
	if is_instance_valid(palette_material): palette_material.set_shader_parameter("eye_gaze",pupil_gaze)
	elastic_scale=elasticity.advance(delta,velocity.y,supported or preview_mode,SaveManager.settings.get("reduce_motion",false))
	if preview_mode or celebrating:
		time+=delta
		if preview_mode:
			position=origin+Vector2(sin(time*1.8)*radius*0.12,0)
			walking=true
		queue_redraw()
	update_quality_pose()

func celebrate_escape() -> void:
	if eaten: return
	celebrating=true
	fleeing=false
	panic=0.0
	state="celebrating"

func setup(data: Dictionary,cat: Node2D,ground: Node2D,level: Node2D) -> void:
	config=data
	position=Vector2(data.position[0],data.position[1])
	origin=position
	patrol_anchor=origin
	escape_anchor=origin
	radius=maxf(22.0 if data.kind=="SMALL" else 35.0,float(data.radius))
	config.radius=radius
	if is_instance_valid(ball_collider): ball_collider.shape.radius=radius
	required_growth=int(data.required_growth)
	kitty=cat
	terrain=ground
	game=level
	z_index=4
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if preview_mode or eaten or game.ended or game.section_transition or int(config.section)!=game.section_index: return
	time+=delta
	var before:=position
	var desired_x:=0.0
	var distance:=global_position.distance_to(kitty.global_position)
	startle_cooldown=maxf(0,startle_cooldown-delta)
	var visible_cat: bool=distance<340 and game.sight_clear(global_position,kitty.global_position)
	alarm_memory=0.85 if visible_cat else maxf(0,alarm_memory-delta)
	if alarm_memory>0:
		if not fleeing:
			if not game.simulation_mode and not game.test_mode: AudioManager.play_fx("mouse",randf_range(0.95,1.08))
			flee_count+=1
			escape_anchor=origin
			if supported and startle_cooldown<=0:
				velocity.y=-115
				startle_cooldown=1.5
		fleeing=true
		state="fleeing"
		panic=clampf(1.0-distance/400.0,0.58,1.0) if visible_cat else maxf(0.3,panic-delta*0.4)
		var direction: Vector2=(global_position-kitty.global_position).normalized()
		if config.has("escape_route"):
			direction=Vector2.ZERO
			if escape_index<config.escape_route.size():
				var waypoint:=Vector2(config.escape_route[escape_index][0],config.escape_route[escape_index][1])
				if position.distance_to(waypoint)<5:
					escape_index+=1
				elif waypoint.distance_to(kitty.position)>position.distance_to(kitty.position)-12:
					direction=(waypoint-position).normalized()
		elif absf(direction.x)<0.3:
			# Kitty directly above is still a threat: choose an open side instead
			# of multiplying escape speed by an almost-zero horizontal vector.
			var side: float=1.0 if palette_index%2 else -1.0
			if not game.sight_clear(position,position+Vector2(side*50,0)): side=-side
			direction=Vector2(side,0)
		if absf(direction.x)>0.08: facing=signf(direction.x)
		# Escape steering only supplies horizontal rolling. Gravity always owns
		# vertical motion, so a route can never make a mouse hover or climb air.
		desired_x=signf(direction.x)*maxf(65,float(config.flee_speed))
		var budget: float=maxf(24,float(config.escape_distance))
		if absf(position.x-escape_anchor.x)>budget and signf(desired_x)==signf(position.x-escape_anchor.x): desired_x=0.0
	else:
		if fleeing: patrol_anchor=position
		fleeing=false
		panic=maxf(0,panic-delta*2)
		state="patrolling"
		var phase:=fmod(time+origin.x*0.013,8.0)
		var progress: float=lerpf(-1,1,phase/2.4) if phase<2.4 else 1.0 if phase<3.4 else lerpf(1,-1,(phase-3.4)/2.4) if phase<5.8 else -1.0
		var target_x: float=patrol_anchor.x+progress*patrol_distance
		desired_x=clampf((target_x-position.x)*4,-13,13)
	velocity.x=move_toward(velocity.x,desired_x,delta*(330 if fleeing else 150))
	velocity.y=minf(240,velocity.y+980*delta)
	var fall_speed:=velocity.y
	# Sweep the circle and slide its remaining displacement along each contact.
	# This preserves sideways rolling on a floor without turning gravity into
	# artificial horizontal speed (CharacterBody floating mode does that).
	var was_supported:=supported
	supported=false
	var travel:=velocity*delta
	for i in 4:
		var contact:=move_and_collide(travel)
		if not contact: break
		var normal:=contact.get_normal()
		if normal.y< -0.45: supported=true
		velocity=velocity.slide(normal)
		travel=contact.get_remainder().slide(normal)
		if travel.length_squared()<0.000001: break
	if supported and not was_supported:
		elasticity.land(fall_speed)
		if fall_speed>180: velocity.y=-minf(90,fall_speed*0.14)
	walking=absf(position.x-before.x)>0.01
	if walking: facing=signf(position.x-before.x)
	roll_angle+=(position.x-before.x)/maxf(radius,1)
	if position.y>patrol_anchor.y+radius: patrol_anchor=position
	# The open mouth can reach an edible ball a little before body contact.
	# Oversized mice only fail on actual contact, never an invisible padded halo.
	var reach: float=12.0 if required_growth<=game.growth else -0.5
	if global_position.distance_to(kitty.global_position)<kitty.radius+radius+reach: game.encounter_mouse(self)
	queue_redraw()

func catch_mouse(mouth:=Vector2.INF) -> void:
	if eaten: return
	eaten=true
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	ball_collider.set_deferred("disabled",true)
	state="eaten"
	set_physics_process(false)
	if game.simulation_mode:
		hide()
		return
	var tween:=create_tween().set_parallel(true)
	if mouth!=Vector2.INF: tween.tween_property(self,"global_position",mouth,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self,"scale",Vector2.ONE*0.05,0.18)
	tween.tween_property(self,"modulate:a",0.0,0.18)
	tween.chain().tween_callback(hide)

func _draw() -> void:
	if eaten: return
	if supported or preview_mode:
		draw_set_transform(Vector2(0,radius*0.97),0,Vector2(1,0.15))
		draw_circle(Vector2.ZERO,radius*0.9,Color(0.16,0.12,0.15,0.18))
		draw_set_transform(Vector2.ZERO)
	var danger: bool=not celebrating and is_instance_valid(game) and required_growth>game.growth
	if is_instance_valid(quality_sprite) and quality_sprite.ready_art:
		draw_status(danger)
		return
	var color:=Color("a4b7d8") if config.kind=="SMALL" else Color("c4a088")
	var stride:=time*(23+panic*15) if fleeing else time*9 if walking else 0.0
	var bounce:=maxf(0,sin(time*9))*radius*0.5 if celebrating else absf(sin(stride))*radius*(0.09 if fleeing else 0.025)
	var shake:=sin(time*65)*panic*radius*0.06
	# All faces look toward the player. Motion is carried by paws and body lean.
	draw_set_transform(Vector2(shake,-bounce))
	var tail:=PackedVector2Array()
	for i in 25:
		var t:=float(i)/24
		tail.append(Vector2(facing*(0.32+t*1.9),0.4+sin(t*PI)*0.65-t*0.5+sin(time*3+t*5)*0.10*t)*radius)
	draw_polyline(tail,Color("ac7288"),maxf(3,radius*0.18),true)
	draw_polyline(tail,Color("f2b6c9"),maxf(2,radius*0.11),true)
	# Hind feet, pear-shaped torso, lighter tummy and two little arms.
	for side in [-1,1]:
		var lift:=sin(stride+side*PI/2)*radius*(0.13 if fleeing else 0.05) if walking or fleeing else 0.0
		draw_line(Vector2(side*0.35,0.38)*radius,Vector2(side*0.44,0.82)*radius+Vector2(0,lift),color.darkened(0.25),maxf(3,radius*0.22),true)
		draw_set_transform(Vector2(shake+side*radius*0.44,radius*0.83+lift-bounce),0,Vector2(1.55,0.68))
		draw_circle(Vector2.ZERO,radius*0.24,Color("f2b6c9"))
	draw_set_transform(Vector2(shake,-bounce),0,Vector2(0.65,0.85))
	for i in 12:
		var f:=float(i)/12
		draw_circle(Vector2(-f*2,-f*3),radius*(1-f*0.55),color.darkened(0.22).lerp(color.lightened(0.18),f))
	draw_set_transform(Vector2(shake,radius*0.15-bounce),0,Vector2(0.40,0.57))
	draw_circle(Vector2.ZERO,radius,Color("f5dfd5"))
	draw_set_transform(Vector2(shake,-bounce))
	for side in [-1,1]:
		var wave:=sin(stride+side)*radius*0.10 if walking or fleeing or celebrating else sin(time*2)*radius*0.025
		draw_line(Vector2(side*0.48,-0.02)*radius,Vector2(side*0.64,0.33)*radius+Vector2(0,wave),color.darkened(0.06),maxf(3,radius*0.22),true)
		draw_circle(Vector2(side*0.64,0.33)*radius+Vector2(0,wave),radius*0.16,Color("f2b6c9"))
	# Big symmetrical ears and a soft front-facing head.
	for side in [-1,1]:
		draw_circle(Vector2(side*0.72,-1.16)*radius,radius*0.54,color.darkened(0.12))
		draw_circle(Vector2(side*0.72,-1.16)*radius,radius*0.39,Color("f4b3cd"))
		draw_circle(Vector2(side*0.76,-1.21)*radius,radius*0.22,Color("ffd3df"))
	draw_set_transform(Vector2(shake,-radius*0.60-bounce),0,Vector2(0.87,0.78))
	for i in 12:
		var f:=float(i)/12
		draw_circle(Vector2(-f*2,-f*3),radius*(1-f*0.5),color.darkened(0.16).lerp(color.lightened(0.24),f))
	draw_set_transform(Vector2(shake,-bounce))
	var blink: bool=fmod(time+origin.x*0.01,4.1)<0.13
	var gaze:=Vector2.ZERO
	if is_instance_valid(kitty): gaze=(kitty.global_position-global_position).normalized()*radius*0.055
	for side in [-1,1]:
		var eye:=Vector2(side*0.32,-0.72)*radius
		if celebrating or (blink and panic<0.2):
			draw_arc(eye,radius*0.17,PI,TAU,14,Color("312e46"),maxf(2,radius*0.07),true)
		else:
			draw_set_transform(eye+Vector2(shake,-bounce),0,Vector2(0.87,1.15+panic*0.2))
			draw_circle(Vector2.ZERO,radius*0.23,Color("fff9ef"))
			draw_circle(gaze,radius*(0.14 if panic>0.3 else 0.18),Color("35334d"))
			draw_circle(gaze+Vector2(-radius*0.05,-radius*0.07),radius*0.065,Color.WHITE)
			draw_circle(gaze+Vector2(radius*0.05,radius*0.06),radius*0.027,Color("d4e9ff"))
			draw_set_transform(Vector2(shake,-bounce))
		draw_circle(Vector2(side*0.23,-0.34)*radius,radius*0.24,Color("f7e3db"))
		draw_circle(Vector2(side*0.61,-0.39)*radius,radius*0.13,Color("e8a2b9"))
		for line in [-1,0,1]:
			draw_line(Vector2(side*0.32,-0.30)*radius,Vector2(side*1.03,-0.30+line*0.16)*radius,Color("fff7e8"),maxf(1,radius*0.045),true)
	draw_colored_polygon(PackedVector2Array([Vector2(-0.14,-0.42)*radius,Vector2(0.14,-0.42)*radius,Vector2(0,-0.25)*radius]),Color("e78caa"))
	if panic>0.35:
		draw_circle(Vector2(0,-0.10)*radius,radius*0.11,Color("795067"))
	else:
		draw_arc(Vector2(0,-0.25)*radius,radius*0.17,0,PI,16,Color("795067"),maxf(1.5,radius*0.055),true)
		if celebrating: draw_circle(Vector2(0,-0.10)*radius,radius*0.07,Color("f4a5be"))
	draw_set_transform(Vector2.ZERO)
	if celebrating:
		for i in 3:
			var point:=Vector2(cos(time*2+i*TAU/3)*radius*1.8,-radius*1.4+sin(time*2+i*TAU/3)*radius*0.6)
			draw_line(point-Vector2(3,0),point+Vector2(3,0),Color("ffe27d"),2,true)
			draw_line(point-Vector2(0,3),point+Vector2(0,3),Color("ffe27d"),2,true)
	draw_status(danger)

func draw_status(danger: bool) -> void:
	if preview_mode: return
	# A thin ground marker communicates whether Kitty is large enough.
	draw_set_transform(Vector2(0,radius*1.04),0,Vector2(1.35,0.18))
	draw_arc(Vector2.ZERO,radius,0,TAU,40,Color("ff6477") if danger else Color("95ed83"),2,true)
	draw_set_transform(Vector2.ZERO)
	if fleeing and not SaveManager.settings.get("reduce_motion",false):
		var sweat:=Vector2(radius*1.22,-radius*(0.7+fmod(time*2.5,0.6)))
		draw_circle(sweat,3.0,Color("8be8ff"))
		draw_line(sweat-Vector2(1,4),sweat+Vector2(1,1),Color("c6f9ff"),2,true)
	if not show_label: return
	var text:="ESCAPED!" if celebrating else "BIG · NEED %d"%(required_growth+1) if config.kind=="BIG" else "SMALL"
	draw_string(UI.game_font(),Vector2(-85,-radius*1.8-17),text,HORIZONTAL_ALIGNMENT_CENTER,170,20,Color("ffc0ba") if danger else Color("d9ffbc"))
	if fleeing: draw_string(UI.game_font(),Vector2(-18,-radius*1.8-40),"!!" if panic>0.55 else "!",HORIZONTAL_ALIGNMENT_CENTER,36,23,Color("ffe78a"))

func update_quality_pose() -> void:
	if eaten or not is_instance_valid(quality_sprite) or not quality_sprite.ready_art: return
	quality_sprite.show()
	var frame:=3 if celebrating else 2 if panic>0.55 else 1 if fleeing else 4 if fmod(time+origin.x*0.01,4.1)<0.13 else 0
	quality_sprite.modulate=Color.WHITE
	quality_sprite.deform_around_floor(elastic_scale,radius*0.97 if supported or preview_mode else 0.0)
	if fleeing and not SaveManager.settings.get("reduce_motion",false):
		quality_sprite.position.x+=sin(time*46)*radius*0.075*panic
		quality_sprite.position.y-=absf(sin(time*19))*radius*0.09*panic
	var lean:=sin(roll_angle)*0.18 if not SaveManager.settings.get("reduce_motion",false) else 0.0
	quality_sprite.show_pose(frame,radius*2.38,radius*0.97,false,lean)

func set_body_palette(index: int) -> void:
	palette_index=posmod(index,BODY_PALETTE.size())
	if is_instance_valid(palette_material): palette_material.set_shader_parameter("body_color",BODY_PALETTE[palette_index])
