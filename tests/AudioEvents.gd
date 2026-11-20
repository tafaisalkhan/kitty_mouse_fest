extends Node
var failures:=0
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures+=1
func _ready() -> void:
 call_deferred("run")
func run() -> void:
 check(AudioManager.music.stream is AudioStreamMP3,"Recorded background music loaded")
 check(AudioManager.music.stream.loop,"Music loops")
 for kind in AudioManager.SOUND_FILES:
  check(AudioManager.effect_streams.has(kind),"Recorded event: "+kind)
  if AudioManager.effect_streams.has(kind):
   check(AudioManager.effect_streams[kind].get_length()>0,"Nonempty sound: "+kind)
 for kind in ["start","cat","mouse","mouse_die","eat","eat_big","coin","win","fail"]:
  AudioManager.play_fx(kind)
 check(AudioManager.effect_voices.size()==12,"Bounded voice pool")
 var game=load("res://scripts/gameplay/HuntGameplay.gd").new()
 game.test_mode=true
 game.level_override=preload("res://scripts/generation/HuntLevels.gd").create(1,false)
 add_child(game)
 await get_tree().process_frame
 AudioManager.last_played.erase("mouse_die")
 AudioManager.last_played.erase("eat")
 var mouse=game.mice[0]
 game.resolve_mouse(mouse)
 await get_tree().create_timer(0.2).timeout
 check(AudioManager.last_played.has("mouse_die"),"Capture sound triggered")
 check(AudioManager.last_played.has("eat"),"Small mouse eating sound triggered")
 AudioManager.last_played.erase("eat_big")
 game.resolve_mouse(game.mice[1])
 await get_tree().create_timer(0.2).timeout
 check(AudioManager.last_played.has("eat_big"),"Final mouse eating sound triggered")
 game.queue_free()
 await get_tree().process_frame
 await get_tree().create_timer(0.25).timeout
 print("AUDIO FAILURES ",failures)
 get_tree().quit(failures)
