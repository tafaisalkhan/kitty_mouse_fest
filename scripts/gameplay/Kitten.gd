extends RigidBody2D

signal lost(kitten)
var rescued := false
var radius := 22.0
var max_speed := 620.0
var visual: Node2D
var portal_cooldown := 0.0
var family_target:=Vector2.ZERO
var muted:=false
var loss_y:=1270.0
var supported:=true
var support_grace:=0.0
var previous_fall_speed:=0.0
var max_side_speed:=0.0

func configure(data: Dictionary) -> void:
	can_sleep=false
	add_to_group("terrain_loose_bodies")
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	position = Vector2(data.position[0],data.position[1])
	radius = float(data.get("radius",22))
	mass = float(data.get("mass",1.0))
	gravity_scale = float(data.get("gravity_scale",1.0))
	linear_damp = float(data.get("linear_damping",0.25))
	angular_damp = float(data.get("angular_damping",0.4))
	max_speed = float(data.get("maximum_speed",620))
	var material := PhysicsMaterial.new()
	material.bounce = float(data.get("bounce",0.12))
	material.friction = float(data.get("friction",0.65))
	physics_material_override = material
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	contact_monitor = true
	max_contacts_reported = 6
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	visual = load("res://scripts/gameplay/CatVisual.gd").new()
	visual.radius = radius
	visual.mother = bool(data.get("mother",false))
	var variant_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var selected=data.get("variant",0)
	visual.variant = maxi(0,variant_data.variants.find(selected)) if selected is String else int(selected)
	add_child(visual)
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body_entered.connect(func(_other):
		if linear_velocity.length()>90:
			if not muted: AudioManager.play_fx("bounce")
			visual.react_collision(linear_velocity.length()))

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(max_speed)
	if max_side_speed>0: state.linear_velocity.x=clampf(state.linear_velocity.x,-max_side_speed,max_side_speed)
	var contact_below:=false
	for i in state.get_contact_count():
		# "Local" identifies this body, not a rotated coordinate basis.
		var normal:=state.get_contact_local_normal(i)
		if normal.y<-0.45: contact_below=true
	support_grace=0.06 if contact_below else maxf(0,support_grace-state.step)
	var now_supported:=support_grace>0
	if now_supported and not supported and previous_fall_speed>100:
		visual.react_collision(previous_fall_speed)
		if not muted: AudioManager.play_fx("bounce")
	supported=now_supported
	previous_fall_speed=0.0 if supported else maxf(previous_fall_speed,state.linear_velocity.y)

func _physics_process(delta: float) -> void:
	portal_cooldown = maxf(0,portal_cooldown-delta)
	if visual:
		visual.set_physics_motion(linear_velocity,supported)
	if position.y > loss_y and not rescued:
		lost.emit(self)

func rescue() -> void:
	if rescued: return
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	rescued = true
	visual.celebrate()
	set_physics_process(false)
	set_deferred("freeze",true)
	set_deferred("linear_velocity",Vector2.ZERO)
	set_deferred("angular_velocity",0.0)
	set_deferred("collision_layer",0)
	set_deferred("collision_mask",0)

func join_family(target: Vector2) -> void:
	if not rescued: rescue()
	family_target=target
	z_index=2
	show()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self,"position",target,0.6)
	tween.tween_property(self,"rotation",0.0,0.4)
	tween.tween_property(self,"scale",Vector2.ONE*0.95,0.4)
	tween.chain().tween_callback(visual.celebrate)

