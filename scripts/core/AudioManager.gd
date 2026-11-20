extends Node

var music: AudioStreamPlayer
const SOUND_FILES := {
	"dig":"sand_remove.wav", "win":"level_complete.mp3", "fail":"level_fail.mp3",
	"star":"star_sound.mp3", "coin":"coin_sound.wav",
	"cat":"cat_sound.mp3", "mouse":"mouse_sound.mp3",
	"mouse_die":"mouse_die.wav", "eat":"cat_eat_mouse.mp3",
	"eat_big":"cat_eat_last_mouse.wav", "start":"right_answer.mp3",
	"click":"right_answer.mp3", "wrong":"wrong_answer.mp3"
}
const MAX_EFFECT_VOICES:=12
const MUSIC_NOTES: Array=[261.63,329.63,392.0,523.25,440.0,392.0,329.63,293.66,261.63,329.63,392.0,587.33,523.25,392.0,329.63,293.66]
const FREQUENCIES: Dictionary={"click":660.0,"dig":120.0,"rescue":880.0,"win":1046.0,"fail":180.0,"bounce":300.0,"boom":65.0}
const COOLDOWNS: Dictionary={"click":45,"dig":120,"bounce":75,"cat":7000,"mouse":4500,"mouse_die":180,"eat":180,"eat_big":180,"start":500}
var effect_streams: Dictionary={}
var effect_voices: Array[AudioStreamPlayer]=[]
var last_played: Dictionary={}
var voice_cursor:=0

func _ready() -> void:
	for title in ["Music", "Effects"]:
		if AudioServer.get_bus_index(title) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, title)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	music.stream = load("res://assets/sound/backgroud_music.mp3").duplicate()
	music.stream.loop = true
	music.volume_db = -16.0
	music.play()
	for kind in FREQUENCIES:
		effect_streams[kind]=tone(FREQUENCIES[kind],0.07 if kind=="dig" else 0.28)
	for kind in SOUND_FILES:
		var path: String="res://assets/sound/"+SOUND_FILES[kind]
		if ResourceLoader.exists(path): effect_streams[kind]=load(path)
	for i in MAX_EFFECT_VOICES:
		var voice:=AudioStreamPlayer.new()
		voice.name="EffectVoice%d"%i
		voice.bus="Effects"
		voice.volume_db=-6.0
		add_child(voice)
		effect_voices.append(voice)
	apply_settings()

func apply_settings() -> void:
	for pair in [["Music","music","music_volume"],["Effects","effects","effects_volume"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index >= 0:
			AudioServer.set_bus_mute(index, not SaveManager.settings[pair[1]])
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, float(SaveManager.settings[pair[2]]))))

func tone(frequency: float, duration: float, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	var rate := 22050
	bytes.resize(int(rate * duration) * 2)
	for i in range(int(rate * duration)):
		var t := float(i) / rate
		var envelope := 0.13 if looped else 0.3 * pow(1.0-t/duration, 2)
		var sample := sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 1.5 * t)
		if looped:
			var note: float=MUSIC_NOTES[int(t*2)%MUSIC_NOTES.size()]
			var beat:=fmod(t,0.5)
			sample=(sin(TAU*note*t)+0.25*sin(TAU*note*2*t))*exp(-beat*8)*minf(1,beat*70)
			sample+=sin(TAU*130.815*t)*0.12
		bytes.encode_s16(i*2, int(sample * envelope * 16000))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.data = bytes
	if looped:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		# Keep the loop endpoint inside the PCM buffer. Godot's WAV mixer
		# can decode the endpoint itself, so frame_count reads past the data.
		wave.loop_end = int(rate * duration) - 1
	return wave

func play_fx(kind := "click", pitch := 1.0) -> void:
	if not SaveManager.settings.get("effects",true) or effect_voices.is_empty(): return
	var now:=Time.get_ticks_msec()
	if now-int(last_played.get(kind,-1000))<int(COOLDOWNS.get(kind,0)): return
	last_played[kind]=now
	var player: AudioStreamPlayer=effect_voices[voice_cursor]
	for offset in effect_voices.size():
		var index: int=(voice_cursor+offset)%effect_voices.size()
		if not effect_voices[index].playing:
			player=effect_voices[index]
			voice_cursor=index
			break
	voice_cursor=(voice_cursor+1)%effect_voices.size()
	# A lost audio device may prevent "finished" from firing. Reuse a bounded
	# pool regardless of playback completion instead of allocating new nodes.
	player.stop()
	player.stream=effect_streams.get(kind,effect_streams.click)
	player.pitch_scale=clampf(pitch,0.8,1.2)
	player.volume_db=-10.0 if kind in ["cat","mouse"] else -6.0
	player.play()

