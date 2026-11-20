extends RefCounted
const VERSION:=5
const Base=preload("res://scripts/generation/HuntLevels.gd")

static func recipe_path(number: int) -> String:
	return "res://levels/hunt_recipes/level_%04d.json"%number

static func candidate(number: int,attempt:=0) -> Dictionary:
	var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(recipe_path(number)))
	var data:=Base.create_prototype(number)
	var count:=int(recipe.screen_count)
	data.name=recipe.name
	data.seed=recipe.seed
	data.hunt_generation_version=VERSION
	data.recipe_hash=FileAccess.get_file_as_string(recipe_path(number)).sha256_text()
	data.difficulty_tier=recipe.difficulty_tier
	data.sections=count
	data.section_names=[]
	data.world.height=1280+960*(count-1)
	data.terrain={"grid_size":10,"height":960*count,"brush_radius":minf(90,float(recipe.brush_radius)+attempt*4),"chambers":[[360,300,65]],"tunnels":[],"rock_rects":[]}
	data.mice=[]
	data.obstacles=[]
	data.section_solutions=[]
	data.solution_steps=[]
	data.solution_digs=[]
	data.solution_bombs=[]
	data.modules=[]
	data.objectives.target_time_seconds=recipe.target_time_seconds
	data.objectives.target_dig_distance=recipe.target_dig_distance
	data.mother.position=[360,1090+960*(count-1)]
	for section in count:
		var spec: Dictionary=recipe.screens[section]
		var module: String=spec.module
		var y:=section*960
		var mirror: float=-1 if spec.mirror else 1
		var shift:=float(spec.offset_x)
		data.modules.append(module)
		data.section_names.append(module.replace("_"," ").to_upper())
		if section>0: data.terrain.chambers.append([360,200+y,110])
		data.terrain.chambers.append([360,1100+y,125])
		var xs: Array=[330,390,350]
		match module:
			"wheel_bypass": xs=[240,235,345]
			"stone_bee_trap": xs=[355,425,350]
			"moving_catch": xs=[265,255,355]
			"timed_garden": xs=[280,295,355]
			"size_order_fork": xs=[265,290,400]
		var start: Array=[360,310+y] if section==0 else [360,200+y]
		var route: Array=[start]
		var previous: Array=start
		for i in 3:
			var x:=360+(float(xs[i])-360)*mirror+shift
			var p: Array=[x,int(spec.hole_y[i])+y]
			var distance:=maxf(12,float(recipe.escape_distance)-attempt*4)
			var escape_dx: float=(360-x)*0.65 if i==2 else float(spec.escape_direction)*mirror*distance*1.15
			var escape: Array=[[x+escape_dx*0.6,p[1]+16],[x+escape_dx,p[1]+32]]
			var id:="prey_%d_%d"%[section,i]
			data.mice.append({"id":id,"position":p,"section":section,"kind":"SMALL" if i<2 else "BIG","required_growth":section*3+(0 if i<2 else 2),"growth":1,"radius":15 if i<2 else 27,"flee_speed":maxf(30,float(recipe.flee_speed)-attempt*5),"escape_distance":distance*1.5+36,"escape_route":escape})
			data.terrain.chambers.append([x,p[1],80 if i<2 else 105])
			data.terrain.tunnels.append({"points":[p]+escape,"radius":40 if i<2 else 48})
			# Stop excavation above the escape pocket's floor. Cutting through
			# its bottom would drop Kitty past the prey before she can turn.
			var dig_end: Array=[escape[-1][0],p[1]+3]
			var points: Array=[previous,p,dig_end]
			data.solution_steps.append({"section":section,"points":points,"wait_for_mouse":id})
			route.append_array([p,dig_end])
			previous=dig_end
		var ending: Array=[360,(1140 if section<count-1 else 1100)+y]
		data.solution_steps.append({"section":section,"points":[previous,ending]})
		route.append(ending)
		data.section_solutions.append(route)
		match module:
			"switch_gate":
				var switch_point: Array=data.mice[section*3+1].position
				data.obstacles.append({"id":"switch_%d"%section,"type":"pressure_switch","position":switch_point.duplicate(),"radius":48,"target":"gate_%d"%section})
				data.obstacles.append({"id":"gate_%d"%section,"type":"gate","position":[360,865+y],"width":520,"radius":25})
				data.terrain.chambers.append([360,865+y,110])
			"wheel_bypass":
				data.obstacles.append({"id":"wheel_%d"%section,"type":"rotating_wheel","position":[360+shift,690+y],"radius":60,"speed":(0.4+float(recipe.difficulty_tier)*0.025)*mirror,"interactive":true})
				data.terrain.chambers.append([360+shift,690+y,95])
			"stone_bee_trap":
				var trap_x:=360+190*mirror
				data.obstacles.append({"id":"stone_%d"%section,"type":"falling_rock","position":[trap_x,510+y],"radius":34})
				data.obstacles.append({"id":"bee_%d"%section,"type":"bee","position":[trap_x,850+y],"radius":23,"chase_speed":225})
				data.terrain.chambers.append_array([[trap_x,510+y,75],[trap_x,850+y,75]])
				data.terrain.tunnels.append({"points":[[trap_x,620+y],[trap_x,850+y]],"radius":52})
				data.solution_digs.append({"section":section,"points":[[trap_x,575+y],[trap_x,850+y]],"wait_ticks":150})
			"moving_catch":
				var px:=360+125*mirror
				data.obstacles.append({"id":"platform_%d"%section,"type":"moving_platform","position":[px,650+y],"width":130,"distance":40,"speed":0.6+float(recipe.difficulty_tier)*0.04})
				data.terrain.chambers.append([px,650+y,125])
				data.obstacles.append({"id":"plant_%d"%section,"type":"dangerous_plant","position":[360+220*mirror,870+y],"radius":30})
				data.terrain.chambers.append([360+220*mirror,870+y,55])
			"timed_garden":
				data.obstacles.append({"id":"garden_%d"%section,"type":"dangerous_plant","position":[360+145*mirror,650+y],"radius":32})
				data.obstacles.append({"id":"spikes_%d"%section,"type":"spikes","position":[360-200*mirror,905+y],"radius":28})
				data.terrain.chambers.append_array([[360+145*mirror,650+y,65],[360-200*mirror,905+y,55]])
			"size_order_fork":
				data.terrain.tunnels.append({"points":[[360+160*mirror,410+y],[360+110*mirror,960+y]],"radius":29})
		if number>=20 and number%10==0:
			data.terrain.rock_rects.append([270,365+y,180,35])
			data.solution_bombs.append([360,380+y])
		if number>=200:
			data.obstacles.append({"id":"edge_%d"%section,"type":"spikes","position":[625,560+y],"radius":25})
			data.terrain.chambers.append([625,560+y,45])
	data.bombs=data.solution_bombs.size()
	data.solution=data.section_solutions[0].duplicate(true)
	data.tutorial="Dig one burrow at a time. Catch SMALL mice before BIG mice."
	return data
