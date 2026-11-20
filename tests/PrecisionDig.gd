extends Node
const Terrain=preload("res://scripts/gameplay/SandTerrain.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func make_terrain(brush: float):
	var terrain:=Terrain.new()
	terrain.render_visuals=false
	add_child(terrain)
	terrain.setup({"brush_radius":brush,"rock_rects":[[300,380,40,40]]})
	return terrain
func _ready() -> void:
	var precise=make_terrain(28)
	var old=make_terrain(84)
	var narrow_count: int=precise.dig_segment(Vector2(200,400),Vector2(450,400))
	var old_count: int=old.dig_segment(Vector2(200,400),Vector2(450,400))
	check(narrow_count>0 and narrow_count<old_count*0.45,"same drag removes less than half the previous sand")
	var outside:=false
	var stone_count:=0
	for row in precise.ROWS:
		for column in precise.COLS:
			var cell: int=precise.cells[row*precise.COLS+column]
			if cell==2: stone_count+=1
			if cell==0 and absf(precise.position.y+row*precise.CELL+precise.CELL*0.5-400)>28: outside=true
	check(not outside,"digging stays within the narrow stroke footprint")
	check(stone_count==16,"ordinary digging preserves stone")
	var continuous:=true
	for x in range(200,451,10):
		if x>=300 and x<=340: continue
		continuous=continuous and precise.cells[21*precise.COLS+int((x-30)/10)]==0
	check(continuous,"fast drag remains continuous without gaps")
	var tap=make_terrain(28)
	var tap_count: int=tap.dig_segment(Vector2(200,400),Vector2(200,400))
	check(tap_count>0 and tap_count<40,"one touch removes a small patch instead of a chamber")
	print("PRECISION DIG RESULT: ",failures," failures")
	get_tree().quit(failures)
