extends RefCounted
const VERSION:=1
const Trials=preload("res://scripts/generation/TrialLevels.gd")
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const FAMILIES=["Shelf Drop","Opposite Steps","Twin Islands","Long Ramp","Bomb Bridge","laser","bee","rock_switch","portal","water"]
static var memory: Dictionary={}
static var advanced_cache: Dictionary={}
static var module_mutex:=Mutex.new()
static func create(number: int,daily:=false) -> Dictionary:
	number=maxi(1,number)
	var key: String="daily_"+Time.get_date_string_from_system() if daily else str(number)
	if memory.has(key): return memory[key].duplicate(true)
	var result:=build(number,Time.get_date_string_from_system().hash() if daily else number*104729)
	var errors:=Validator.validate(result)
	if not errors.is_empty(): return {"mode":"mouse_hunt","error":"Burrow layout: "+"; ".join(errors)}
	store_prefetched(number,result,daily)
	return result

static func store_prefetched(number: int,result: Dictionary,daily:=false) -> void:
	var key: String="daily_"+Time.get_date_string_from_system() if daily else str(number)
	memory[key]=result.duplicate(true)
	if memory.size()>8: memory.erase(memory.keys()[0])
	var directory:="user://endless_burrows/v%d"%VERSION
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	# JSON is an inspectable local cache. No physics simulation or timing changes
	# run during generation, and player progress lives in its separate save file.
	var file:=FileAccess.open(directory+("/daily.json" if daily else "/slot_%d.json"%posmod(number,8)),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(result,"\t"))

static func build(number: int,seed_value: int,forced_family:=-1,forced_mirror:=-1,forced_screens:=0) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var screens: int=forced_screens if forced_screens>0 else 1 if number<8 else 2 if number<25 else 3 if number<70 else 4 if number<180 else 5
	var pool:=mini(10,4+int(number/4))
	var source: Dictionary={"schema_version":2,"id":"endless_%d"%number,"number":number,"name":"Burrow %d"%number,"seed":seed_value,"bomb_mode":"physical","resources":{"bombs":0},"sections":[],"required_events":[],"instructions":"Dig a safe route around the bricks. Eat small mice first. Land at each base."}
	var growth:=0
	var previous:=-1
	var families: Array=[]
	var bricks: Array=[]
	var start_x:=360.0
	for index in screens:
		var family: int=forced_family if forced_family>=0 else (number-1)%4 if number<=4 and index==0 else posmod(number+int(number/pool)*3+index*7,pool)
		if forced_family<0 and index==0 and number>=5 and number<=25 and (number-5)%4==0: family=mini(9,4+int((number-5)/4))
		if forced_family<0 and family==previous: family=(family+1)%pool
		previous=family
		families.append(family)
		var mirror: bool=forced_mirror==1 if forced_mirror>=0 else rng.randf()>0.5
		if number==1 and forced_mirror<0: mirror=false
		var count: int=2 if number==1 else rng.randi_range(2,4)
		var part: Dictionary=classic_part(family,count,rng) if family<5 else advanced_part(family)
		var shift: float=rng.randi_range(-1,1)*10.0 if family>=5 else 0.0
		if family>=5:
			part.terrain.chambers[-1].radius+=rng.randi_range(0,12)
		if index==0: start_x=720-float(part.start_x)-shift if mirror else float(part.start_x)+shift
		var prefix:="e%d_s%d"%[number,index]
		var shifted: Dictionary=transform(part,"",index*960,mirror,growth,prefix,shift)
		shifted.index=index
		shifted.id=prefix
		shifted.bounds=[30,190+960*index,660,960]
		shifted.camera_center=[360,640+960*index]
		shifted.exit_base=[360,1150+960*index]
		shifted.completion={"eat_all_mice":true,"reach_exit_base":true,"next_section":"e%d_s%d"%[number,index+1] if index+1<screens else null}
		# All later rooms enter from the preceding central base.
		if index>0:
			shifted.terrain.tunnels.append({"points":[[360,1165+960*(index-1)],[shifted.reference_route[0][0],shifted.reference_route[0][1]]],"radius":160})
			shifted.solution_steps.push_front({"points":[[360,1165+960*(index-1)],[shifted.reference_route[0][0],shifted.reference_route[0][1]]]})
		bricks.append_array(shifted.terrain.get("brick_polygons",[]))
		growth+=shifted.mice.size()
		for obstacle in shifted.obstacles:
			if obstacle.type=="bomb": source.resources.bombs+=1
		source.sections.append(shifted)
	var data:=Trials.to_engine(source)
	data.trial=false
	data.endless=true
	data.endless_version=VERSION
	data.start_x=start_x
	data.kittens[0].position[0]=start_x
	data.module_families=families
	data.terrain.solid_polygons=bricks
	data.brick_polygons=bricks.duplicate(true)
	for rect in data.terrain.solid_rects:
		data.brick_polygons.append([[rect[0],rect[1]],[rect[0]+rect[2],rect[1]],[rect[0]+rect[2],rect[1]+rect[3]],[rect[0],rect[1]+rect[3]]])
	data.terrain.brush_radius=84
	return data

static func advanced_part(family: int) -> Dictionary:
	module_mutex.lock()
	if not advanced_cache.has(family):
		advanced_cache[family]=JSON.parse_string(FileAccess.get_file_as_string("res://levels/endless/modules/"+FAMILIES[family]+".json"))
	var part: Dictionary=advanced_cache[family].duplicate(true)
	module_mutex.unlock()
	return part

