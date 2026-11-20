extends Node
class NativeStub extends RefCounted:
	var banners:=false
	var interstitials:=0
	var rewards:=0
	func set_home(value: bool) -> void: banners=value
	func show_interstitial() -> void: interstitials+=1
	func show_rewarded(_token: String) -> void: rewards+=1
var failures:=0
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var native:=NativeStub.new()
	PlatformServices.native=native
	AdsService.initialized=true
	AdsService.no_fill_this_launch=false
	PlatformServices.on_event("remove_ads_price","$4.99")
	PlatformServices.on_event("ads_removed","true")
	check(PlatformServices.ads_removed and PlatformServices.remove_ads_price=="$4.99","native entitlement and real product price update")
	AdsService.home_visible(true)
	for level in 6: AdsService.level_transition()
	check(not native.banners and native.interstitials==0,"owned Remove Ads suppresses banners and interstitials")
	AdsService.on_native_event("ad_loaded","interstitial")
	check(not AdsService.loaded.has("interstitial"),"late interstitial callback cannot restore removed ads")
	AdsService.rewarded_ready=true
	var rewards: Array=[]
	check(AdsService.request_reward(func(): rewards.append(true)) and native.rewards==1,"optional rewarded videos still available")
	AdsService.on_native_event("reward_earned",AdsService.pending_token)
	check(rewards.size()==1,"reward delivered only on earned callback")
	var original:=SaveManager.progress.duplicate(true)
	SaveManager.reset_progress()
	check(PlatformServices.ads_removed,"resetting progress preserves purchase entitlement")
	SaveManager.progress=original
	SaveManager.atomic_save("user://savegame.json",original)
	PlatformServices.on_event("ads_removed","false")
	AdsService.home_visible(true)
	for level in 3: AdsService.level_transition()
	check(native.banners and native.interstitials==1,"revoked entitlement restores normal ad eligibility")
	PlatformServices.native=null
	print("REMOVE ADS RESULT: ",failures," failures")
	get_tree().quit(failures)
