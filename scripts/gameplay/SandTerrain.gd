extends Node2D

var render_visuals:=true
var CELL := 10
var COLS := 66
var ROWS := 96
const CHUNK := 12
var cells := PackedByteArray()
var dirty: Dictionary = {}
var bodies: Dictionary = {}
var image: Image
var texture: ImageTexture
var brush := 35.0
var removed := 0
var debug_chunks := false
var pending := false
var distance_field := PackedFloat32Array()
var cut_material: ShaderMaterial
var previous_mask: ImageTexture
var previous_image: Image
var cut_blend:=1.0
const CUT_SECONDS:=0.05
var revision:=0
var bee_grids: Dictionary={}

func setup(data: Dictionary) -> void:
	position = Vector2(30,190)
	CELL=clampi(int(data.get("grid_size",10)),6,16)
	COLS=ceili(660.0/CELL)
	ROWS=ceili(float(data.get("height",960))/CELL)
	brush = float(data.get("brush_radius",35))
	cells.resize(COLS*ROWS)
	cells.fill(1)
	for chamber in data.get("chambers",[]):
		carve(Vector2(chamber[0],chamber[1])-position,float(chamber[2]),false)
	for tunnel in data.get("tunnels",[]):
		var points: Array=tunnel.points
		var width: float=tunnel.get("radius",45)
		for i in range(1,points.size()):
			var a:=Vector2(points[i-1][0],points[i-1][1])-position
			var b:=Vector2(points[i][0],points[i][1])-position
			var steps:=maxi(1,ceili(a.distance_to(b)/5))
			for j in range(steps+1): carve(a.lerp(b,float(j)/steps),width,false)
	for rect in data.get("rock_rects",[]):
		for y in range(maxi(0,int((rect[1]-190)/CELL)),mini(ROWS,int((rect[1]+rect[3]-190)/CELL))):
			for x in range(maxi(0,int((rect[0]-30)/CELL)),mini(COLS,int((rect[0]+rect[2]-30)/CELL))):
				cells[y*COLS+x]=2
	for rect in data.get("solid_rects",[]):
		for y in range(maxi(0,int((rect[1]-190)/CELL)),mini(ROWS,int((rect[1]+rect[3]-190)/CELL))):
			for x in range(maxi(0,int((rect[0]-30)/CELL)),mini(COLS,int((rect[0]+rect[2]-30)/CELL))): cells[y*COLS+x]=3
	for raw_polygon in data.get("solid_polygons",[]):
		var polygon:=PackedVector2Array()
		for point in raw_polygon: polygon.append(Vector2(point[0],point[1]))
		if polygon.size()<3: continue
		var bounds:=Rect2(polygon[0],Vector2.ZERO)
		for point in polygon: bounds=bounds.expand(point)
		for y in range(maxi(0,floori((bounds.position.y-position.y)/CELL)),mini(ROWS,ceili((bounds.end.y-position.y)/CELL))):
			for x in range(maxi(0,floori((bounds.position.x-position.x)/CELL)),mini(COLS,ceili((bounds.end.x-position.x)/CELL))):
				if Geometry2D.is_point_in_polygon(position+Vector2((x+0.5)*CELL,(y+0.5)*CELL),polygon): cells[y*COLS+x]=3
	if render_visuals:
		image = Image.create(COLS,ROWS,false,Image.FORMAT_RGBA8)
		refresh_image()
		texture = ImageTexture.create_from_image(image)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.scale = Vector2(CELL,CELL)
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string("res://assets/terrain/sculpted_sand.gdshader")
		var material := ShaderMaterial.new()
		material.shader = shader
		cut_material=material
		previous_image=image.duplicate()
		previous_mask=ImageTexture.create_from_image(previous_image)
		material.set_shader_parameter("previous_mask",previous_mask)
		material.set_shader_parameter("cut_blend",1.0)
		material.set_shader_parameter("terrain_mask",texture)
		material.set_shader_parameter("world_size",Vector2(660,ROWS*CELL))
		if ResourceLoader.exists("res://assets/terrain/golden_sand.png"):
			material.set_shader_parameter("sand_texture",load("res://assets/terrain/golden_sand.png"))
			material.set_shader_parameter("has_sand_texture",true)
		sprite.material = material
		add_child(sprite)
	for cy in range(ceili(float(ROWS)/CHUNK)):
		for cx in range(ceili(float(COLS)/CHUNK)):
			dirty[Vector2i(cx,cy)] = true
	rebuild()
	removed=0

