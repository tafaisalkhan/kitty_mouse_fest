extends Node
signal availability_changed
signal reward_finished(success: bool)
var no_fill_this_launch:=false
var initialized:=false
var rewarded_ready:=false
var loaded: Dictionary={}
var pending: Callable
var pending_token:=""
var request_serial:=0
var completed_rounds:=0

func _ready() -> void:
	PlatformServices.service_event.connect(on_native_event)

func initialize() -> void:
	if initialized: return
	initialized=true
	var native:=PlatformServices.native
	if not native or not native.ads_configured():
		mark_no_fill()
		return
	# IDs are supplied only by the generated, untracked native asset.
	native.initialize_ads(native.read_ad_units())

func mark_no_fill() -> void:
	no_fill_this_launch=true
	rewarded_ready=false
	loaded.clear()
	if PlatformServices.native: PlatformServices.native.stop_ads()
	availability_changed.emit()
	if pending.is_valid(): deliver_pending()

func on_native_event(kind: String,payload: String) -> void:
	if kind=="ads_removed":
		loaded.erase("banner")
		loaded.erase("interstitial")
		availability_changed.emit()
	elif kind=="ad_failed": mark_no_fill()
	elif kind=="ad_loaded" and not no_fill_this_launch:
		if PlatformServices.ads_removed and payload in ["banner","interstitial"]: return
		loaded[payload]=true
		if payload=="rewarded": rewarded_ready=true
		availability_changed.emit()
	elif kind=="reward_earned" and payload==pending_token: deliver_pending()
	elif kind in ["reward_closed","reward_not_ready"] and payload==pending_token:
		pending=Callable()
		pending_token=""
		reward_finished.emit(false)

func request_reward(action: Callable) -> bool:
	initialize()
	if pending.is_valid(): return false
	if no_fill_this_launch or not rewarded_ready:
		return false
	request_serial+=1
	pending_token="reward_%d"%request_serial
	pending=action
	rewarded_ready=false
	PlatformServices.native.show_rewarded(pending_token)
	availability_changed.emit()
	return true

func deliver_pending() -> void:
	var action:=pending
	pending=Callable()
	pending_token=""
	if action.is_valid():
		action.call()
		reward_finished.emit(true)

func home_visible(value: bool) -> void:
	if value: initialize()
	if PlatformServices.native: PlatformServices.native.set_home(value and not no_fill_this_launch and not PlatformServices.ads_removed)

func level_transition() -> void:
	completed_rounds+=1
	if completed_rounds%3==0 and not no_fill_this_launch and not PlatformServices.ads_removed and PlatformServices.native:
		PlatformServices.native.show_interstitial()
