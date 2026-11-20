extends Node2D

var decorations: Texture2D
var foreground_pass:=false
var level_data: Dictionary={}
var brick_faces: Array=[]
var brick_faces_ready:=false

func _ready() -> void:
	if ResourceLoader.exists("res://assets/terrain/garden_props.png"):
		decorations=load("res://assets/terrain/garden_props.png")

func _draw() -> void:
	if foreground_pass:
		draw_borders()
		draw_structural_bricks()
		draw_decorations()
		return
	var world_height:=1280+960*(int(level_data.get("sections",1))-1)
	for y in range(0,world_height,8):
		draw_rect(Rect2(0,y,720,8),Color(0.18,0.55,0.86).lerp(Color(0.72,0.84,0.94),float(y)/world_height))
	for cloud in [[140,50,0.7],[555,73,0.85],[360,18,0.5]]:
		for i in 5:
			draw_circle(Vector2(cloud[0]+(i-2)*19*cloud[2],cloud[1]-sin(i*0.9)*12),22*cloud[2],Color(0.77,0.94,1,0.28))
	var surface: float=level_data.get("start_surface_y",190)
	# Holes open onto the sky; depth comes from the terrain shader cut edge.
	# Dune crest gives the top of the underground board a natural silhouette.
	var points:=PackedVector2Array([Vector2(30,surface+22)])
	for x in range(30,692,6): points.append(Vector2(x,surface+1+sin(x*0.017)*2+sin(x*0.041)))
	points.append(Vector2(690,surface+23))
	draw_colored_polygon(points,Color("ffd273"))

func brick(rect: Rect2,variation: float) -> void:
	if decorations:
		var size:=decorations.get_size()/2
		draw_texture_rect_region(decorations,rect.grow(5),Rect2(Vector2.ZERO,size),Color.WHITE.darkened(variation))
	else:
		draw_style_box(style(Color("9c451c"),6),rect)
		draw_style_box(style(Color("df8736").darkened(variation),5),rect.grow(-2))
		draw_line(rect.position+Vector2(5,5),rect.position+Vector2(rect.size.x-5,5),Color("ffc46a"),3,true)

func draw_borders() -> void:
	var extra:=960*(int(level_data.get("sections",1))-1)
	for x in [0,687]:
		draw_rect(Rect2(x,183,33,1008+extra),Color("87421f"))
		for i in ceili(float(1008+extra)/43):
			brick(Rect2(x-3,185+i*43,38,42),fmod(i*0.13,0.12))
	# Two interlocking courses at the foot of the board.
	draw_rect(Rect2(0,1150+extra,720,130),Color("8a4b25"))
	for row in 3:
		for col in range(-1,10):
			brick(Rect2(col*83+(41 if row%2==1 else 0),1152+extra+row*42,81,40),fmod(col*0.04+row*0.03,0.1))

func stamp(index: int,rect: Rect2,angle:=0.0) -> void:
	if not decorations: return
	var size:=decorations.get_size()/2
	draw_set_transform(rect.get_center(),angle)
	draw_texture_rect_region(decorations,Rect2(-rect.size/2,rect.size),Rect2(Vector2(index%2,index/2)*size,size))
	draw_set_transform(Vector2.ZERO)

func draw_decorations() -> void:
	if level_data.get("trial",false) or level_data.get("endless",false):
		var terrain: Node2D=get_parent().terrain
		for wall in level_data.get("trial_walls",[]):
			if level_data.get("endless",false) and not wall.get("breakable",true): continue
			var rectangle:=Rect2(wall.rect[0],wall.rect[1],wall.rect[2],wall.rect[3])
			var center:=rectangle.get_center()
			var cell:=Vector2i((center-terrain.position)/terrain.CELL)
			if cell.x<0 or cell.x>=terrain.COLS or cell.y<0 or cell.y>=terrain.ROWS: continue
			if terrain.cells[cell.y*terrain.COLS+cell.x]<2: continue
			var label:=("BLAST WALL" if rectangle.size.x>=200 else "STONE") if wall.get("breakable",true) else "LOCKED"
			draw_string(preload("res://scripts/core/UI.gd").game_font(),center+Vector2(-70,6),label,HORIZONTAL_ALIGNMENT_CENTER,140,17,Color("fff1c8"))
	for item in level_data.get("decorations",[]):
		var terrain: Node2D=get_parent().terrain
		var cell:=Vector2i((Vector2(item.x,item.y)-terrain.position)/terrain.CELL)
		if cell.x>=0 and cell.x<terrain.COLS and cell.y>=0 and cell.y<terrain.ROWS:
			if terrain.cells[cell.y*terrain.COLS+cell.x]==0: continue
		stamp(int(item.get("sprite",1)),Rect2(float(item.x)-item.size/2.0,float(item.y)-item.size/2.0,item.size,item.size),float(item.get("rotation",0)))
	if level_data.get("mode","")=="mouse_hunt": return
	var mom: Array=level_data.get("mother",{}).get("position",[450,1040])
	stamp(2,Rect2(mom[0]-95,mom[1]+62,190,62))
	stamp(3,Rect2(mom[0]-120,mom[1]-5,75,110))

func style(color: Color,radius: int) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=color
	box.set_corner_radius_all(radius)
	return box

func draw_structural_bricks() -> void:
	if not brick_faces_ready:
		brick_faces_ready=true
		for raw in level_data.get("brick_polygons",[]):
			var polygon:=PackedVector2Array()
			for point in raw: polygon.append(Vector2(point[0],point[1]))
			if polygon.size()<3: continue
			brick_faces.append({"points":polygon,"color":Color("9d602f")})
			var bounds:=Rect2(polygon[0],Vector2.ZERO)
			for point in polygon: bounds=bounds.expand(point)
			for row in range(floori(bounds.position.y/36),ceili(bounds.end.y/36)):
				for column in range(floori(bounds.position.x/72)-1,ceili(bounds.end.x/72)+1):
					var rect:=Rect2(column*72+(36 if row%2 else 0),row*36,72,36)
					add_brick_face(polygon,rect.grow(-1),Color("b77837"))
					add_brick_face(polygon,rect.grow(-3),Color("e9ad5f"))
					for band in 6:
						var color:=Color("f4c67c").lerp(Color("d58d3f"),band/5.0)
						add_brick_face(polygon,Rect2(rect.position+Vector2(4,4+band*4.6),Vector2(64,4.8)),color)
	for face in brick_faces: draw_colored_polygon(face.points,face.color)

func add_brick_face(polygon: PackedVector2Array,rect: Rect2,color: Color) -> void:
	var corners:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	for piece in Geometry2D.intersect_polygons(polygon,corners):
		if piece.size()>=3 and not Geometry2D.triangulate_polygon(piece).is_empty(): brick_faces.append({"points":piece,"color":color})
