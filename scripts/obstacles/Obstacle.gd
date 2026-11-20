extends Node2D

signal danger(body)
var config: Dictionary
var kind: String
var body: Node2D
var area: Area2D
var radius:=30.0
var elapsed:=0.0
var enabled:=true
var activated:=false
var origin:=Vector2.ZERO
var links: Dictionary={}
var bee_chase: RefCounted
var round_ended:=false
var defeated:=false
var hazard_targets: Array=[]
var uses:=0
var laser_end:=Vector2.ZERO
var laser_state:="cooldown"
const Skins=preload("res://scripts/obstacles/PropSkins.gd")

func defeat() -> void:
	if kind!="bee" or defeated: return
	defeated=true
	enabled=false
	stop_for_result()
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(self,"scale",Vector2.ZERO,0.35)
	tween.tween_property(self,"modulate:a",0.0,0.35)

func setup(data: Dictionary) -> void:
	config=data
	material=Skins.material()
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	kind=data.type
	position=Vector2(data.position[0],data.position[1])
	origin=position
	radius=float(data.get("radius",30))
	if kind=="bee": bee_chase=load("res://scripts/obstacles/BeeChase.gd").new()
	if kind=="rotating_wheel" or kind=="gate" or kind=="moving_platform":
		body=AnimatableBody2D.new()
		body.collision_layer=4
		body.collision_mask=2
		add_child(body)
		if kind=="rotating_wheel":
			for angle in [0.0,PI/2]:
				var collider:=CollisionShape2D.new()
				var box:=RectangleShape2D.new()
				box.size=Vector2(radius*2,18)
				collider.shape=box
				collider.rotation=angle
				body.add_child(collider)
		else:
			var collider:=CollisionShape2D.new()
			var box:=RectangleShape2D.new()
			box.size=Vector2(config.get("width",100),20)
			collider.shape=box
			body.add_child(collider)
	elif kind=="bomb":
		body=preload("res://scripts/obstacles/RollingBomb.gd").new()
		body.radius=radius
		add_child(body)
		body.detonated.connect(on_bomb_detonated)
	elif kind=="falling_rock":
		body=RigidBody2D.new()
		body.mass=5
		body.can_sleep=false
		body.continuous_cd=RigidBody2D.CCD_MODE_CAST_SHAPE
		body.add_to_group("terrain_loose_bodies")
		body.collision_layer=4
		body.collision_mask=1|2|4
		body.contact_monitor=true
		body.max_contacts_reported=4
		var collider:=CollisionShape2D.new()
		var circle:=CircleShape2D.new()
		circle.radius=radius
		collider.shape=circle
		body.add_child(collider)
		add_child(body)
		body.body_entered.connect(func(other):
			if other.has_method("rescue") and body.linear_velocity.length()>100: danger.emit(other))
		var art:=Node2D.new()
		art.set_script(load("res://scripts/obstacles/RockVisual.gd"))
		art.radius=radius
		body.add_child(art)
	if kind not in ["rotating_wheel","gate","moving_platform","falling_rock","laser","bomb"]:
		area=Area2D.new()
		area.collision_layer=0
		area.collision_mask=6
		var collider:=CollisionShape2D.new()
		var circle:=CircleShape2D.new()
		circle.radius=radius
		collider.shape=circle
		area.add_child(collider)
		add_child(area)
		area.body_entered.connect(on_enter)

func activate() -> void:
	activated=true
	enabled=false
	if kind in ["gate","moving_platform"]:
		for collider in body.get_children():
			if collider is CollisionShape2D: collider.set_deferred("disabled",true)
	queue_redraw()

func configure_chase(kittens: Array,terrain: Node2D,mother: Node2D=null) -> void:
	hazard_targets=kittens
	if kind=="bomb": body.terrain=terrain
	if bee_chase:
		bee_chase.kittens=kittens
		bee_chase.terrain=terrain
		bee_chase.mother=mother

func on_bomb_detonated(point: Vector2) -> void:
	if activated or round_ended: return
	activated=true
	uses=1
	enabled=false
	get_parent().call_deferred("detonate_world_bomb",point,float(config.get("blast_radius",145)))

func stop_for_result() -> void:
	round_ended=true
	if bee_chase:
		bee_chase.target=null
		bee_chase.state="rest"
		bee_chase.velocity=Vector2.ZERO
	if body is RigidBody2D: body.set_deferred("freeze",true)
	if area: area.set_deferred("monitoring",false)

