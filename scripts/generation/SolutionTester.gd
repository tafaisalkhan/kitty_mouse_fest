extends RefCounted

# A route is only a candidate until this drives actual input and physics to a win.
static func execute(game: Node,route: Array,max_frames:=1800) -> Dictionary:
	if game.data.has("section_solutions"): return await execute_sections(game,max_frames)
	if route.size()<2: return {"verified":false,"reason":"No route"}
	var touch:=InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=Vector2(route[0][0],route[0][1])
	game._unhandled_input(touch)
	for i in range(1,route.size()):
		var drag:=InputEventScreenDrag.new()
		drag.index=0
		drag.position=Vector2(route[i][0],route[i][1])
		game._unhandled_input(drag)
		await game.get_tree().physics_frame
	touch.pressed=false
	game._unhandled_input(touch)
	for frame in max_frames:
		await game.get_tree().physics_frame
		if game.ended: break
	return {"verified":game.rescued==game.kittens.size(),"rescued":game.rescued,"count":game.kittens.size(),"seconds":game.elapsed}

static func execute_sections(game: Node,max_frames: int) -> Dictionary:
	var routes: Array=game.data.get("section_solutions",[])
	for section in routes.size():
		for tick in max_frames:
			if game.ended or (game.section_index==section and not game.section_transition): break
			await game.get_tree().physics_frame
		if game.ended or game.section_index!=section: break
		for action in game.data.get("solution_digs",[]):
			if int(action.section)!=section: continue
			await dig_points(game,action.points)
			for tick in int(action.get("wait_ticks",0)): await game.get_tree().physics_frame
		for action in game.data.get("solution_bomb_digs",[]):
			if int(action.section)!=section: continue
			# A bomb-sized channel uses the same single narrow finger stroke as
			# a player. Do not widen it into a Kitty-sized escape route.
			await dig_stroke(game,action.points)
			for tick in max_frames:
				if game.ended or game.obstacles[action.wait_for_bomb].activated: break
				await game.get_tree().physics_frame
		for point in game.data.get("solution_bombs",[]):
			if point[1]>=190+game.camera_offset and point[1]<=1150+game.camera_offset:
				game.use_bomb(Vector2(point[0],point[1]))
		if game.data.has("solution_steps"):
			for step in game.data.solution_steps:
				if int(step.section)!=section or game.ended: continue
				await dig_points(game,step.points)
				if step.has("wait_for_portal"):
					for tick in max_frames:
						if game.ended or game.obstacles[step.wait_for_portal].uses>0: break
						await game.get_tree().physics_frame
				if step.has("wait_for_mouse"):
					for tick in max_frames:
						if game.ended or game.mice.any(func(mouse): return mouse.config.id==step.wait_for_mouse and mouse.eaten): break
						await game.get_tree().physics_frame
			for tick in max_frames:
				await game.get_tree().physics_frame
				if game.ended or game.section_index>section: break
			continue
		await dig_points(game,routes[section])
		for tick in max_frames:
			await game.get_tree().physics_frame
			if game.ended or game.section_index>section: break
	return {"verified":game.rescued==game.kittens.size(),"rescued":game.rescued,"count":game.kittens.size(),"seconds":game.elapsed}

static func dig_points(game: Node,points: Array) -> void:
	# The narrow production brush is never enlarged for verification. Widen
	# reference corridors with separate adjacent finger strokes, as a player can.
	var spread: float=maxf(0,float(game.data.get("reference_brush_radius",game.terrain.brush))-game.terrain.brush)
	var offsets: Array[float]=[0.0]
	var bands:=ceili(spread/game.terrain.brush)
	for band in range(1,bands+1):
		var offset:=minf(spread,band*game.terrain.brush)
		offsets.append(-offset)
		offsets.append(offset)
	for offset in offsets:
		if game.ended: return
		var stroke: Array=[]
		for index in points.size():
			var current:=Vector2(points[index][0],points[index][1])
			var previous:=Vector2(points[maxi(0,index-1)][0],points[maxi(0,index-1)][1])
			var next:=Vector2(points[mini(points.size()-1,index+1)][0],points[mini(points.size()-1,index+1)][1])
			var tangent: Vector2=(next-previous).normalized()
			var shifted:=current+Vector2(-tangent.y,tangent.x)*offset
			stroke.append([shifted.x,shifted.y])
		await dig_stroke(game,stroke)

static func dig_stroke(game: Node,points: Array) -> void:
	var touch:=InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=Vector2(points[0][0],points[0][1]-game.camera_offset)
	game._unhandled_input(touch)
	for index in range(1,points.size()):
		var drag:=InputEventScreenDrag.new()
		drag.index=0
		drag.position=Vector2(points[index][0],points[index][1]-game.camera_offset)
		game._unhandled_input(drag)
		await game.get_tree().physics_frame
	touch.pressed=false
	game._unhandled_input(touch)
