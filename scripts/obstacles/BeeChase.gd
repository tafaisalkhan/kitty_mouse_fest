extends RefCounted

var kittens: Array=[]
var mother: Node2D
var terrain: Node2D
var target: Node2D
var state:="patrol"
var velocity:=Vector2.ZERO
var facing:=1.0
var tilt:=0.0
var path:=PackedVector2Array()
var waypoint:=0
var repath_timer:=0.0
var cached_revision:=-1
var query_shape:=CircleShape2D.new()

func update(bee: Node2D,delta: float) -> void:
	if not bee.enabled:
		target=null
		state="rest"
		velocity=Vector2.ZERO
		return
	repath_timer-=delta
	var revision: int=terrain.revision if is_instance_valid(terrain) else -1
	if target!=null and (not is_instance_valid(target) or (target!=mother and target.rescued)):
		target=null
		path.clear()
		repath_timer=0.0
	if repath_timer<=0 or revision!=cached_revision:
		find_target(bee)
		repath_timer=clampf(float(bee.config.get("repath_seconds",0.12)),0.08,0.2)
		cached_revision=revision
	var destination: Vector2=bee.origin+Vector2(sin(bee.elapsed*1.5)*float(bee.config.get("patrol_width",35)),cos(bee.elapsed*2)*10)
	var speed: float=bee.config.get("patrol_speed",45.0)
	if is_instance_valid(target):
		state="chase"
		# Older generated levels stored timid speeds; keep pursuit aggressive
		# in cached levels as well as newly generated ones.
		speed=maxf(220.0,float(bee.config.get("chase_speed",220)))
		while waypoint<path.size() and bee.global_position.distance_to(path[waypoint])<9:
			waypoint+=1
		# Fly along clear stretches instead of braking at every 20-pixel cell.
		# A full-radius sweep keeps this shortcut from clipping tunnel bends.
		for lookahead in range(mini(waypoint+5,path.size()-1),waypoint,-1):
			var shortcut:=path[lookahead]-bee.global_position
			if safe_motion(bee,shortcut).distance_to(shortcut)<0.5:
				waypoint=lookahead
				break
		destination=path[waypoint] if waypoint<path.size() else target.global_position
	else: state="patrol"
	var offset:=destination-bee.global_position
	var desired:=offset.normalized()*minf(speed,offset.length()*6.0)
	velocity=velocity.move_toward(desired,maxf(950.0,float(bee.config.get("chase_acceleration",950)))*delta)
	var step:=velocity*delta
	var allowed:=safe_motion(bee,step)
	if allowed.length_squared()<step.length_squared()*0.1:
		# Slide along a wall instead of cutting through sand on a corner.
		var slide_x:=safe_motion(bee,Vector2(step.x,0))
		var slide_y:=safe_motion(bee,Vector2(0,step.y))
		allowed=slide_x if slide_x.length_squared()>slide_y.length_squared() else slide_y
	bee.global_position+=allowed
	# Mom is a visual rather than a physics body. Use the same contact rule
	# for both target types, with terrain still blocking every movement step.
	if is_instance_valid(target):
		var hit_radius: float=target.radius*(0.72 if target==mother else 1.0)
		if bee.global_position.distance_to(target.global_position)<=bee.radius+hit_radius:
			var ray:=PhysicsRayQueryParameters2D.create(bee.global_position,target.global_position,1|4)
			if bee.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): bee.danger.emit(target)
	if absf(velocity.x)>8: facing=signf(velocity.x)
	tilt=lerpf(tilt,clampf(velocity.y/maxf(speed,1),-1,1)*0.13,1-exp(-delta*7))

func find_target(bee: Node2D) -> void:
	target=null
	path.clear()
	waypoint=0
	if not bee.config.get("chase",true): return
	var max_distance:=float(bee.config.get("detection_radius",1600))
	var targets:=kittens.duplicate()
	if is_instance_valid(mother): targets.append(mother)
	targets=targets.filter(func(kitten): return is_instance_valid(kitten) and (kitten==mother or not kitten.rescued) and bee.global_position.distance_to(kitten.global_position)<=max_distance)
	if targets.is_empty(): return
	var best_length:=INF
	var grid: AStarGrid2D
	var start:=Vector2i.ZERO
	if is_instance_valid(terrain):
		grid=terrain.bee_navigation(bee.radius,float(bee.config.get("nav_min_y",190)),float(bee.config.get("nav_max_y",-1)))
		start=nearest_open(grid,bee.global_position)
		if start.x<0: return
	for kitten in targets:
		if not is_instance_valid(kitten) or (kitten!=mother and kitten.rescued): continue
		if bee.global_position.distance_to(kitten.global_position)>max_distance: continue
		var candidate:=PackedVector2Array()
		if grid:
			candidate=contact_path(bee,grid,start,kitten)
			if candidate.is_empty(): continue
		else: candidate.append(kitten.global_position)
		var length:=0.0
		var previous: Vector2=bee.global_position
		for point in candidate:
			length+=previous.distance_to(point)
			previous=point
		if length<best_length:
			best_length=length
			target=kitten
			path=candidate
			# The first grid point is our current cell, often behind the bee.
			# Skip it when replanning so pursuit does not repeatedly turn back.
			waypoint=1 if path.size()>1 else 0

func contact_path(bee: Node2D,grid: AStarGrid2D,start: Vector2i,cat: Node2D) -> PackedVector2Array:
	# Search around the cat too: the closest open cell to its center can be
	# on the wrong side of sand, while another approach is reachable.
	var reach: float=cat.radius*(0.72 if cat==mother else 1.0)+bee.radius-4.0
	var points: Array[Vector2]=[cat.global_position]
	for i in 8: points.append(cat.global_position+Vector2.RIGHT.rotated(i*TAU/8)*reach)
	var best:=PackedVector2Array()
	var best_length:=INF
	var visited: Array[Vector2i]=[]
	for point in points:
		var goal:=nearest_open(grid,point)
		if goal.x<0 or visited.has(goal): continue
		visited.append(goal)
		var goal_position:=grid.get_point_position(goal)
		var ray:=PhysicsRayQueryParameters2D.create(goal_position,cat.global_position,1|4)
		if not bee.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var route:=grid.get_point_path(start,goal)
		if route.is_empty(): continue
		var length:=0.0
		var previous:=bee.global_position
		for step in route:
			length+=previous.distance_to(step)
			previous=step
		if length<best_length:
			best_length=length
			best=route
	return best

func nearest_open(grid: AStarGrid2D,point: Vector2) -> Vector2i:
	var center:=Vector2i(((point-grid.offset)/grid.cell_size).round())
	var closest:=Vector2i(-1,-1)
	var best:=INF
	for y in range(center.y-2,center.y+3):
		for x in range(center.x-2,center.x+3):
			var cell:=Vector2i(x,y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell): continue
			var distance:=point.distance_squared_to(grid.get_point_position(cell))
			if distance<best:
				closest=cell
				best=distance
	return closest

func safe_motion(bee: Node2D,step: Vector2) -> Vector2:
	if step.length_squared()<0.00001: return Vector2.ZERO
	query_shape.radius=bee.radius
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=query_shape
	query.transform=Transform2D(0,bee.global_position)
	query.motion=step
	query.collision_mask=1|4
	query.collide_with_areas=false
	query.margin=0.25
	var fractions:=bee.get_world_2d().direct_space_state.cast_motion(query)
	return step*maxf(0.0,fractions[0]-0.01) if fractions[0]<1 else step
