extends RefCounted

const TYPES = ["rotating_wheel","falling_rock","bee","spikes","dangerous_plant","pressure_switch","gate","fan","portal","water","moving_platform","laser","bomb"]

static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary: return PackedStringArray(["Level must be a JSON object"])
	for key in ["schema_version","id","world","terrain","kittens","mother","obstacles"]:
		if not data.has(key): errors.append("Missing field: " + key)
	if not errors.is_empty(): return errors
	if data.schema_version != 1: errors.append("Unsupported schema version")
	if not data.world is Dictionary or not data.terrain is Dictionary or not data.mother is Dictionary or not data.kittens is Array or not data.obstacles is Array:
		return PackedStringArray(["Invalid world, terrain, mother, kittens or obstacles type"])
	if not is_number(data.get("sections",1)): return PackedStringArray(["Section count must be numeric"])
	var sections: int=int(data.get("sections",1))
	if float(sections)!=float(data.get("sections",1)): errors.append("Section count must be a whole number")
	if sections<1 or sections>5: errors.append("Expected one to five sections")
	if data.world.get("width",0)!=720 or data.world.get("height",0)!=1280+960*(sections-1): errors.append("Invalid world dimensions")
	if data.terrain.get("height",960)!=960*sections: errors.append("Invalid terrain height")
	if not is_number(data.get("bombs",0)) or data.get("bombs",0)<0 or data.get("bombs",0)>9: errors.append("Invalid bomb count")
	if not is_number(data.world.get("gravity",980)) or data.world.get("gravity",980)<=0: errors.append("Gravity must be positive")
	for pair in [["grid_size",6,16],["brush_radius",25,90]]:
		var value=data.terrain.get(pair[0],10 if pair[0]=="grid_size" else 35)
		if not is_number(value) or value<pair[1] or value>pair[2]: errors.append("Invalid terrain "+pair[0])
	if not data.terrain.get("chambers",[]) is Array: return PackedStringArray(["Terrain chambers must be an array"])
	for chamber in data.terrain.get("chambers",[]):
		if not chamber is Array or chamber.size()!=3:
			errors.append("Chamber must contain x, y, radius")
		else:
			for component in chamber:
				if not is_number(component): errors.append("Chamber coordinates must be numeric")
	if data.kittens.is_empty(): errors.append("A level needs kittens")
	if not is_number(data.mother.get("rescue_radius",80)) or data.mother.get("rescue_radius",80)<35: errors.append("Invalid mother rescue radius")
	var ids: Dictionary={}
	for item in data.kittens+data.obstacles+[data.mother]:
		if not item is Dictionary:
			errors.append("Entity must be an object")
			continue
		var p = item.get("position",[])
		if not p is Array or p.size()!=2:
			errors.append("Entity needs a two-number position")
		elif not (p[0] is float or p[0] is int) or not (p[1] is float or p[1] is int):
			errors.append("Position coordinates must be numbers")
		elif p[0]<30 or p[0]>690 or p[1]<190 or p[1]>1180+960*(sections-1):
			errors.append("Entity position is outside playable bounds")
		var id = item.get("id","")
		if not id is String or id.is_empty() or ids.has(id): errors.append("Missing or duplicate entity ID: " + str(id))
		ids[id]=true
	for obstacle in data.obstacles:
		if not obstacle is Dictionary: continue
		if not TYPES.has(obstacle.get("type","")): errors.append("Unsupported obstacle type")
		for parameter in ["radius","speed","width","distance","force_x","force_y","current","patrol_width","chase_speed","detection_radius","chase_acceleration","patrol_speed","repath_seconds","required_growth","phase_offset"]:
			if obstacle.has(parameter) and not is_number(obstacle[parameter]): errors.append("Obstacle parameter must be numeric: "+parameter)
		for parameter in ["chase_speed","detection_radius","chase_acceleration","repath_seconds"]:
			if obstacle.has(parameter) and is_number(obstacle[parameter]) and obstacle[parameter]<=0: errors.append("Bee chase parameter must be positive: "+parameter)
		if obstacle.has("chase") and not obstacle.chase is bool: errors.append("Bee chase must be a boolean")
		if obstacle.has("radius") and is_number(obstacle.radius) and (obstacle.radius<5 or obstacle.radius>180): errors.append("Obstacle radius out of range")
		for link in ["target","linked_to"]:
			if obstacle.has(link) and not ids.has(obstacle[link]): errors.append("Unresolved link: " + str(obstacle[link]))
		if not obstacle.get("targets",[]) is Array: errors.append("Switch targets must be an array")
		else:
			for target_id in obstacle.get("targets",[]):
				if not ids.has(target_id): errors.append("Unresolved switch target: "+str(target_id))
		for flag in ["exit_only","wait_for_growth"]:
			if obstacle.has(flag) and not obstacle[flag] is bool: errors.append("Portal flag must be boolean")
		if obstacle.get("type","")=="laser":
			var direction=obstacle.get("direction",[])
			if not direction is Array or direction.size()!=2 or not is_number(direction[0]) or not is_number(direction[1]): errors.append("Laser needs a numeric direction")
			elif Vector2(direction[0],direction[1]).length()<0.01: errors.append("Laser direction cannot be zero")
			for key in ["length","warning_seconds","active_seconds","cooldown_seconds"]:
				if not is_number(obstacle.get(key,null)) or obstacle[key]<=0: errors.append("Invalid laser "+key)
	for kitten in data.kittens:
		if kitten is Dictionary:
			var radius = kitten.get("radius",22)
			if not (radius is float or radius is int) or radius<12 or radius>35: errors.append("Invalid kitten radius")
			for parameter in ["mass","gravity_scale","bounce","friction","linear_damping","angular_damping","maximum_speed"]:
				if kitten.has(parameter) and not is_number(kitten[parameter]): errors.append("Kitten parameter must be numeric: "+parameter)
	if data.has("objectives") and not data.objectives is Dictionary: errors.append("Objectives must be an object")
	elif data.has("objectives"):
		for key in ["target_time_seconds","target_dig_distance"]:
			if data.objectives.has(key) and not is_number(data.objectives[key]): errors.append("Objective must be numeric: "+key)
	if data.get("mode","")=="mouse_hunt":
		if data.kittens.size()!=1 or not data.kittens[0].get("mother",false): errors.append("Hunts require one playable Mom Kitty")
		if not data.get("mice",null) is Array or data.mice.is_empty():
			errors.append("Hunts require mice")
		else:
			var available_growth:=0
			for mouse in data.mice:
				if not mouse is Dictionary:
					errors.append("Mouse must be an object")
					continue
				var point=mouse.get("position",[])
				if not point is Array or point.size()!=2 or not is_number(point[0]) or not is_number(point[1]): errors.append("Mouse needs numeric position")
				elif point[0]<30 or point[0]>690 or point[1]<190 or point[1]>1150+960*(sections-1): errors.append("Mouse outside playable area")
				var id: String=mouse.get("id","")
				if id.is_empty() or ids.has(id): errors.append("Missing or duplicate mouse ID")
				ids[id]=true
				for key in ["section","required_growth","growth","radius","flee_speed","escape_distance"]:
					if not is_number(mouse.get(key,null)): errors.append("Mouse needs numeric "+key)
				if not is_number(mouse.get("required_growth",null)) or not is_number(mouse.get("growth",null)): continue
				if mouse.required_growth<0 or mouse.required_growth>available_growth: errors.append("Impossible mouse growth order")
				if mouse.growth<=0: errors.append("Mouse growth must be positive")
				available_growth+=int(mouse.growth)
	return errors

static func is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func check_route(data: Dictionary) -> PackedStringArray:
	var errors:=PackedStringArray()
	var route: Array=data.get("solution",[])
	if route.size()<2: return PackedStringArray(["No candidate rescue route"])
	for i in range(1,route.size()):
		if route[i][1]<route[i-1][1] and not (data.get("endless",false) and route[i-1][1]-route[i][1]<=24): errors.append("Route climbs against gravity")
		var horizontal: float=absf(route[i][0]-route[i-1][0])
		var in_burrow: bool=data.get("mode","")=="mouse_hunt" and (horizontal<=90 or data.get("endless",false))
		if not in_burrow and horizontal>absf(route[i][1]-route[i-1][1])*1.25: errors.append("Route segment too shallow")
	return errors