func on_enter(other: Node2D) -> void:
	if kind=="bee" and enabled and other is RigidBody2D and other.collision_layer==4:
		if other.linear_velocity.length()>55: defeat()
		return
	if kind=="pressure_switch":
		if config.get("rocks_only",false) and other.collision_layer!=4: return
		activate()
		if links.has(config.get("target","")): links[config.target].activate()
		for target_id in config.get("targets",[]):
			if links.has(target_id): links[target_id].activate()
	elif other.has_method("rescue") and not other.rescued:
		if kind in ["bee","spikes","dangerous_plant"] and enabled: danger.emit(other)
		elif kind=="portal" and other.portal_cooldown<=0 and links.has(config.get("linked_to","")):
			if config.get("exit_only",false) or int(other.get_meta("growth",0))<int(config.get("required_growth",0)): return
			uses+=1
			other.portal_cooldown=0.9
			var destination: Vector2=links[config.linked_to].global_position+Vector2(0,other.radius+links[config.linked_to].radius+8)
			call_deferred("perform_teleport",other,destination)

func perform_teleport(other: RigidBody2D,destination: Vector2) -> void:
	if not is_instance_valid(other) or other.rescued: return
	other.freeze=true
	other.global_position=destination
	other.linear_velocity=Vector2.ZERO
	other.angular_velocity=0.0
	other.reset_physics_interpolation()
	await get_tree().physics_frame
	if is_instance_valid(other) and not other.rescued: other.freeze=false

func _physics_process(delta: float) -> void:
	if round_ended: return
	elapsed+=delta
	if kind=="laser": update_laser()
	if kind=="portal" and config.get("wait_for_growth",false) and area:
		for other in area.get_overlapping_bodies():
			if other.has_method("rescue") and not other.rescued: on_enter(other)
	if kind=="rotating_wheel" and enabled:
		body.rotation+=delta*float(config.get("speed",0.6))*(-1 if config.get("direction","")=="counterclockwise" else 1)
	if kind=="bee": bee_chase.update(self,delta)
	if kind=="dangerous_plant" and not activated: enabled=fmod(elapsed,4.0)<2.3
	if kind=="dangerous_plant" and enabled and area:
		for other in area.get_overlapping_bodies():
			if other.has_method("rescue") and not other.rescued: danger.emit(other)
	if kind=="moving_platform" and enabled: body.position=Vector2(sin(elapsed*float(config.get("speed",1.0)))*float(config.get("distance",70)),0)
	if area and kind in ["fan","water"] and enabled:
		for other in area.get_overlapping_bodies():
			if other is RigidBody2D:
				if other.has_method("rescue"): uses+=1
				if kind=="fan": other.apply_central_force(Vector2(config.get("force_x",150),config.get("force_y",-1100)))
				else: other.apply_central_force(-other.linear_velocity*4+Vector2(config.get("current",0),-other.mass*800))
	queue_redraw()

func update_laser() -> void:
	var direction:=Vector2(config.get("direction",[1,0])[0],config.get("direction",[1,0])[1]).normalized()
	var destination:=global_position+direction*float(config.get("length",600))
	var query:=PhysicsRayQueryParameters2D.create(global_position,destination,1|4)
	var hit:=get_world_2d().direct_space_state.intersect_ray(query)
	laser_end=to_local(hit.position if not hit.is_empty() else destination)
	if not enabled:
		laser_state="disabled"
		return
	var warning:=float(config.get("warning_seconds",1.5))
	var firing:=float(config.get("active_seconds",1.0))
	var cooldown:=float(config.get("cooldown_seconds",3.0))
	var phase:=fposmod(elapsed+float(config.get("phase_offset",0)),warning+firing+cooldown)
	laser_state="warning" if phase<warning else "active" if phase<warning+firing else "cooldown"
	if laser_state!="active": return
	for target in hazard_targets:
		if not is_instance_valid(target) or target.rescued: continue
		var nearest:=Geometry2D.get_closest_point_to_segment(target.global_position,global_position,to_global(laser_end))
		if nearest.distance_to(target.global_position)<=target.radius+float(config.get("beam_width",8))/2:
			danger.emit(target)

