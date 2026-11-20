extends Node2D

var variant := 0
var radius := 24.0
var mother := false
var expression := "idle"
var time := 0.0
var atlas: Texture2D
var mom_texture: Texture2D
var art: Sprite2D
var face_material: ShaderMaterial
var art_scale:=Vector2.ONE
var rng:=RandomNumberGenerator.new()
var idle_phase:=0.0
var blink_wait:=2.0
var blink_age:=-1.0
var blink_amount:=0.0
var blink_count:=0
var blink_override:=-1.0
var ear_wait:=2.0
var ear_age:=-1.0
var impact:=0.0
var celebration:=0.0
var surprise_amount:=0.0
var gaze:=Vector2.ZERO
var gaze_target:=Vector2.ZERO
var motion:=Vector2.ZERO
var attention_timer:=0.0
var glance_wait:=0.0
var defeated:=false
var crying:=false
var sparkle_time:=0.0
var attention_kind:="idle"
var attention_strength:=0.0
var supported:=true
var landing_time:=0.0
var fear_amount:=0.0
var action_body:=false
var curl_amount:=0.0
var locomotion_state:="standing"
var walk_phase:=0.0
var eating_time:=0.0
var can_stand:=true
var facing:=1.0
var quality_sprite: Node2D
var eating_sprite: Node2D
var quality_effects: Node2D
var ball_style:=true
var elasticity=preload("res://scripts/gameplay/BallElasticity.gd").new()
var elastic_scale:=Vector2.ONE
var ball_face_material: ShaderMaterial
var body_lean:=0.0
var food_interest:=0.0
var food_excitement:=0.0
var ball_spin=preload("res://scripts/gameplay/BallSpin.gd").new()

func react_eat() -> void:
	var velocity:=motion
	var grounded:=supported
	eating_time=1.5
	celebrate()
	sparkle_time=maxf(sparkle_time,2.0)
	motion=velocity
	supported=grounded
	if action_body: update_quality_pose()

func get_eating_stage() -> String:
	return "idle" if eating_time<=0 else "mouth_open" if eating_time>1.25 else "chewing" if eating_time>0.9 else "tongue_lick"

func mouth_world_position() -> Vector2:
	if mother and ball_style and has_quality_art():
		return quality_sprite.frame_point_world(quality_sprite.cell_size*Vector2(0.5,0.64))
	var curled:=is_curled_pose()
	if is_instance_valid(eating_sprite) and eating_sprite.ready_art and eating_time>0:
		var point: Vector2=eating_sprite.cell_size*Vector2(0.56,0.58) if curled else eating_sprite.cell_size*Vector2(0.80,0.66)
		return eating_sprite.frame_point_world(point)
	return to_global(Vector2(0 if curled else facing*radius*0.65,-radius*(0.16 if curled else 0.65)))

func is_curled_pose() -> bool:
	if mother and ball_style: return true
	return curl_amount>0.65 or not can_stand or (not supported and absf(motion.y)>65)

func focus_on(world_point: Vector2,kind: String,strength:=1.0) -> void:
	if defeated or crying: return
	var travel:=1.55 if mother and ball_style else 1.0
	gaze_target=to_local(world_point).normalized()*Vector2(0.060,0.050)*travel
	attention_timer=0.32
	attention_kind=kind
	attention_strength=strength

func set_physics_motion(velocity: Vector2,on_ground: bool) -> void:
	supported=on_ground
	set_motion(velocity)

func cry() -> void:
	if defeated: return
	crying=true
	expression="crying"
	celebration=0.0
	sparkle_time=0.0
	motion=Vector2.ZERO
	supported=true
	attention_timer=0.0
	attention_kind="idle"
	if face_material:
		face_material.set_shader_parameter("crying",true)
		face_material.set_shader_parameter("sparkle",0.0)
	if action_body: update_quality_pose()

