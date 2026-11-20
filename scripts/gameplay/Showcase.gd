extends "res://scripts/gameplay/Gameplay.gd"

func _ready() -> void:
	SaveManager.level_number=6
	SaveManager.daily_mode=false
	super._ready()
