extends RefCounted
const Validator=preload("res://scripts/generation/LevelValidator.gd")
const LayoutHash=preload("res://scripts/generation/LevelGenerator.gd")
const CONTENT_VERSION:=5

# Phase 1 layouts are independent of the rescue campaign. No player save reset.
static func create(number: int,daily:=false) -> Dictionary:
	return preload("res://scripts/generation/EndlessBurrows.gd").create(number,daily)

static func valid_baked_layout(saved: Variant,number: int) -> bool:
	if not saved is Dictionary or saved.get("mode","")!="mouse_hunt" or int(saved.get("number",0))!=number: return false
	if not saved.get("verified",false) or not Validator.validate(saved).is_empty(): return false
	if int(saved.get("hunt_generation_version",0))!=CONTENT_VERSION: return false
	var proof: Dictionary=saved.get("verification",{})
	return proof.get("mechanics_verified",false) and proof.get("idle_start_verified",false) and int(proof.get("mice_eaten",0))==saved.mice.size() and proof.get("blueprint_hash","")==LayoutHash.blueprint_hash(saved)

static func create_prototype(number: int,daily:=false) -> Dictionary:
	var seed_value:=number*7919 if not daily else Time.get_date_string_from_system().hash()
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var count:=1 if number<30 else 2 if number<100 else 3 if number<250 else 4 if number<500 else 5
	var chambers: Array=[[360,300,100]]
	var mice: Array=[]
	var obstacles: Array=[]
	var routes: Array=[]
	var names: Array=[]
	var rocks: Array=[]
	var bombs: Array=[]
	for section in count:
		var y:=section*960
		var side: int=1 if (number+section)%2==0 else -1
		var x:=360+side*(10+int(seed_value%4)*3)
		if section>0: chambers.append([360,200+y,110])
		var route: Array=[[360,310+y] if section==0 else [360,200+y]]
		for i in 3:
			var p: Array=[x if i!=1 else 360-side*14,490+i*265+y]
			chambers.append([p[0],p[1],82 if i<2 else 100])
			mice.append({"id":"mouse_%d_%d"%[section,i],"position":p.duplicate(),"section":section,"kind":"SMALL" if i<2 else "BIG","required_growth":section*3+(0 if i<2 else 2),"growth":1,"radius":15 if i<2 else 27,"flee_speed":38+mini(number,100)*0.3,"escape_distance":20 if number<6 else 30})
			route.append(p.duplicate())
		route.append([360,1140+y] if section<count-1 else [360,1090+y])
		routes.append(route)
		names.append("HUNT %d · SMALL BEFORE BIG"%(section+1))
		chambers.append([360,1100+y,125])
		if number>=3:
			var hx:=590 if side<0 else 130
			chambers.append([hx,650+y,60])
			obstacles.append({"id":"hazard_%d"%section,"type":"spikes" if number%2==0 else "dangerous_plant","position":[hx,650+y],"radius":28})
		if number>=6:
			chambers.append([560,900+y,70])
			obstacles.append({"id":"bee_%d"%section,"type":"bee","position":[560,900+y],"radius":23,"chase_speed":220})
		if number>=10:
			chambers.append([170,870+y,90])
			obstacles.append({"id":"platform_%d"%section,"type":"moving_platform","position":[170,870+y],"width":100,"distance":35,"speed":0.8})
		if number>=15:
			rocks.append([280,360+y,160,35])
			bombs.append([360,380+y])
	return {"schema_version":1,"mode":"mouse_hunt","id":"hunt_%d"%number,"number":number,"name":"Small Before Big" if number<6 else "Mouse Maze %d"%number,"seed":seed_value,"sections":count,"section_names":names,"bombs":bombs.size(),"world":{"width":720,"height":1280+960*(count-1),"gravity":980},"terrain":{"height":960*count,"grid_size":10,"brush_radius":85,"chambers":chambers,"rock_rects":rocks},"kittens":[{"id":"mom_kitty","position":[360,300],"radius":25,"mass":1,"mother":true}],"mother":{"id":"unused_goal","position":[360,1090+960*(count-1)],"rescue_radius":60},"mice":mice,"obstacles":obstacles,"section_solutions":routes,"solution":routes[0],"solution_bombs":bombs,"objectives":{"rescue_all":false,"eat_all":true,"target_time_seconds":count*50,"target_dig_distance":count*1600},"tutorial":"Eat SMALL mice to grow. BIG mice need +2 size first."}