func defeat() -> void:
	defeated=true
	crying=false
	sparkle_time=0.0
	expression="defeated"
	celebration=0.0
	if art:
		art.scale=art_scale
		art.position=Vector2(0,-radius*0.2)
		if action_body:
			art.scale*=lerpf(0.68,0.91,curl_amount)
			art.position.y=lerpf(-radius*0.58,-radius*0.13,curl_amount)
		art.rotation=0.0
		face_material.set_shader_parameter("defeated",true)
		face_material.set_shader_parameter("crying",false)
		face_material.set_shader_parameter("sparkle",0.0)
	if action_body: update_quality_pose()
	queue_redraw()

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	if mother:
		elasticity.spring_stiffness=180.0
		elasticity.spring_damping=13.0
		elasticity.air_stretch=0.12
		elasticity.impact_compression=0.32
	if ResourceLoader.exists("res://assets/cats/kitten_heads.png"):
		atlas = load("res://assets/cats/kitten_heads.png")
	if ResourceLoader.exists("res://assets/cats/mother_head.png"):
		mom_texture = load("res://assets/cats/mother_head.png")
	rng.seed=get_instance_id()+variant*911
	idle_phase=rng.randf_range(0,TAU)
	blink_wait=rng.randf_range(0.8,2.6)
	ear_wait=rng.randf_range(1.0,3.7)
	build_art()

func build_art() -> void:
	var texture: Texture2D=mom_texture if mother else atlas
	if texture==null: return
	art=Sprite2D.new()
	art.texture=texture
	if not mother:
		art.hframes=3
		art.vframes=2
		art.frame=clampi(variant,0,5)
	var frame_size:=texture.get_size()/(Vector2.ONE if mother else Vector2(3,2))
	art_scale=Vector2(radius*2.4/frame_size.x,radius*2.4/frame_size.y)
	art.scale=art_scale
	art.position=Vector2(0,-radius*0.2)
	face_material=ShaderMaterial.new()
	face_material.shader=load("res://assets/cats/living_face.gdshader")
	face_material.set_shader_parameter("tile",Vector4(0,0,1,1) if mother else Vector4(float(variant%3)/3,float(variant/3)/2,1.0/3,0.5))
	var eye_y:=0.50 if mother or variant<3 else 0.52
	face_material.set_shader_parameter("left_eye",Vector2(0.31 if mother else 0.30,eye_y))
	face_material.set_shader_parameter("right_eye",Vector2(0.69 if mother else 0.70,eye_y))
	var closed_path:="res://assets/cats/mother_blink.png" if mother else "res://assets/cats/kitten_blink.png"
	if ResourceLoader.exists(closed_path):
		face_material.set_shader_parameter("closed_texture",load(closed_path))
		face_material.set_shader_parameter("has_closed_texture",true)
	art.material=face_material
	add_child(art)
	if mother:
		quality_sprite=preload("res://scripts/gameplay/QualitySprite.gd").new()
		add_child(quality_sprite)
		quality_sprite.configure("res://assets/characters/cat-ball-white.png",3,2)
		ball_face_material=ShaderMaterial.new()
		ball_face_material.shader=preload("res://assets/characters/cat_ball_face.gdshader")
		ball_face_material.set_shader_parameter("eye_enlargement",0.06)
		quality_sprite.set_atlas_material(ball_face_material)
		quality_sprite.hide()
		eating_sprite=preload("res://scripts/gameplay/QualitySprite.gd").new()
		add_child(eating_sprite)
		eating_sprite.hide()
		quality_effects=Node2D.new()
		add_child(quality_effects)
		quality_effects.draw.connect(draw_quality_effects)

func look_toward(world_point: Vector2) -> void:
	if defeated or crying: return
	gaze_target=to_local(world_point).normalized()*0.035
	attention_timer=0.4

func react_collision(speed: float) -> void:
	if defeated or crying: return
	if mother and ball_style: elasticity.land(speed)
	impact=maxf(impact,clampf(speed/420.0,0.0,1.0))
	if speed>100: landing_time=0.28

func celebrate() -> void:
	if defeated: return
	crying=false
	sparkle_time=3.5
	fear_amount=0.0
	surprise_amount=0.0
	motion=Vector2.ZERO
	supported=true
	attention_kind="idle"
	attention_timer=0.0
	if face_material: face_material.set_shader_parameter("crying",false)
	celebration=1.35
	expression="happy"
	blink_wait=0.06

