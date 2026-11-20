extends RigidBody2D
signal detonated(point: Vector2)
var terrain: Node2D
var radius:=25.0
var start_y:=0.0
var released:=false
var exploded:=false
var age:=0.0
var skin: Texture2D
var art_center:=Vector2.ZERO
var art_radius:=1.0
func _ready() -> void:
	skin=load("res://assets/obstacles/bomb-v2.png")
	var meta=JSON.parse_string(FileAccess.get_file_as_string("res://assets/obstacles/bomb-v2.frames.json"))
	art_center=Vector2(meta.body_center[0],meta.body_center[1])
	art_radius=float(meta.body_radius)
	material=preload("res://scripts/obstacles/PropSkins.gd").material()
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	start_y=global_position.y
	mass=2.5
	can_sleep=false
	add_to_group("terrain_loose_bodies")
	collision_layer=4
	collision_mask=1|2|4
	continuous_cd=RigidBody2D.CCD_MODE_CAST_SHAPE
	linear_damp=0.6
	angular_damp=2.0
	physics_material_override=PhysicsMaterial.new()
	physics_material_override.friction=0.8
	physics_material_override.bounce=0.04
	var collider:=CollisionShape2D.new()
	var shape:=CircleShape2D.new()
	shape.radius=radius
	collider.shape=shape
	add_child(collider)
func _physics_process(delta: float) -> void:
	if freeze or exploded or not is_instance_valid(terrain): return
	age+=delta
	released=released or absf(global_position.y-start_y)>6 or linear_velocity.length()>60
	if linear_velocity.length()>360: linear_velocity=linear_velocity.limit_length(360)
	if released and touches_breakable_stone():
		exploded=true
		set_deferred("freeze",true)
		for child in get_children():
			if child is CollisionShape2D: child.set_deferred("disabled",true)
		detonated.emit(global_position)
	queue_redraw()
func touches_breakable_stone() -> bool:
	var local:=global_position-terrain.global_position
	var cell_size: float=terrain.CELL
	for y in range(maxi(0,floori((local.y-radius-3)/cell_size)),mini(terrain.ROWS,ceili((local.y+radius+3)/cell_size))):
		for x in range(maxi(0,floori((local.x-radius-3)/cell_size)),mini(terrain.COLS,ceili((local.x+radius+3)/cell_size))):
			if terrain.cells[y*terrain.COLS+x]!=2: continue
			var nearest:=Vector2(clampf(local.x,x*cell_size,(x+1)*cell_size),clampf(local.y,y*cell_size,(y+1)*cell_size))
			if nearest.distance_to(local)<=radius+3: return true
	return false

func _draw() -> void:
	if exploded or not skin: return
	var factor:=radius/art_radius
	draw_texture_rect(skin,Rect2(-art_center*factor,skin.get_size()*factor),false)