func _process(delta: float) -> void:
	if cut_material and cut_blend<1.0:
		cut_blend=minf(1.0,cut_blend+delta/CUT_SECONDS)
		cut_material.set_shader_parameter("cut_blend",cut_blend)

func refresh_image(only_dirty:=false) -> void:
	# Small signed distance mask for the sculpted cut-face. Physics stays chunked.
	distance_field=build_distance_field()
	for y in ROWS:
		for x in COLS:
			var cell := cells[y*COLS+x]
			image.set_pixel(x,y,Color(1.0 if cell==1 else 0.15 if cell==3 else 0.35,clampf(0.5+distance_field[y*COLS+x]/128.0,0,1),0.25,1.0 if cell>0 else 0.0))

func build_distance_field() -> PackedFloat32Array:
	var fields: Array[PackedFloat32Array]=[]
	for target in [0,1]:
		var field:=PackedFloat32Array()
		field.resize(COLS*ROWS)
		for i in cells.size(): field[i]=0.0 if (cells[i]==0)==(target==0) else 1000.0
		for pass_index in 2:
			var direction:=1 if pass_index==0 else -1
			for yi in ROWS:
				var y:=yi if direction==1 else ROWS-yi-1
				for xi in COLS:
					var x:=xi if direction==1 else COLS-xi-1
					var index:=y*COLS+x
					var px:=x-direction
					var py:=y-direction
					if px>=0 and px<COLS: field[index]=minf(field[index],field[y*COLS+px]+1.0)
					if py>=0 and py<ROWS:
						field[index]=minf(field[index],field[py*COLS+x]+1.0)
						for dx in [-1,1]:
							if x+dx>=0 and x+dx<COLS: field[index]=minf(field[index],field[py*COLS+x+dx]+1.4142)
		fields.append(field)
	var result:=PackedFloat32Array()
	result.resize(COLS*ROWS)
	for i in result.size():
		var raw: float=fields[0][i]-fields[1][i]
		result[i]=(raw-signf(raw)*0.5)*CELL
	return result

func dig_segment(a: Vector2,b: Vector2) -> int:
	var before := removed
	var steps := maxi(1,ceili(a.distance_to(b)/maxf(4.0,brush*0.16)))
	for i in range(steps+1):
		carve(a.lerp(b,float(i)/steps)-position,brush,true)
	if removed>before and not pending:
		pending = true
		call_deferred("rebuild")
	return removed-before

func carve(center: Vector2,radius: float,mark: bool) -> void:
	for y in range(maxi(0,floori((center.y-radius)/CELL)),mini(ROWS,ceili((center.y+radius)/CELL))):
		for x in range(maxi(0,floori((center.x-radius)/CELL)),mini(COLS,ceili((center.x+radius)/CELL))):
			if Vector2(x*CELL+CELL*0.5,y*CELL+CELL*0.5).distance_to(center)<=radius and cells[y*COLS+x]==1:
				cells[y*COLS+x]=0
				removed+=1
				if mark: dirty[Vector2i(x/CHUNK,y/CHUNK)]=true

func blast(world_point: Vector2,radius:=110.0) -> int:
	var count:=0
	var center:=world_point-position
	for y in range(maxi(0,floori((center.y-radius)/CELL)),mini(ROWS,ceili((center.y+radius)/CELL))):
		for x in range(maxi(0,floori((center.x-radius)/CELL)),mini(COLS,ceili((center.x+radius)/CELL))):
			if cells[y*COLS+x] in [1,2] and Vector2(x*CELL+CELL*0.5,y*CELL+CELL*0.5).distance_to(center)<=radius:
				cells[y*COLS+x]=0
				removed+=1
				count+=1
				dirty[Vector2i(x/CHUNK,y/CHUNK)]=true
	if count>0 and not pending:
		pending=true
		call_deferred("rebuild")
	return count

