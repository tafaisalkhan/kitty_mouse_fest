extends Node2D
var failures:=0
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures+=1
func _ready() -> void:
 call_deferred("run")
func run() -> void:
 var tilt=preload("res://scripts/gameplay/TiltControl.gd").new()
 var axis:=0.0
 for i in 60: axis=tilt.sample(Vector3(-4,8,3),Vector3.ZERO,1.0/60.0)
 check(axis>0.8,"Right tilt steers right")
 for i in 60: axis=tilt.sample(Vector3(4,8,3),Vector3.ZERO,1.0/60.0)
 check(axis< -0.8,"Left tilt steers left")
 for i in 90: axis=tilt.sample(Vector3(0.1,9.8,0),Vector3.ZERO,1.0/60.0)
 check(axis==0,"Neutral dead zone suppresses jitter")
 tilt.reset()
 for i in 60: axis=tilt.sample(Vector3.ZERO,Vector3(-4,8,3),1.0/60.0)
 check(axis>0.8,"Accelerometer fallback")
 tilt.reset()
 check(tilt.sample(Vector3.ZERO,Vector3.ZERO,0.1)==0 and not tilt.available,"No sensor means no drift")
 var terrain=preload("res://scripts/gameplay/SandTerrain.gd").new()
 add_child(terrain)
 terrain.setup({"brush_radius":28,"solid_rects":[[400,400,40,40]]})
 terrain._process(0.1)
 var removed: int=terrain.dig_segment(Vector2(200,400),Vector2(300,500))
 terrain.rebuild()
 check(removed>0 and terrain.cut_blend==0,"Cut starts a visual transition")
 check(terrain.circle_is_empty(Vector2(250,450),10),"Collision clears immediately under the stroke")
 terrain._process(0.03)
 check(terrain.cut_blend>0 and terrain.cut_blend<1,"Cut interpolates across frames")
 terrain._process(0.1)
 check(terrain.cut_blend==1,"Cut finishes promptly")
 check(not terrain.circle_is_empty(Vector2(420,420),5),"Solid wall survives digging")
 check(AudioManager.effect_streams.dig.resource_path.ends_with("sand_remove.wav"),"Dig uses sand scrape recording")
 terrain.queue_free()
 await get_tree().process_frame
 print("TILT AND SAND FAILURES ",failures)
 get_tree().quit(failures)
