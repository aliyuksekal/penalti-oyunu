extends Node
## Gerçek AdMob bağlantısı (Poing Studios AdMob eklentisi v5.1).
## Sadece Android'de, eklenti yüklüyse AdService tarafından oluşturulur; masaüstünde/testte hiç yüklenmez.
##
## Reklam birimi kimlikleri AdService.gd içindeki AD_UNITS'ten gelir.

signal status_changed

var interstitial_id: String = ""
var rewarded_id: String = ""
var banner_id: String = ""
var _banner: AdView
var _banner_want: bool = false
var banner_loaded: bool = false

var _inter: InterstitialAd
var _reward: RewardedAd
var _inter_loading: bool = false
var _reward_loading: bool = false
var _retry_inter: float = 0.0
var _retry_reward: float = 0.0
var _consent_form: ConsentForm


func start(inter_id: String, reward_id: String, ban_id: String = "") -> void:
	interstitial_id = inter_id
	rewarded_id = reward_id
	banner_id = ban_id
	_request_consent()


# ---------------- KVKK/GDPR izni (Google UMP) ----------------
func _request_consent() -> void:
	var req := ConsentRequestParameters.new()
	req.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(req, _on_consent_updated, _on_consent_failed)


func _on_consent_updated() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available() \
			and UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_consent_failed)
	else:
		_init_ads()


func _on_form_loaded(form: ConsentForm) -> void:
	_consent_form = form
	form.show(func(_err: FormError) -> void: _init_ads())


func _on_consent_failed(_err: FormError) -> void:
	_init_ads()   # izin ekranı açılamadıysa yine de (kişiselleştirilmemiş) reklamlarla devam


func _init_ads() -> void:
	var done := OnInitializationCompleteListener.new()
	done.on_initialization_complete = func(_s: InitializationStatus) -> void:
		_load_inter()
		_load_reward()
		_make_banner()
	MobileAds.initialize(done)


# ---------------- yükleme ----------------
func _process(delta: float) -> void:
	if _retry_inter > 0.0:
		_retry_inter -= delta
		if _retry_inter <= 0.0:
			_load_inter()
	if _retry_reward > 0.0:
		_retry_reward -= delta
		if _retry_reward <= 0.0:
			_load_reward()


func _load_inter() -> void:
	if _inter != null or _inter_loading or interstitial_id == "":
		return
	_inter_loading = true
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_inter_loading = false
		_inter = ad
		status_changed.emit()
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_inter_loading = false
		_retry_inter = 30.0
	InterstitialAdLoader.new().load(interstitial_id, AdRequest.new(), cb)


func _load_reward() -> void:
	if _reward != null or _reward_loading or rewarded_id == "":
		return
	_reward_loading = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_reward_loading = false
		_reward = ad
		status_changed.emit()
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_reward_loading = false
		_retry_reward = 20.0
	RewardedAdLoader.new().load(rewarded_id, AdRequest.new(), cb)


func has_rewarded() -> bool:
	return _reward != null


func has_interstitial() -> bool:
	return _inter != null


func ensure_rewarded() -> void:
	_retry_reward = 0.0
	_load_reward()


# ---------------- gösterme ----------------
## Tam ekran reklam: yoksa hemen done (oyuncu bekletilmez)
func show_interstitial(done: Callable) -> void:
	if _inter == null:
		_load_inter()
		done.call()
		return
	var ad: InterstitialAd = _inter
	_inter = null
	var once := {"v": false}
	var finish := func() -> void:
		if once["v"]:
			return
		once["v"] = true
		ad.destroy()
		_load_inter()
		done.call()
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = finish
	fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: finish.call()
	ad.full_screen_content_callback = fs
	ad.show()


## Ödüllü reklam: sonuna kadar izlenip kapatılınca on_reward, değilse on_cancel
func show_rewarded(on_reward: Callable, on_cancel: Callable) -> bool:
	if _reward == null:
		_load_reward()
		return false
	var ad: RewardedAd = _reward
	_reward = null
	var st := {"earned": false, "done": false}
	var finish := func() -> void:
		if st["done"]:
			return
		st["done"] = true
		ad.destroy()
		_load_reward()
		if st["earned"]:
			on_reward.call()
		elif on_cancel.is_valid():
			on_cancel.call()
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = finish
	fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: finish.call()
	ad.full_screen_content_callback = fs
	var earn := OnUserEarnedRewardListener.new()
	earn.on_user_earned_reward = func(_item: RewardedItem) -> void:
		st["earned"] = true
	ad.show(earn)
	return true



# ---------------- banner (alt orta, küçük 320x50) ----------------
## Banner oluşturulur oluşturulmaz "var" sayılır: yerleşim onun yüklenmesini beklemez
## (bazı telefonlarda "yüklendi" bildirimi gelmiyor, tuşlar reklamın altında kalıyordu).
func _make_banner() -> void:
	if banner_id == "" or _banner != null:
		return
	_banner = AdView.new(banner_id, AdSize.BANNER, AdPosition.BOTTOM)
	_banner.ad_listener.on_ad_loaded = func() -> void:
		banner_loaded = true
		print("[reklam] banner yüklendi: %dx%d px" % [_banner.get_width_in_pixels(), _banner.get_height_in_pixels()])
		if _banner_want:
			_banner.show()
		else:
			_banner.hide()
		status_changed.emit()
	_banner.ad_listener.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		banner_loaded = false
		print("[reklam] banner yüklenemedi: %s" % str(e.message if e != null else ""))
	_banner.load_ad(AdRequest.new())
	print("[reklam] banner istendi")
	if not _banner_want:
		_banner.hide()
	status_changed.emit()


func set_banner(on: bool) -> void:
	_banner_want = on
	if _banner == null:
		return
	if on:
		_banner.show()
	else:
		_banner.hide()


## Banner ekranda yer kaplıyor mu (oluşturuldu ve isteniyor)
func banner_present() -> bool:
	return _banner != null and _banner_want


## Banner boyutu (ekran pikseli). Eklenti söylemezse 0x0 döner; o zaman dp'den hesaplanır.
func banner_px() -> Vector2i:
	if _banner == null:
		return Vector2i.ZERO
	var w: int = _banner.get_width_in_pixels()
	var h: int = _banner.get_height_in_pixels()
	if w > 0 and h > 0:
		return Vector2i(w, h)
	return Vector2i.ZERO
