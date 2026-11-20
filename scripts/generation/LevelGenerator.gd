extends RefCounted

const VERSION:=6

static func recipe_path(number: int) -> String:
	var template_number:=number if number<=1000 else 901+posmod(number-1001,100)
	return "res://levels/campaign/level_%04d.json"%template_number

static func recipe_hash(number: int) -> String:
	var path:=recipe_path(number)
	return FileAccess.get_file_as_string(path).sha256_text() if FileAccess.file_exists(path) else ""

static func candidate(number: int,fixed_seed: int=-1,attempt: int=0) -> Dictionary:
	if number>=30 and fixed_seed<0:
		var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(recipe_path(number)))
		if number>1000:
			recipe.number=number
			recipe.seed=number*71809
			recipe.name="Endless Rescue %d"%number
			recipe.mirror=bool(number%2)
			recipe.layout_offset_x=float(posmod(number*7919,40001))/1000.0-20.0
		var result: Dictionary=preload("res://scripts/generation/CampaignBuilder.gd").build(recipe,long_candidate(29),attempt)
		result.generation_version=VERSION
		result.recipe_hash=recipe_hash(number)
		return result
	if number<=25 and fixed_seed<0: return legacy_candidate(number)
	var rng:=RandomNumberGenerator.new()
	rng.seed=("kitty:%d:%d:%d:%d"%[VERSION,number,fixed_seed,attempt]).hash()
	var safe:=attempt>=4
	var side:=1 if rng.randi_range(0,1)==0 else -1
	var spawn_x:=360+side*rng.randi_range(85,145)
	var mother_x:=360-side*rng.randi_range(75,125)
	var count:=rng.randi_range(2,3 if safe else mini(5,2+int(number/20)))
	var topology:=rng.randi_range(0,7)
	if attempt>=6:
		spawn_x=mother_x
		count=1
		topology=0
	var route: Array=[[spawn_x,345]]
	match topology:
		0: route.append_array([[int((spawn_x+mother_x)/2),670],[mother_x,1030]])
		1,5: route.append_array([[360+side*40,490],[360-side*55,680],[360+side*15,850],[mother_x,1030]])
		2: route.append_array([[360+side*rng.randi_range(95,130),530],[360-side*rng.randi_range(85,115),765],[mother_x,1030]])
		3: route.append_array([[spawn_x,545],[mother_x,810],[mother_x,1030]])
		4,6: route.append_array([[spawn_x-side*70,470],[360+side*40,640],[mother_x+side*65,830],[mother_x,1030]])
		_: route.append_array([[360+side*70,510],[360-side*70,725],[mother_x,1030]])
	var kittens: Array=[]
	for i in count:
		var x:=spawn_x+((i%3)-1)*56 if count>=3 else spawn_x+(i*2-1)*29
		if i>=3: x=spawn_x+(i*2-7)*28
		kittens.append({"id":"kitten_%d"%i,"variant":(i+number)%6,"position":[x,300+(i/3)*56],"radius":29,"mass":1.0})
	var chambers: Array=[[spawn_x,330,120],[mother_x,1030,126]]
	var obstacles: Array=[]
	var tunnels: Array=[]
	if not safe:
		var hazard_x:=112 if side>0 else 608
		var hazard_y:=rng.randi_range(540,700)
		chambers.append([hazard_x,hazard_y,64])
		tunnels.append({"points":[[hazard_x,hazard_y-80],[hazard_x-side*15,hazard_y+60],[hazard_x+side*35,hazard_y+130]],"radius":39})
		var hazard: String=["bee","spikes","dangerous_plant","falling_rock"][rng.randi_range(0,3)]
		obstacles.append({"id":"hazard","type":hazard,"position":[hazard_x,hazard_y],"radius":24 if hazard=="bee" else 32,"chase_speed":rng.randi_range(220,250)})
		if topology in [1,2,4,5,7]:
			var wheel_point: Array=route[mini(2,route.size()-2)]
			var wheel_radius:=rng.randi_range(65,96)
			chambers.append([wheel_point[0],wheel_point[1],wheel_radius+47])
			obstacles.append({"id":"wheel","type":"rotating_wheel","position":wheel_point.duplicate(),"radius":wheel_radius,"speed":rng.randf_range(0.35,0.75)*side,"interactive":true})
		if topology in [3,6]:
			chambers.append([route[1][0],route[1][1],103])
			chambers.append([route[2][0],route[2][1],98])
	var names: Array=["Golden Descent","The Winding Way","Sweeping Sands","Hidden Chambers","A Helping Turn","Round We Go","Secret Caverns","Homeward Bound"]
	return {"schema_version":1,"id":"level_%03d"%number,"number":number,"name":names[topology],"difficulty":"medium" if count<4 else "hard","seed":rng.seed,"generation_version":VERSION,"topology":topology,"verified":false,"world":{"width":720,"height":1280,"gravity":980},"terrain":{"grid_size":8,"brush_radius":90,"chambers":chambers,"tunnels":tunnels,"rock_rects":[]},"kittens":kittens,"mother":{"id":"mom","position":[mother_x,1030],"rescue_radius":97},"obstacles":obstacles,"solution":route,"objectives":{"rescue_all":true,"target_time_seconds":65,"target_dig_distance":1550},"tutorial":"Dig a safe way home. Bees chase through open tunnels!","decorations":[{"sprite":1,"x":350,"y":405,"size":34},{"sprite":1,"x":600,"y":960,"size":43},{"sprite":2,"x":640,"y":213,"size":64}]}