func rebuild() -> void:
	pending=false
	if image:
		if previous_mask:
			if cut_blend>=1.0:
				previous_image=image.duplicate()
			else:
				for y in ROWS:
					for x in COLS:
						previous_image.set_pixel(x,y,previous_image.get_pixel(x,y).lerp(image.get_pixel(x,y),cut_blend))
			previous_mask.update(previous_image)
			cut_blend=0.0
			cut_material.set_shader_parameter("cut_blend",0.0)
		refresh_image(true)
		if texture: texture.update(image)
	for key in dirty:
		if bodies.has(key):
			var old: StaticBody2D = bodies[key]
			remove_child(old)
			old.queue_free()
		var body := StaticBody2D.new()
		body.collision_layer=1
		body.collision_mask=6
		# Merge identical horizontal runs vertically within each dirty chunk.
		var runs: Dictionary={}
		for y in range(key.y*CHUNK,mini(ROWS,(key.y+1)*CHUNK)):
			var x: int=key.x*CHUNK
			while x<mini(COLS,(key.x+1)*CHUNK):
				if cells[y*COLS+x]==0:
					x+=1
					continue
				var start:=x
				while x<mini(COLS,(key.x+1)*CHUNK) and cells[y*COLS+x]>0: x+=1
				var run_key:=Vector2i(start,x-start)
				if runs.has(run_key) and runs[run_key].end.y==y:
					var rect: Rect2i=runs[run_key]
					rect.size.y+=1
					runs[run_key]=rect
				else:
					if runs.has(run_key): add_rect(body,runs[run_key])
					runs[run_key]=Rect2i(start,y,x-start,1)
		for rect in runs.values(): add_rect(body,rect)
		add_child(body)
		bodies[key]=body
	dirty.clear()
	# Rebuilt chunks are new StaticBody2Ds. Wake active loose bodies explicitly
	# so removing a support cannot leave an old sleeping contact suspended.
	for loose in get_tree().get_nodes_in_group("terrain_loose_bodies"):
		if loose is RigidBody2D and not loose.freeze and loose.get_world_2d()==get_world_2d(): loose.sleeping=false
	revision+=1
	bee_grids.clear()
	queue_redraw()

func bee_navigation(clearance: float,min_y:=190.0,max_y:=-1.0) -> AStarGrid2D:
	var nav_rows:=ceili(float(ROWS*CELL)/20.0)
	var first_row:=clampi(floori((min_y-position.y)/20.0),0,nav_rows-1)
	var end_row:=nav_rows if max_y<0 else clampi(ceili((max_y-position.y)/20.0),first_row+1,nav_rows)
	var key:=Vector3i(ceili(clearance),first_row,end_row)
	if bee_grids.has(key): return bee_grids[key]
	var grid:=AStarGrid2D.new()
	grid.region=Rect2i(0,first_row,33,end_row-first_row)
	grid.cell_size=Vector2(20,20)
	grid.offset=position+Vector2(10,10)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(first_row,end_row):
		for x in 33:
			var id:=Vector2i(x,y)
			grid.set_point_solid(id,not circle_is_empty(grid.get_point_position(id),clearance+1.0))
	bee_grids[key]=grid
	return grid

func circle_is_empty(world_point: Vector2,clearance: float) -> bool:
	var point:=world_point-position
	var start:=Vector2i(((point-Vector2.ONE*clearance)/CELL).floor())
	var end:=Vector2i(((point+Vector2.ONE*clearance)/CELL).floor())
	for y in range(start.y,end.y+1):
		for x in range(start.x,end.x+1):
			if x<0 or y<0 or x>=COLS or y>=ROWS: return false
			if cells[y*COLS+x]==0: continue
			var corner:=Vector2(x,y)*CELL
			var nearest:=point.clamp(corner,corner+Vector2.ONE*CELL)
			if point.distance_squared_to(nearest)<clearance*clearance: return false
	return true

func add_rect(body: StaticBody2D,rect: Rect2i) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size=Vector2(rect.size)*CELL
	shape.shape=box
	shape.position=Vector2(rect.position)*CELL+box.size/2
	body.add_child(shape)

func _draw() -> void:
	if debug_chunks:
		for key in bodies:
			draw_rect(Rect2(Vector2(key)*CHUNK*CELL,Vector2.ONE*CHUNK*CELL),Color(0.2,1,0.6,0.6),false,1)