func set_motion(velocity: Vector2) -> void:
	if defeated or crying: return
	motion=velocity
	if velocity.length()>80 and attention_timer<=0:
		gaze_target=velocity.rotated(-global_rotation).normalized()*0.035

func _process(delta: float) -> void:
	time += delta
	advance_animation(delta)
	queue_redraw()

func advance_animation(delta: float) -> void:
	if defeated: return
	var reduce_motion: bool=SaveManager.settings.get("reduce_motion",false)
	if mother and ball_style:
		elastic_scale=elasticity.advance(delta,motion.y,supported,reduce_motion)
		var target_lean:=clampf(motion.x*0.0007,-0.075,0.075) if not reduce_motion else 0.0
		body_lean=lerpf(body_lean,target_lean,1-exp(-delta*6))
	if action_body or (mother and ball_style):
		var airborne:=not supported and absf(motion.y)>65
		var must_curl:=ball_style or airborne or not can_stand
		curl_amount=move_toward(curl_amount,1.0 if must_curl else 0.0,delta*(6 if must_curl else 9))
		eating_time=maxf(0,eating_time-delta)
		walk_phase+=absf(motion.x)/maxf(radius,1)*delta*2.2
		locomotion_state="eating" if eating_time>0 else "curled" if must_curl else "landing" if landing_time>0 else "walking" if absf(motion.x)>12 else "watching_mouse" if attention_timer>0 and attention_kind=="object" else "standing"
		var parent_angle: float=get_parent().rotation if get_parent() is Node2D else 0.0
		if ball_style:
			rotation=-parent_angle+ball_spin.advance(delta,motion,supported,reduce_motion)
		else:
			var upright:=lerp_angle(-parent_angle,0.0,curl_amount)
			rotation=lerp_angle(rotation,upright,1-exp(-delta*18))
		if absf(motion.x)>5: facing=signf(motion.x)
	landing_time=maxf(0,landing_time-delta)
	var attentive:=attention_timer>0
	var danger: float=attention_strength if attentive and attention_kind=="danger" and celebration<=0 and not crying else 0.0
	fear_amount=lerpf(fear_amount,danger,1-exp(-delta*10))
	if not crying:
		if celebration>0: expression="happy"
		elif landing_time>0: expression="landing"
		elif danger>0.25: expression="scared"
		elif not supported and motion.y>55: expression="falling"
		elif attentive and attention_kind in ["dig","object"]: expression="curious"
		elif attentive and attention_kind=="mom": expression="hopeful"
		elif absf(motion.x)>45: expression="rolling"
		else: expression="idle"
	blink_wait-=delta
	if blink_age<0 and blink_wait<=0:
		blink_age=0.0
		blink_count+=1
	if blink_age>=0:
		blink_age+=delta
		if blink_age<0.075: blink_amount=smoothstep(0.0,0.075,blink_age)
		elif blink_age<0.135: blink_amount=1.0
		elif blink_age<0.27: blink_amount=1.0-smoothstep(0.135,0.27,blink_age)
		else:
			blink_age=-1.0
			blink_amount=0.0
			blink_wait=rng.randf_range(2.0,4.8) if celebration<=0 else 0.22
	if blink_override>=0: blink_amount=blink_override
	ear_wait-=delta
	if ear_age<0 and ear_wait<=0: ear_age=0.0
	var twitch:=0.0
	if ear_age>=0:
		ear_age+=delta
		twitch=sin(ear_age*30.0)*exp(-ear_age*7.0)
		if ear_age>0.6:
			ear_age=-1.0
			ear_wait=rng.randf_range(2.8,6.0)
	impact=move_toward(impact,0.0,delta*5.0)
	celebration=maxf(0.0,celebration-delta)
	var surprise_target:=maxf(fear_amount,clampf(motion.y/420.0,0.35,1.0) if expression=="falling" else 0.0)
	surprise_amount=lerpf(surprise_amount,surprise_target,1.0-exp(-delta*9.0))
	attention_timer-=delta
	glance_wait-=delta
	if attention_timer<=0:
		if not mother and motion.length()>80:
			gaze_target=motion.rotated(-global_rotation).normalized()*0.035
		elif mother:
			gaze_target=Vector2(sin(time*0.62+idle_phase)*0.012,cos(time*0.43)*0.005)
		elif glance_wait<=0:
			gaze_target=Vector2(rng.randf_range(-0.014,0.014),rng.randf_range(-0.006,0.008))
			glance_wait=rng.randf_range(1.1,2.8)
	food_excitement=lerpf(food_excitement,food_interest,1-exp(-delta*8))
	gaze=gaze.lerp(gaze_target,1.0-exp(-delta*11.0))
	if art:
		var breath:=sin(time*2.6+idle_phase)*(0.0 if reduce_motion else 0.018)
		var bounce:=absf(sin(celebration*13.0))*celebration if not reduce_motion else 0.0
		var stretch:=clampf(motion.y/620.0,0,1) if not supported else 0.0
		if reduce_motion: stretch=0
		var squash:=Vector2(1.0+breath+impact*0.20-stretch*0.10,1.0-breath-impact*0.16+stretch*0.16)
		art.scale=art_scale*squash
		art.position=Vector2(0,-radius*0.2-radius*bounce*0.10)
		if action_body:
			var chew:=sin(eating_time*38)*eating_time*0.06
			art.scale*=lerpf(0.68,0.91,curl_amount)
			art.scale*=Vector2(1+chew,1-chew)
			art.position.y=lerpf(-radius*0.58,-radius*0.13,curl_amount)-radius*bounce*0.08
		art.rotation=0.0 if reduce_motion else sin(time*1.3+idle_phase)*0.019+sin(celebration*17)*celebration*0.025
		face_material.set_shader_parameter("blink",maxf(blink_amount,landing_time/0.28*0.75))
		face_material.set_shader_parameter("gaze",gaze)
		face_material.set_shader_parameter("ear_twitch",0.0 if reduce_motion else twitch)
		face_material.set_shader_parameter("surprise",surprise_amount)
		face_material.set_shader_parameter("fear",fear_amount)
		face_material.set_shader_parameter("curious",1.0 if expression=="curious" else 0.0)
		face_material.set_shader_parameter("landing",clampf(landing_time/0.28,0,1))
		face_material.set_shader_parameter("smile_motion",sin(time*3+idle_phase))
		sparkle_time=maxf(0,sparkle_time-delta)
		face_material.set_shader_parameter("sparkle",minf(1,sparkle_time))
		face_material.set_shader_parameter("emotion_time",time if not reduce_motion else 0.4)
		if crying:
			art.rotation=0.04+sin(time*12)*0.012 if not reduce_motion else 0.04
			face_material.set_shader_parameter("blink",0.25)
	if action_body or (mother and ball_style): update_quality_pose()