static func blueprint_hash(data: Dictionary) -> String:
	var blueprint:=data.duplicate(true)
	blueprint.erase("verified")
	blueprint.erase("verification")
	# JSON parses all numbers as floats. Normalize once before hashing so the
	# proof survives an int -> JSON -> float round trip without changing layout.
	var canonical=JSON.parse_string(JSON.stringify(blueprint))
	return JSON.stringify(canonical).sha256_text()

static func legacy_candidate(number: int, fixed_seed: int = -1) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	rng.seed=number*7919 if fixed_seed<0 else fixed_seed
	var side:=1 if number%2==0 else -1
	var spawn_x:=360+side*rng.randi_range(100,170)
	var mother_x:=360-side*rng.randi_range(90,140)
	var count:=mini(5,1+int(number/25))
	var kittens:=[]
	for i in count:
		kittens.append({"id":"kitten_%d"%i,"variant":i%6,"position":[spawn_x+(i%2)*46-23,290-(i/2)*44],"radius":21,"mass":1.0})
	var route: Array=[[spawn_x,300],[360+side*55,540],[360-side*45,790],[mother_x,1060]]
	var data: Dictionary={"schema_version":1,"id":"level_%03d"%number,"name":"Sandy Beginnings","seed":rng.seed,"number":number,"difficulty":"easy" if number<=20 else "medium","verified":false,"world":{"width":720,"height":1280,"gravity":980},"terrain":{"grid_size":10,"brush_radius":60,"chambers":[[spawn_x,260,110],[mother_x,1070,100]],"rock_rects":[]},"kittens":kittens,"mother":{"id":"mom","position":[mother_x,1070],"rescue_radius":83},"obstacles":[],"solution":route,"objectives":{"rescue_all":true,"target_time_seconds":45,"target_dig_distance":1200}}
	if number>5:
		data.name=["Curving Caverns","A Little Detour","Golden Descent","Homeward Bound"][number%4]
		var hazard_x:=150 if side>0 else 580
		data.terrain.chambers.append([hazard_x,640,65])
		data.obstacles.append({"id":"hazard","type":["bee","spikes","dangerous_plant"][number%3],"position":[hazard_x,640],"radius":25})
		if number>40: data.obstacles.append({"id":"wheel","type":"rotating_wheel","position":[360+side*55,560],"radius":76,"speed":0.45,"interactive":true})
	return data


static func advanced_candidate(number: int) -> Dictionary:
	if number>=28: return long_candidate(number)
	var sections:=3 if number>=60 or number==27 else 2
	var chambers: Array=[[360,300,120]]
	var stones: Array=[]
	var routes: Array=[]
	var bombs: Array=[]
	for section in sections:
		var offset:=960*section
		chambers.append([360,1100+offset,110])
		if section>0: chambers.append([360,1200+offset-960,105])
		stones.append([270,680+offset,180,45])
		bombs.append([360,700+offset])
		routes.append([[360,310+offset] if section==0 else [360,200+offset],[360,650+offset],[360,850+offset],[360,1140+offset] if section<sections-1 else [360,1030+offset]])
	var final_y:=1030+960*(sections-1)
	chambers.append([360,final_y,125])
	chambers.append([135,790,70])
	chambers.append([565,500,80])
	chambers.append([565,850,75])
	return {"schema_version":1,"id":"level_%03d"%number,"number":number,"name":"Deep Stone Rescue","difficulty":"hard","sections":sections,"bombs":sections+1,"world":{"width":720,"height":1280+960*(sections-1),"gravity":980},"terrain":{"height":960*sections,"grid_size":10,"brush_radius":75,"chambers":chambers,"rock_rects":stones,"tunnels":[{"points":[[565,610],[565,850]],"radius":58}]},"kittens":[{"id":"baby_a","position":[333,300],"radius":27,"variant":0},{"id":"baby_b","position":[387,300],"radius":27,"variant":1}],"mother":{"id":"mom","position":[360,final_y],"rescue_radius":95},"obstacles":[{"id":"bee_left","type":"bee","position":[135,790],"radius":24},{"id":"stone","type":"falling_rock","position":[565,500],"radius":36},{"id":"bee_stone","type":"bee","position":[565,850],"radius":24}],"section_solutions":routes,"solution_bombs":bombs,"solution":routes[0],"objectives":{"rescue_all":true,"target_time_seconds":120,"target_dig_distance":3500},"tutorial":"Tap the bomb, then stone to blast. Drop rocks onto bees!"}