static func transform(value: Variant,key: String,offset: int,mirror: bool,growth: int,prefix: String,dx:=0.0) -> Variant:
	if key in ["position","entry","exit_base","camera_center"] and value is Array: return [720-value[0]-dx if mirror else value[0]+dx,value[1]+offset]
	if key=="rect": return [720-value[0]-value[2]-dx if mirror else value[0]+dx,value[1]+offset,value[2],value[3]]
	if key in ["points","reference_route"]:
		return value.map(func(p):return [720-p[0]-dx if mirror else p[0]+dx,p[1]+offset])
	if key=="brick_polygons":
		return value.map(func(poly):return poly.map(func(p):return [720-p[0]-dx if mirror else p[0]+dx,p[1]+offset]))
	if key=="required_growth": return int(value)+growth
	if key=="direction" and value is Array: return [-value[0] if mirror else value[0],value[1]]
	if key in ["force_x","current"] and mirror: return -value
	if value is Dictionary:
		var result: Dictionary={}
		for child_key in value: result[child_key]=transform(value[child_key],child_key,offset,mirror,growth,prefix,dx)
		return result
	if value is Array: return value.map(func(item):return transform(item,"",offset,mirror,growth,prefix,dx))
	if value is String: return value.replace("module",prefix)
	return value

static func classic_part(family: int,count: int,rng: RandomNumberGenerator) -> Dictionary:
	var part: Dictionary={"id":"module","name":FAMILIES[family].to_upper(),"index":0,"start_x":150,"terrain":{"chambers":[{"position":[360,240],"radius":105},{"position":[360,1110],"radius":135}],"walls":[],"tunnels":[],"brick_polygons":[]},"mice":[],"obstacles":[],"solution_digs":[],"solution_bomb_digs":[],"solution_bombs":[],"solution_steps":[],"reference_route":[]}
	var jitter:=rng.randi_range(-16,16)
	var lower_y:=rng.randi_range(945,990)
	var approach: Array=[]
	match family:
		0:
			part.terrain.brick_polygons=[[[280,690],[430,690],[690,520],[690,740],[280,740]]]
			part.terrain.tunnels.append({"points":[[150,440],[150,650]],"radius":95})
			add_rock(part,555,440)
			approach=[[150,350],[150,620],[150,810]]
			add_group(part,[435+jitter,lower_y],count,false,approach)
		1:
			part.start_x=550
			part.terrain.brick_polygons=[[[30,540],[340,540],[340,585],[30,585]],[[400,820],[690,680],[690,865],[400,865]]]
			add_rock(part,155,435)
			approach=[[550,350],[550,640],[170,820]]
			add_group(part,[245+jitter,lower_y],count,false,approach)
		2:
			part.terrain.brick_polygons=[[[270,610],[450,610],[450,685],[270,685]]]
			add_rock(part,550,475)
			add_group(part,[145+jitter,500],count,false,[[150,350]])
			add_group(part,[440-jitter,lower_y],1,true,[[150,800]])
		3:
			part.start_x=550
			part.terrain.brick_polygons=[[[30,680],[210,680],[380,900],[30,900]]]
			add_rock(part,120,480)
			add_group(part,[530+jitter,510],count,false,[[550,350]])
			add_group(part,[220-jitter,1010],1,true,[[550,1010]])
		4:
			part.start_x=360
			part.terrain.walls.append({"id":"module_blast_wall","rect":[80,650,560,35],"breakable":true})
			part.terrain.chambers.append({"position":[360,530],"radius":45})
			part.obstacles.append({"id":"module_bomb","type":"bomb","position":[360,530],"radius":25,"blast_radius":145})
			part.solution_bomb_digs.append({"points":[[360,545],[360,655]],"wait_for_bomb":"module_bomb"})
			add_group(part,[435+jitter,475],count,false,[[360,350]])
			add_group(part,[285-jitter,lower_y],1,true,[])
	# A broad, shared collection floor prevents a small mouse remaining on a
	# high side lip after the larger Kitty has already dropped to the base.
	var lower: Array=part.mice.filter(func(m):return m.position[1]>=900)
	if not lower.is_empty():
		var left:=690.0
		var right:=30.0
		for mouse in lower:
			left=minf(left,mouse.position[0]-35)
			right=maxf(right,mouse.position[0]+35)
		part.terrain.tunnels.append({"points":[[left,1060],[right,1060]],"radius":100})
	part.solution_steps.append({"points":[part.mice[-1].position,[360,1140]]})
	part.reference_route.append([360,1140])
	return part

static func add_rock(part: Dictionary,x: float,y: float) -> void:
	part.terrain.chambers.append({"position":[x,y],"radius":58})
	part.obstacles.append({"id":"module_rock","type":"falling_rock","position":[x,y],"radius":30})

static func add_group(part: Dictionary,center: Array,count: int,big: bool,approach: Array) -> void:
	var half: float=(count-1)*27.0
	part.terrain.chambers.append({"position":center,"radius":125 if big else 102})
	if count>1: part.terrain.tunnels.append({"points":[[center[0]-half,center[1]],[center[0]+half,center[1]]],"radius":102})
	var previous: Array=part.mice[-1].position if not part.mice.is_empty() else [part.start_x,350]
	var required: int=part.mice.size() if big else 0
	var group_id:="module_group_%d"%part.mice.size() if count>1 else ""
	for i in count:
		var p: Array=[center[0]-half+i*54,center[1]+(10 if i%2 else 0)]
		var identity:="module_mouse_%d"%part.mice.size()
		part.mice.append({"id":identity,"group_id":group_id,"position":p,"kind":"BIG" if big else "SMALL","radius":35 if big else 22,"growth":1,"required_growth":required,"flee_speed":65,"escape_distance":24})
		var stroke: Array=[previous]
		if i==0: stroke.append_array(approach)
		stroke.append(p)
		part.solution_steps.append({"points":stroke,"wait_for_mouse":identity})
		if i==0: part.reference_route.append_array(approach)
		part.reference_route.append(p)
		previous=p