func _draw() -> void:
	var colors := [Color("9ba8b8"),Color("ed9e46"),Color("fff2d5"),Color("586374"),Color("edce99"),Color("a97149")]
	var r := radius
	if action_body and has_quality_art():
		if supported:
			draw_set_transform(Vector2(2,r*0.97).rotated(-global_rotation),-global_rotation,Vector2(1.1,0.16))
			draw_circle(Vector2.ZERO,r*0.9,Color(0.16,0.09,0.08,0.20))
			draw_set_transform(Vector2.ZERO)
	else: draw_circle(Vector2(2, 3), r * 0.95, Color(0.16,0.09,0.08,0.24))
	if action_body and not has_quality_art(): draw_action_body()
	if art: return
	var base: Color = Color("fff0d5") if mother else colors[variant % 6]
	for side in [-1,1]:
		var ear := PackedVector2Array([Vector2(side*r*0.85,-r*0.25),Vector2(side*r*0.68,-r*1.25),Vector2(side*r*0.12,-r*0.68)])
		draw_colored_polygon(ear, base.darkened(0.15))
		draw_circle(Vector2(side*r*0.57,-r*0.72),r*0.18,Color("ed9b9e"))
	for step in range(22):
		var f := float(step)/22.0
		draw_circle(Vector2(-f*r*0.12,-f*r*0.16),r*(1.0-f*0.72),base.darkened(0.27).lerp(base.lightened(0.16),f))
	var blink := fmod(time,4.2)>4.05
	for side in [-1,1]:
		var eye := Vector2(side*r*0.37,-r*0.12)
		draw_circle(eye,r*0.25,Color("fff9e8"))
		if blink:
			draw_line(eye-Vector2(r*0.17,0),eye+Vector2(r*0.17,0),Color("433126"),3)
		else:
			draw_circle(eye+Vector2(0,2),r*0.18,Color("71412c"))
			draw_circle(eye+Vector2(0,3),r*0.12,Color("201b2c"))
			draw_circle(eye+Vector2(-r*0.06,-r*0.06),r*0.065,Color.WHITE)
		for j in range(3):
			draw_line(Vector2(side*r*0.46,r*(0.28+j*0.08)),Vector2(side*r*0.91,r*(0.19+j*0.18)),Color("67564c"),1.3,true)
	draw_circle(Vector2(0,r*0.2),r*0.105,Color("e8859b"))
	draw_arc(Vector2(0,r*0.31),r*0.14,0.1,PI-0.1,12,Color("71412c"),2,true)
	if mother or variant == 1:
		for side in [-1,1]:
			draw_circle(Vector2(side*r*0.22,-r*0.87),r*0.22,Color("e95899"))
		draw_circle(Vector2(0,-r*0.87),r*0.12,Color("ffb1d0"))


