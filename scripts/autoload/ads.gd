extends Node
## Ödüllü (tam ekran) reklam soyutlaması.
## AdMob eklentisi (Android singleton) bulunursa gerçek reklam gösterilir; bulunmazsa
## açıkça "TEST" yazan 5 saniyelik bir simülasyon gösterilir. Gerçek reklam için AdMob
## hesabı ve uygulama/reklam birimi kimlikleri gerekir (docs/ADS.md).

signal reward_done(ok: bool)

var _main: Node = null


func register_main(m: Node) -> void:
	_main = m


func has_real_ads() -> bool:
	return false


func show_rewarded(on_reward: Callable) -> void:
	if _main == null:
		on_reward.call()
		return
	_main.call("show_test_ad", on_reward)
