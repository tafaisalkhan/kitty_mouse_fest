extends RefCounted

const MODULE_INDEX={"switch_gate":0,"rotating_wheel":1,"stone_bee_trap":2,"moving_platform":3,"garden_gate":4}

static func build(recipe: Dictionary, source: Dictionary, attempt: int) -> Dictionary:
	var data:=source.duplicate(true)
	var count:=int(recipe.screen_count)
	data.number=int(recipe.number)
	data.id="level_%03d"%data.number
	data.name=recipe.name
	data.seed=int(recipe.seed)
	data.topology="campaign_modules"
	data.difficulty="medium" if int(recipe.difficulty_tier)<3 else "hard"
	data.difficulty_tier=int(recipe.difficulty_tier)
	data.sections=count
	data.world.height=1280+960*(count-1)
	data.terrain.height=960*count
	data.terrain.brush_radius=minf(90,float(recipe.brush_radius)+attempt*3)
	data.terrain.chambers=[[360,300,120]]
	data.terrain.tunnels=[]
	data.terrain.rock_rects=[]
	data.obstacles=[]
	data.section_solutions=[]
	data.solution_bombs=[]
	data.solution_digs=[]
	data.section_names=[]
	data.objectives=recipe.objectives.duplicate(true)
	data.kittens=[]
	for i in int(recipe.kitten_count):
		data.kittens.append({"id":"baby_%d"%i,"position":[360+(i-(int(recipe.kitten_count)-1)*0.5)*54,300],"radius":25,"variant":(int(recipe.number)+i)%6})
	for section in count:
		var module: String=recipe.screens[section].module
		var original: int=MODULE_INDEX[module]
		var old_y:=original*960
		var shift: int=(section-original)*960
		data.section_names.append(module.replace("_"," ").to_upper())
		for chamber in source.terrain.chambers:
			if chamber[1]<old_y+190 or chamber[1]>old_y+1150: continue
			data.terrain.chambers.append([chamber[0],chamber[1]+shift,chamber[2]])
		for tunnel in source.terrain.tunnels:
			if tunnel.points[0][1]<old_y+190 or tunnel.points[0][1]>old_y+1150: continue
			var copy: Dictionary=tunnel.duplicate(true)
			for point in copy.points: point[1]+=shift
			data.terrain.tunnels.append(copy)
		for wall in source.terrain.rock_rects:
			if wall[1]<old_y+190 or wall[1]>old_y+1150: continue
			data.terrain.rock_rects.append([wall[0],wall[1]+shift,wall[2],wall[3]])
		for item in source.obstacles:
			if item.position[1]<old_y+190 or item.position[1]>old_y+1150: continue
			var copy: Dictionary=item.duplicate(true)
			copy.position[1]+=shift
			copy.id+="_part_%d"%section
			if copy.has("target"): copy.target+="_part_%d"%section
			if copy.type=="rotating_wheel": copy.speed=maxf(0.15,float(recipe.wheel_speed)*pow(0.8,attempt))
			if copy.type=="moving_platform":
				copy.speed=float(recipe.platform_speed)*pow(0.9,attempt)
				copy.distance=recipe.platform_distance
			if copy.type=="bee": copy.chase_speed=recipe.bee_chase_speed
			data.obstacles.append(copy)
		for point in source.solution_bombs:
			if point[1]>=old_y+190 and point[1]<=old_y+1150: data.solution_bombs.append([point[0],point[1]+shift])
		for action in source.solution_digs:
			if int(action.section)!=original: continue
			var copy: Dictionary=action.duplicate(true)
			copy.section=section
			for point in copy.points: point[1]+=shift
			data.solution_digs.append(copy)
		var route: Array=source.section_solutions[original].duplicate(true)
		for point in route: point[1]+=shift
		route[0]=[360,310 if section==0 else 200+section*960]
		route[-1]=[360,(1030 if section==count-1 else 1140)+section*960]
		data.section_solutions.append(route)
		for extra in int(recipe.extra_hazards_per_screen):
			var x:=630 if extra==0 else 90
			var y:=section*960+450+extra*420
			data.terrain.chambers.append([x,y,48])
			data.obstacles.append({"id":"side_%d_%d"%[section,extra],"type":"spikes" if extra==0 else "dangerous_plant","position":[x,y],"radius":25})
	data.mother.position=[360,1030+960*(count-1)]
	data.terrain.chambers.append([360,data.mother.position[1],130])
	# One bomb per stone wall; no paid booster is required to finish a recipe.
	data.bombs=data.solution_bombs.size()
	data.solution=data.section_solutions[0].duplicate(true)
	data.tutorial="Gather every kitten at each base. Switches open gates; drop stones onto bees."
	if recipe.mirror: mirror(data)
	shift_layout(data,float(recipe.layout_offset_x))
	return data

static func shift_layout(data: Dictionary,offset: float) -> void:
	for chamber in data.terrain.chambers: chamber[0]+=offset
	for wall in data.terrain.rock_rects: wall[0]+=offset
	for tunnel in data.terrain.tunnels:
		for point in tunnel.points: point[0]+=offset
	for item in data.obstacles+data.kittens+[data.mother]: item.position[0]+=offset
	for route in data.section_solutions:
		for point in route: point[0]+=offset
	for point in data.solution_bombs: point[0]+=offset
	for action in data.solution_digs:
		for point in action.points: point[0]+=offset
	data.solution=data.section_solutions[0].duplicate(true)

static func mirror(data: Dictionary) -> void:
	for chamber in data.terrain.chambers: chamber[0]=720-chamber[0]
	for wall in data.terrain.rock_rects: wall[0]=720-wall[0]-wall[2]
	for tunnel in data.terrain.tunnels:
		for point in tunnel.points: point[0]=720-point[0]
	for item in data.obstacles+data.kittens+[data.mother]: item.position[0]=720-item.position[0]
	for route in data.section_solutions:
		for point in route: point[0]=720-point[0]
	for point in data.solution_bombs: point[0]=720-point[0]
	for action in data.solution_digs:
		for point in action.points: point[0]=720-point[0]
	data.solution=data.section_solutions[0].duplicate(true)