func draw_action_body() -> void:
	var r:=radius
	var open:=1.0-curl_amount
	var fur:=Color("fff0d6")
	if defeated: fur=fur.darkened(0.45)
	var wag:=sin(time*3.4)*0.15
	# The tail wraps around the ball in flight and opens behind the standing cat.
	var tail:=PackedVector2Array()
	for i in 25:
		var t:=float(i)/24
		var standing:=Vector2(0.45+sin(t*PI*0.7)*0.85,0.45-t*1.35+sin(t*PI)*wag)*r
		var angle:=lerpf(PI*0.32,PI*1.88,t)
		var wrapped:=Vector2(cos(angle),sin(angle))*r*0.91
		tail.append(standing.lerp(wrapped,curl_amount))
	draw_polyline(tail,fur.darkened(0.20),maxf(4,r*0.25),true)
	draw_polyline(tail,fur.lightened(0.08),maxf(3,r*0.17),true)
	# Rear paws and four short legs are separate from the head artwork.
	var moving:=supported and absf(motion.x)>12
	for pair in 2:
		for side in [-1,1]:
			var phase: float=walk_phase+side*PI/2+pair*PI
			var step: float=sin(phase)*r*0.12 if moving else 0.0
			var x: float=side*(0.60 if pair==0 else 0.30)
			var foot:=Vector2(x*r,(0.68+pair*0.15)*r+step)
			var tucked:=Vector2(side*r*0.55,r*0.30)
			foot=foot.lerp(tucked,curl_amount)
			if eating_time>0 and pair==1: foot.y-=r*0.38*open
			draw_line(Vector2(side*r*0.4,r*0.22),foot,fur.darkened(0.13),maxf(4,r*0.25),true)
			draw_set_transform(foot,0,Vector2(1.25,0.7))
			draw_circle(Vector2.ZERO,r*0.21,fur)
			draw_circle(Vector2(0,r*0.025),r*0.11,Color("edb3b9").darkened(0.4 if defeated else 0))
	draw_set_transform(Vector2(0,r*0.10*open),0,Vector2(lerpf(0.66,0.97,curl_amount),lerpf(0.60,0.97,curl_amount)))
	for i in 14:
		var f:=float(i)/14
		draw_circle(Vector2(-f*r*0.13,-f*r*0.13),r*(1-f*0.55),fur.darkened(0.21).lerp(fur.lightened(0.05),f))
	if open>0.05:
		draw_set_transform(Vector2(0,r*0.23),0,Vector2(0.40*open,0.53*open))
		draw_circle(Vector2.ZERO,r,fur.lightened(0.18))
	draw_set_transform(Vector2.ZERO)
	if curl_amount>0.25 and not defeated:
		# Motion strokes communicate an elastic roll, not a second collider.
		var a:=time*7
		draw_arc(Vector2.ZERO,r*1.09,a,a+1.1,24,Color(1,0.87,0.55,curl_amount*0.7),maxf(1,r*0.055),true)
		draw_arc(Vector2.ZERO,r*1.09,a+PI,a+PI+0.65,20,Color(1,0.98,0.85,curl_amount*0.6),maxf(1,r*0.04),true)