func _draw() -> void:
	if kind in ["falling_rock","bomb"]: return
	if kind=="laser":
		var emitter:=Skins.atlas_texture("mechanisms-v2",4)
		var face_left: bool=config.get("direction",[1,0])[0]<0
		draw_set_transform(Vector2.ZERO,0,Vector2(-1 if face_left else 1,1))
		draw_texture_rect(emitter,Skins.fit(emitter,Rect2(-26,-24,52,48)),false)
		draw_set_transform(Vector2.ZERO)
		if laser_state=="disabled": draw_circle(Vector2(-17 if face_left else 17,0),5,Color("6cdaac"))
		if laser_state=="warning":
			draw_dashed_line(Vector2.ZERO,laser_end,Color("ffe078"),3,12)
		elif laser_state=="active":
			draw_line(Vector2.ZERO,laser_end,Color(1,0.15,0.25,0.2),22,true)
			draw_line(Vector2.ZERO,laser_end,Color("ff456b"),float(config.get("beam_width",8)),true)
			draw_line(Vector2.ZERO,laser_end,Color("fff4e3"),2,true)
		return
	if kind=="rotating_wheel":
		draw_circle(Vector2(3,7),radius+12,Color(0.13,0.15,0.17,0.4))
		draw_circle(Vector2.ZERO,radius+8,Color("135475"))
		for i in 18:
			var f:=float(i)/18
			draw_circle(Vector2(-f*6,-f*7),radius+4-f*radius*0.6,Color("1a80b5").lerp(Color("4fbaec"),f))
		draw_arc(Vector2.ZERO,radius+4,PI*1.02,TAU,48,Color("a1d9ed"),2,true)
	if kind in ["bee","spikes","dangerous_plant","pressure_switch","rotating_wheel"]:
		var index: int={"bee":0,"dangerous_plant":2,"spikes":3,"pressure_switch":4,"rotating_wheel":5}[kind]
		var skin:=Skins.atlas_texture("props-v2",index)
		if kind=="rotating_wheel": draw_set_transform(Vector2.ZERO,body.rotation)
		if kind=="bee": draw_set_transform(Vector2.ZERO,bee_chase.tilt,Vector2(bee_chase.facing,1))
		if activated: draw_set_transform(Vector2.ZERO,0,Vector2(1,0.65))
		var size_factor:=1.5 if kind=="bee" else 1.18
		draw_texture_rect(skin,Skins.fit(skin,Rect2(-radius*size_factor,-radius*size_factor,radius*2*size_factor,radius*2*size_factor)),false,Color.WHITE if enabled else Color(0.65,0.8,0.65))
		draw_set_transform(Vector2.ZERO)
		return
	if kind=="rotating_wheel":
		draw_circle(Vector2.ZERO,radius+6,Color("176c90"))
		for angle in [body.rotation,body.rotation+PI/2]:
			var points:=PackedVector2Array()
			for p in [Vector2(-radius,-10),Vector2(radius,-10),Vector2(radius,10),Vector2(-radius,10)]: points.append(p.rotated(angle))
			draw_colored_polygon(points,Color("d38326"))
			draw_line(Vector2(-radius+8,-5).rotated(angle),Vector2(radius-8,-5).rotated(angle),Color("ffd878"),3,true)
		draw_circle(Vector2.ZERO,17,Color("767d89"))
		draw_circle(Vector2(-2,-3),10,Color("dbe9e9"))
	elif kind=="bee":
		for side in [-1,1]: draw_circle(Vector2(side*12,-17),15,Color(0.85,0.96,1,0.8))
		draw_circle(Vector2.ZERO,23,Color("f8c43e"))
		for x in [-8,4]: draw_line(Vector2(x,-19),Vector2(x,19),Color("3c2c37"),7)
		draw_circle(Vector2(16,-5),7,Color.WHITE)
		draw_circle(Vector2(19,-5),3,Color("272836"))
	elif kind=="spikes":
		for x in [-24,0,24]: draw_colored_polygon(PackedVector2Array([Vector2(x-10,15),Vector2(x,-20),Vector2(x+10,15)]),Color("e1e6ed"))
	elif kind=="dangerous_plant":
		draw_line(Vector2(0,30),Vector2.ZERO,Color("58a845"),13)
		draw_circle(Vector2.ZERO,29,Color("ca4288") if enabled else Color("7eae53"))
		if enabled: draw_arc(Vector2.ZERO,20,0,PI,12,Color("fff3d9"),7)
	elif kind=="gate" or kind=="moving_platform":
		if not activated:
			var width: float=config.get("width",100)
			Skins.draw_bar(self,5 if kind=="moving_platform" else 0,Rect2(body.position-Vector2(width/2,14),Vector2(width,28)))
	elif kind=="pressure_switch":
		draw_circle(Vector2.ZERO,22,Color("5ba764") if activated else Color("ec616c"))
		draw_arc(Vector2.ZERO,17,PI,TAU,15,Color("ffd7ca"),4)
	elif kind=="portal":
		var portal:=Skins.atlas_texture("mechanisms-v2",1)
		draw_texture_rect(portal,Skins.fit(portal,Rect2(-radius*1.2,-radius*1.2,radius*2.4,radius*2.4)),false)
	elif kind=="fan":
		var rotor:=Skins.atlas_texture("mechanisms-v2",2)
		draw_set_transform(Vector2.ZERO,elapsed*4.0)
		draw_texture_rect(rotor,Skins.fit(rotor,Rect2(-radius,-radius,radius*2,radius*2)),false)
		draw_set_transform(Vector2.ZERO)
	elif kind=="water":
		var water:=Skins.atlas_texture("mechanisms-v2",3)
		draw_texture_rect(water,Rect2(-radius,-radius,radius*2,radius*2),false,Color(1,1,1,0.85))

func make_box(color: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=color
	box.set_corner_radius_all(6)
	return box

