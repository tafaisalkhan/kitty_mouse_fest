extends Node
signal service_event(kind: String,payload: String)
var native: Object
var coffee_price:=""
var remove_ads_price:=""
var pack_prices: Dictionary={}
var ads_removed:=false
var commerce_started:=false
var updates_checked:=false
var update_available:=false
var update_downloaded:=false
var update_prompts: Dictionary={}

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_RESUMED: call_deferred("route_daily_intent")

func route_daily_intent() -> void:
	var scene:=get_tree().current_scene
	if not native or not is_instance_valid(scene) or scene.scene_file_path.ends_with("Boot.tscn"): return
	if native.take_daily_launch():
		AdsService.home_visible(false)
		SaveManager.daily_mode=true
		SaveManager.level_number=25
		get_tree().paused=false
		get_tree().change_scene_to_file("res://scenes/gameplay/Gameplay.tscn")

func _ready() -> void:
	if Engine.has_singleton("KittyServices"):
		native=Engine.get_singleton("KittyServices")
		native.service_event.connect(on_event)
		ads_removed=native.ads_removed()

func on_event(kind: String,payload: String) -> void:
	if kind=="notification_denied":
		SaveManager.settings.challenge_notifications=false
		SaveManager.save_settings()
		service_event.emit("message",payload)
	if kind=="coffee_price": coffee_price=payload
	if kind=="remove_ads_price": remove_ads_price=payload
	if kind=="pack_price":
		var parts:=payload.split(":",false,1)
		if parts.size()==2: pack_prices[parts[0]]=parts[1]
	if kind=="coins_purchased":
		var parts:=payload.split(":",false,1)
		var amount:=int(parts[1]) if parts.size()==2 else int(payload)
		if amount>0: Economy.add_coins(amount)
		service_event.emit("coins_purchased",str(amount))
		return
	if kind=="ads_removed": ads_removed=payload=="true"
	if kind=="update_available": update_available=true
	if kind=="update_downloaded": update_downloaded=true
	service_event.emit(kind,payload)

func enter_home() -> void:
	if not native: return
	if not commerce_started:
		commerce_started=true
		native.start_commerce()
	if not updates_checked:
		updates_checked=true
		native.check_updates()
	if SaveManager.settings.get("challenge_notifications",false): update_notification(true)

func rate_game() -> void:
	if native: native.rate_game()
	else: OS.shell_open(store_url())

func share_game() -> void:
	if native: native.share_game()
	else:
		DisplayServer.clipboard_set(store_url())
		service_event.emit("message","Game link copied to clipboard.")

func buy_coin_pack(pack_id: String) -> void:
	if native: native.buy_product(pack_id)
	else: service_event.emit("message","Coin packs are available via Google Play test/release builds.")

func buy_coffee() -> void:
	if native: native.buy_coffee()
	else: service_event.emit("message","Coffee purchases are available in the Google Play version.")

func buy_remove_ads() -> void:
	if ads_removed: return
	if native: native.buy_remove_ads()
	else: service_event.emit("message","Remove Ads is available in the Google Play version.")

func restore_purchases() -> void:
	if native: native.restore_purchases()
	else: service_event.emit("message","Open the Google Play version to check pending purchases.")

func update_notification(enabled: bool) -> void:
	SaveManager.settings.challenge_notifications=enabled
	SaveManager.save_settings()
	if native: native.set_challenge_notification(enabled,Economy.daily_status().reward)

func store_url() -> String:
	return "https://play.google.com/store/apps/details?id=com.kittyrescue.digtomom"