func has_quality_art() -> bool:
	return is_instance_valid(quality_sprite) and quality_sprite.ready_art

func update_quality_pose() -> void:
	if not has_quality_art(): return
	if art: art.hide()
	if ball_style:
		if is_instance_valid(eating_sprite): eating_sprite.hide()
		quality_sprite.show()
		var frame:=5 if defeated else 4 if celebration>0.1 or food_excitement>0.55 else 0
		if eating_time>0 and not defeated:
			frame=1 if get_eating_stage()=="mouth_open" else 2 if get_eating_stage()=="chewing" else 3
		quality_sprite.deform_around_floor(elastic_scale,radius*0.96 if supported else 0.0)
		quality_sprite.show_pose(frame,radius*2.34,radius*0.96,false,body_lean)
		ball_face_material.set_shader_parameter("eye_gaze",gaze)
		ball_face_material.set_shader_parameter("eye_enlargement",0.06+food_excitement*0.10)
		if is_instance_valid(quality_effects): quality_effects.queue_redraw()
		return
	var curled:=is_curled_pose()
	var flip:=facing<0
	if eating_time>0 and not defeated and is_instance_valid(eating_sprite) and eating_sprite.ready_art:
		quality_sprite.hide()
		eating_sprite.show()
		var stage:=0 if get_eating_stage()=="mouth_open" else 1 if get_eating_stage()=="chewing" else 2
		eating_sprite.show_pose(stage+(3 if curled else 0),radius*(2.05 if curled else 2.6),radius*0.96,flip)
	elif curled and not defeated and is_instance_valid(eating_sprite) and eating_sprite.ready_art:
		quality_sprite.hide()
		eating_sprite.show()
		eating_sprite.show_pose(4,radius*2.05,radius*0.96,false)
	else:
		if is_instance_valid(eating_sprite): eating_sprite.hide()
		quality_sprite.show()
		var frame:=4
		if defeated: frame=9 if curled else 10
		elif curled: frame=8
		elif eating_time>0: frame=6
		elif landing_time>0.03: frame=7
		elif supported and absf(motion.x)>12:
			frame=5 if fmod(time+idle_phase,5.8)>5.2 else int(walk_phase*2.7)%4
		elif celebration>0.1: frame=11
		var squash:=1.0-minf(0.13,impact*0.13) if not curled else 1.0
		quality_sprite.show_pose(frame,radius*(2.05 if curled else 2.6)*squash,radius*0.96,flip)
		quality_sprite.modulate=Color("a6a29d") if defeated else Color.WHITE
	if is_instance_valid(quality_effects): quality_effects.queue_redraw()

func draw_quality_effects() -> void:
	if not has_quality_art() or defeated or sparkle_time<=0: return
	if eating_time>0 and get_eating_stage()!="tongue_lick": return
	var brightness:=minf(1,sparkle_time)
	var curled:=is_curled_pose()
	var head:=Vector2(0 if curled else facing*radius*0.45,-radius*(0.3 if curled else 1.0))
	for side in [-1,1]:
		var point:=head+Vector2(side*radius*0.38,sin(time*6+side)*radius*0.04)
		var length: float=radius*0.10*(0.75+sin(time*9+side)*0.25)
		quality_effects.draw_line(point-Vector2(length,0),point+Vector2(length,0),Color(1,0.98,0.80,brightness),maxf(1,radius*0.04),true)
		quality_effects.draw_line(point-Vector2(0,length),point+Vector2(0,length),Color(1,1,1,brightness),maxf(1,radius*0.04),true)