static func long_candidate(number: int) -> Dictionary:
	var sections:=5 if number==29 or number>=60 else 4
	var chambers: Array=[[360,300,120]]
	var tunnels: Array=[]
	var stones: Array=[]
	var routes: Array=[]
	var bombs: Array=[]
	var obstacles: Array=[]
	var digs: Array=[]
	var names: Array=["SWITCHBACK GATE","ROLLING MACHINE","DROP THE STONE","MOVING CATCH","TIMED GARDEN"]
	for section in sections:
		var y:=960*section
		if section>0: chambers.append([360,200+y,110])
		chambers.append([360,1100+y,120])
		if section<3:
			stones.append([270,530+y,180,45])
			bombs.append([360,550+y])
		var start: Array=[360,310+y] if section==0 else [360,200+y]
		match section:
			0:
				chambers.append_array([[360,700,100],[360,820,110]])
				obstacles.append_array([{"id":"switch_0","type":"pressure_switch","position":[360,700],"radius":45,"target":"gate_0"},{"id":"gate_0","type":"gate","position":[360,820],"radius":25,"width":500}])
				routes.append([start,[360,650],[360,735],[360,950],[360,1140]])
			1:
				chambers.append([360,700+y,155])
				tunnels.append({"points":[[360,730+y],[360,940+y]],"radius":110})
				obstacles.append({"id":"wheel_1","type":"rotating_wheel","position":[360,700+y],"radius":74,"speed":0.8+float(number%997)*0.0001,"interactive":true})
				routes.append([start,[360,620+y],[360,800+y],[360,1000+y],[360,1140+y]])
			2:
				var rock_x:=548+(number%11)*2
				chambers.append_array([[rock_x,500+y,80],[rock_x,850+y,78]])
				tunnels.append({"points":[[rock_x,610+y],[rock_x,850+y]],"radius":55})
				obstacles.append_array([{"id":"trap_stone","type":"falling_rock","position":[rock_x,500+y],"radius":36},{"id":"trap_bee","type":"bee","position":[rock_x,850+y],"radius":24}])
				digs.append({"section":section,"points":[[rock_x,570+y],[rock_x,850+y]],"wait_ticks":120})
				routes.append([start,[360,650+y],[360,870+y],[360,1140+y]])
			3:
				chambers.append_array([[450,700+y,140],[230,840+y,105],[570,845+y,60]])
				tunnels.append({"points":[[230,820+y],[360,1050+y]],"radius":100})
				obstacles.append_array([{"id":"platform_3","type":"moving_platform","position":[450,700+y],"radius":30,"width":140,"distance":45},{"id":"plant_3","type":"dangerous_plant","position":[570,845+y],"radius":32}])
				routes.append([start,[240,450+y],[215,740+y],[240,930+y],[360,1140+y] if section<sections-1 else [360,1030+y]])
			4:
				chambers.append_array([[255,740+y,100],[360,850+y,115],[460,650+y,75]])
				obstacles.append_array([{"id":"plant_4","type":"dangerous_plant","position":[460,650+y],"radius":33},{"id":"switch_4","type":"pressure_switch","position":[255,740+y],"radius":43,"target":"gate_4"},{"id":"gate_4","type":"gate","position":[360,850+y],"radius":25,"width":500}])
				routes.append([start,[280,460+y],[255,740+y],[285,930+y],[360,1030+y]])
	var final_y:=1030+960*(sections-1)
	chambers.append([360,final_y,130])
	return {"schema_version":1,"id":"level_%03d"%number,"number":number,"name":"The Deep Rescue Trail","difficulty":"hard","sections":sections,"section_names":names.slice(0,sections),"bombs":5,"world":{"width":720,"height":1280+960*(sections-1),"gravity":980},"terrain":{"height":960*sections,"grid_size":10,"brush_radius":75,"chambers":chambers,"rock_rects":stones,"tunnels":tunnels},"kittens":[{"id":"baby_a","position":[333,300],"radius":27,"variant":number%6},{"id":"baby_b","position":[387,300],"radius":27,"variant":(number+1)%6}],"mother":{"id":"mom","position":[360,final_y],"rescue_radius":95},"obstacles":obstacles,"section_solutions":routes,"solution_bombs":bombs,"solution_digs":digs,"solution":routes[0],"objectives":{"rescue_all":true,"target_time_seconds":180,"target_dig_distance":6000},"tutorial":"Gather at each base. Switches open gates; stones stop bees."}
