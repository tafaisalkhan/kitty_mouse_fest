extends RefCounted
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const COUNT:=5

static func path_for(number: int) -> String:
	return "res://levels/trial/trial_%02d.json"%number

static func source_hash(source: Dictionary) -> String:
	var copy:=source.duplicate(true)
	copy.erase("verification")
	return JSON.stringify(copy).sha256_text()

static func read_source(number: int) -> Dictionary:
	var value=JSON.parse_string(FileAccess.get_file_as_string(path_for(number))) if FileAccess.file_exists(path_for(number)) else null
	return value if value is Dictionary else {}

static func validate_source(source: Dictionary) -> PackedStringArray:
	var errors:=PackedStringArray()
	for key in ["id","name","seed","resources","instructions"]:
		if not source.has(key): errors.append("Missing trial field: "+key)
	if source.get("schema_version",0)!=2: errors.append("Trial schema must be version 2")
	if int(source.get("number",0))<1 or int(source.get("number",0))>COUNT: errors.append("Trial number outside 1–10")
	if not source.get("sections",null) is Array or source.sections.is_empty() or source.sections.size()>5: return PackedStringArray(["Expected 1–5 trial sections"])
	if not source.get("kitty",null) is Dictionary or source.get("kitty",{}).get("radius",0)!=50: errors.append("Trial must use the current 50-pixel Kitty")
	elif not same_numbers(source.kitty.get("position",[]),[360,280]): errors.append("Invalid starting Kitty position")
	if not source.get("resources",null) is Dictionary or not Validator.is_number(source.get("resources",{}).get("bombs",null)): errors.append("Trial needs a numeric bomb allowance")
	elif float(source.resources.bombs)!=float(int(source.resources.bombs)): errors.append("Bomb allowance must be a whole number")
	if not source.get("required_events",[]) is Array: errors.append("Required events must be an array")
	for i in source.sections.size():
		var section=source.sections[i]
		if not section is Dictionary:
			errors.append("Section must be an object")
			continue
		if int(section.get("index",-1))!=i or not same_numbers(section.get("bounds",[]),[30,190+960*i,660,960]): errors.append("Invalid section index/bounds")
		if not same_numbers(section.get("camera_center",[]),[360,640+960*i]): errors.append("Invalid camera center")
		if not same_numbers(section.get("exit_base",[]),[360,1150+960*i]): errors.append("Invalid section base")
		if not section.get("completion",null) is Dictionary: errors.append("Section needs completion rules")
		elif i+1<source.sections.size() and source.sections[i+1] is Dictionary and section.completion.get("next_section",null)!=source.sections[i+1].get("id",""): errors.append("Unresolved next section")
		elif i+1==source.sections.size() and section.completion.get("next_section",null)!=null: errors.append("Final section cannot loop to another level")
		if section.get("completion",null) is Dictionary and (not section.completion.get("eat_all_mice",false) or not section.completion.get("reach_exit_base",false)): errors.append("Trial completion requires every mouse and the base")
		if not section.get("mice",null) is Array or (section.get("mice",[]).size()<2 or section.get("mice",[]).size()>5): errors.append("Each trial section needs two to five ordered mice")
		if not section.get("obstacles",[]) is Array: errors.append("Obstacles must be an array")
		if not section.get("terrain",null) is Dictionary:
			errors.append("Section needs terrain")
			continue
		for key in ["chambers","walls","tunnels"]:
			if not section.terrain.get(key,[]) is Array: errors.append("Terrain "+key+" must be an array")
		if not errors.is_empty(): continue
		for chamber in section.terrain.get("chambers",[]):
			if not chamber is Dictionary or not numeric_array(chamber.get("position",null),2) or not Validator.is_number(chamber.get("radius",null)): errors.append("Invalid chamber")
			elif chamber.radius<=0 or chamber.radius>250: errors.append("Invalid chamber radius")
		for wall in section.terrain.get("walls",[]):
			if not wall is Dictionary or not numeric_array(wall.get("rect",null),4): errors.append("Invalid wall rectangle")
			elif wall.rect[2]<=0 or wall.rect[3]<=0 or wall.rect[0]<30 or wall.rect[0]+wall.rect[2]>690 or wall.rect[1]<190+960*i or wall.rect[1]+wall.rect[3]>1150+960*i: errors.append("Wall outside its section")
			elif not wall.get("breakable",true) is bool: errors.append("Wall breakable flag must be boolean")
		for tunnel in section.terrain.get("tunnels",[]):
			if not tunnel is Dictionary or not Validator.is_number(tunnel.get("radius",null)) or not tunnel.get("points",null) is Array: errors.append("Invalid tunnel")
			else:
				for point in tunnel.points:
					if not numeric_array(point,2): errors.append("Invalid tunnel point")
		if not section.get("reference_route",null) is Array: errors.append("Section needs a reference route")
		else:
			for point in section.reference_route:
				if not numeric_array(point,2): errors.append("Invalid reference route point")
		if not section.get("solution_steps",null) is Array or section.get("solution_steps",[]).is_empty(): errors.append("Section needs a candidate solution")
		for key in ["solution_steps","solution_digs","solution_bomb_digs"]:
			if not section.get(key,[]) is Array:
				errors.append("Invalid solution actions")
				continue
			for action in section.get(key,[]):
				if not action is Dictionary or not action.get("points",null) is Array or action.get("points",[]).is_empty(): errors.append("Invalid solution stroke")
				else:
					for point in action.points:
						if not numeric_array(point,2): errors.append("Invalid solution point")
	if errors.is_empty():
		var converted:=to_engine(source)
		errors.append_array(Validator.validate(converted))
		var mouse_ids: Dictionary={}
		var obstacle_types: Dictionary={}
		for mouse in converted.mice: mouse_ids[mouse.id]=true
		for obstacle in converted.obstacles: obstacle_types[obstacle.id]=obstacle.type
		if converted.physical_bombs:
			var placed: int=converted.obstacles.filter(func(o):return o.type=="bomb").size()
			if placed!=int(source.resources.bombs) or not converted.solution_bombs.is_empty(): errors.append("Physical levels need matching placed bombs and no tap-to-blast actions")
		for action in converted.solution_bomb_digs:
			if obstacle_types.get(action.get("wait_for_bomb",""),"")!="bomb": errors.append("Bomb solution must reference a physical bomb")
		for step in converted.solution_steps:
			if step.has("wait_for_mouse") and not mouse_ids.has(step.wait_for_mouse): errors.append("Unresolved solution mouse")
			if step.has("wait_for_portal") and obstacle_types.get(step.wait_for_portal,"")!="portal": errors.append("Unresolved solution portal")
		for requirement in converted.required_events:
			if not requirement is Dictionary or not obstacle_types.has(requirement.get("id","")) or requirement.get("event","") not in ["activated","defeated","used","fell","rotated","detonated"]: errors.append("Invalid required mechanic event")
			elif requirement.event in ["fell","rotated"] and obstacle_types[requirement.id] not in ["falling_rock","rotating_wheel","moving_platform","gate"]: errors.append("Required event needs a physical obstacle")
	return errors

