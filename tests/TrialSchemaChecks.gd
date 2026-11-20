extends Node
const Trials=preload("res://scripts/generation/TrialLevels.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	for number in range(1,Trials.COUNT+1): check(Trials.validate_source(Trials.read_source(number)).is_empty(),"valid trial schema "+str(number))
	for pair in [[3,1,2],[4,1,3],[5,3,4]]:
		var part: Dictionary=Trials.read_source(pair[0]).sections[pair[1]]
		var group: Dictionary=part.mouse_groups[0]
		var members: Array=part.mice.filter(func(m):return m.get("group_id","")==group.id)
		check(members.size()==pair[2] and members.all(func(m):return m.kind=="SMALL" and m.required_growth==members[0].required_growth),"fair shared pocket with "+str(pair[2])+" edible mice")
	var source:=Trials.read_source(3)
	var invalid:=source.duplicate(true)
	invalid.sections[0].obstacles[0].direction=[0,0]
	check(not Trials.validate_source(invalid).is_empty(),"zero-direction laser is rejected")
	invalid=source.duplicate(true)
	invalid.sections[0].obstacles[1].targets=["missing_laser"]
	check(not Trials.validate_source(invalid).is_empty(),"broken switch references are rejected")
	invalid=source.duplicate(true)
	invalid.sections[0].obstacles.append(invalid.sections[0].obstacles[0].duplicate(true))
	check(not Trials.validate_source(invalid).is_empty(),"duplicate object IDs are rejected")
	invalid=source.duplicate(true)
	invalid.sections[0].camera_center=[0,0]
	check(not Trials.validate_source(invalid).is_empty(),"camera bounds cannot silently load the wrong section")
	invalid=source.duplicate(true)
	invalid.sections[0]=4
	check(not Trials.validate_source(invalid).is_empty(),"malformed section fails cleanly")
	invalid=source.duplicate(true)
	invalid.sections[0].mice[0].position[0]+=20
	check(not Trials.is_verified(invalid),"edited positions invalidate the saved physics proof")
	var copy:=Trials.read_source(1)
	var renamed:=copy.duplicate(true)
	renamed.name="Different title"
	renamed.seed=12345
	for part in renamed.sections:
		for mouse in part.mice: mouse.id="renamed_"+mouse.id
	check(Trials.geometry_signature(copy)==Trials.geometry_signature(renamed),"renaming a layout cannot defeat duplicate detection")
	print("TRIAL SCHEMA RESULT: ",failures," failures")
	get_tree().quit(failures)
