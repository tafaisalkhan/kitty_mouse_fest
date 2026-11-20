extends Node2D

# Shared full-body artwork renderer. Alpha bounds align paws between poses.
var main: Sprite2D
var previous: Sprite2D
var bounds: Array=[]
var cell_size:=Vector2.ONE
var pose:=-1
var blend:=1.0
var ready_art:=false

func configure(path: String,columns:=4,rows:=3) -> bool:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not ResourceLoader.exists(path): return false
	var texture: Texture2D=load(path)
	cell_size=texture.get_size()/Vector2(columns,rows)
	var meta_path:=path.get_basename()+".frames.json"
	if FileAccess.file_exists(meta_path):
		var meta=JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		for rect in meta.frames: bounds.append(Rect2(rect[0],rect[1],rect[2],rect[3]))
	else:
		for i in columns*rows: bounds.append(Rect2(Vector2.ZERO,cell_size))
	for i in 2:
		var sprite:=Sprite2D.new()
		sprite.texture=texture
		sprite.hframes=columns
		sprite.vframes=rows
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		if i==0: previous=sprite
		else: main=sprite
	previous.hide()
	ready_art=true
	return true

func show_pose(index: int,height: float,baseline: float,flip:=false,tilt:=0.0) -> void:
	if not ready_art: return
	index=clampi(index,0,bounds.size()-1)
	if index!=pose:
		if pose>=0:
			previous.frame=main.frame
			previous.scale=main.scale
			previous.offset=main.offset
			previous.position=main.position
			previous.flip_h=main.flip_h
			previous.rotation=main.rotation
			previous.modulate=main.modulate
			previous.show()
			blend=0.0
		pose=index
		main.frame=index
	var rect: Rect2=bounds[index]
	var factor:=height/maxf(1,rect.size.y)
	main.scale=Vector2.ONE*factor
	var center_x: float=rect.get_center().x
	if flip: center_x=cell_size.x-center_x
	main.offset=cell_size/2-Vector2(center_x,rect.end.y)
	main.position=Vector2(0,baseline)
	main.flip_h=flip
	main.rotation=tilt
	main.modulate.a=blend

func _process(delta: float) -> void:
	if not ready_art: return
	blend=minf(1,blend+delta/0.09)
	main.modulate.a=blend
	previous.modulate.a=1-blend
	if blend>=1: previous.hide()

func frame_point_world(point: Vector2) -> Vector2:
	if main.flip_h: point.x=cell_size.x-point.x
	return main.to_global(point-cell_size/2+main.offset)

func deform_around_floor(stretch: Vector2,baseline: float) -> void:
	scale=stretch
	position=Vector2(0,baseline*(1-stretch.y))

func set_atlas_material(atlas_material: Material) -> void:
	if not ready_art: return
	main.material=atlas_material
	previous.material=atlas_material