static func numeric_array(value: Variant,count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for item in value:
		if not Validator.is_number(item): return false
	return true

static func geometry_signature(source: Dictionary) -> String:
	var geometry: Array=[]
	for part in source.sections:
		var walls: Array=[]
		for wall in part.terrain.get("walls",[]): walls.append([wall.rect,wall.get("breakable",true)])
		var obstacles: Array=[]
		for item in part.obstacles:
			var shape: Dictionary=item.duplicate(true)
			for key in ["id","target","targets","linked_to"]: shape.erase(key)
			obstacles.append(shape)
		geometry.append([part.terrain.chambers,walls,part.terrain.get("tunnels",[]),part.mice.map(func(m): return [m.position,m.kind,m.required_growth]),obstacles])
	return JSON.stringify(geometry).sha256_text()

static func same_numbers(value: Variant,expected: Array) -> bool:
	if not value is Array or value.size()!=expected.size(): return false
	for i in expected.size():
		if not Validator.is_number(value[i]) or not is_equal_approx(float(value[i]),float(expected[i])): return false
	return true

static func load_trial(number: int,require_verified:=true) -> Dictionary:
	var source:=read_source(number)
	var errors:=validate_source(source)
	if int(source.get("number",0))!=number or source.get("id","")!="trial_%02d"%number: errors.append("Trial identity does not match the requested file")
	if require_verified:
		if not is_verified(source): errors.append("Trial has no current verified solution")
	if not errors.is_empty(): return {"mode":"mouse_hunt","error":"Trial %d: %s"%[number,"; ".join(errors)]}
	return to_engine(source)

static func is_verified(source: Dictionary) -> bool:
	var proof: Dictionary=source.get("verification",{})
	return proof.get("passed",false) and proof.get("source_hash","")==source_hash(source)

static func to_engine(source: Dictionary) -> Dictionary:
	var count: int=source.sections.size()
	var chambers: Array=[]
	var rocks: Array=[]
	var solids: Array=[]
	var mice: Array=[]
	var obstacles: Array=[]
	var routes: Array=[]
	var digs: Array=[]
	var steps: Array=[]
	var bombs: Array=[]
	var bomb_digs: Array=[]
	var names: Array=[]
	var tunnels: Array=[]
	var walls_metadata: Array=[]
	for part in source.sections:
		names.append(part.name)
		for chamber in part.terrain.get("chambers",[]): chambers.append([chamber.position[0],chamber.position[1],chamber.radius])
		tunnels.append_array(part.terrain.get("tunnels",[]))
		for wall in part.terrain.get("walls",[]):
			walls_metadata.append(wall)
			if wall.get("breakable",true): rocks.append(wall.rect)
			else: solids.append(wall.rect)
		for mouse in part.mice:
			var item: Dictionary=mouse.duplicate(true)
			item.section=part.index
			mice.append(item)
		obstacles.append_array(part.get("obstacles",[]))
		routes.append(part.reference_route)
		for action in part.get("solution_digs",[]): digs.append({"section":part.index,"points":action.points,"wait_ticks":action.get("wait_ticks",0)})
		for action in part.solution_steps:
			var step: Dictionary=action.duplicate(true)
			step.section=part.index
			steps.append(step)
		for action in part.get("solution_bomb_digs",[]):
			var item: Dictionary=action.duplicate(true)
			item.section=part.index
			bomb_digs.append(item)
		bombs.append_array(part.get("solution_bombs",[]))
	return {"schema_version":1,"mode":"mouse_hunt","trial":true,"physical_bombs":source.get("bomb_mode","")=="physical","finish_at_base":true,"id":source.id,"number":source.number,"name":source.name,"seed":source.seed,"sections":count,"section_names":names,"bombs":source.resources.bombs,"world":{"width":720,"height":1280+960*(count-1),"gravity":980},"terrain":{"height":960*count,"grid_size":10,"brush_radius":84,"chambers":chambers,"tunnels":tunnels,"rock_rects":rocks,"solid_rects":solids},"kittens":[{"id":"mom_kitty","position":[360,280],"radius":25,"mass":4,"mother":true}],"mother":{"id":"unused_goal","position":[360,1100+960*(count-1)],"rescue_radius":60},"mice":mice,"obstacles":obstacles,"section_solutions":routes,"solution":routes[0],"solution_digs":digs,"solution_steps":steps,"solution_bombs":bombs,"solution_bomb_digs":bomb_digs,"trial_walls":walls_metadata,"required_events":source.get("required_events",[]),"objectives":{"target_time_seconds":count*120,"target_dig_distance":count*18000},"tutorial":source.instructions}
