extends Node
## Forma tanımları: yalnızca renk ve desen (gerçek takım adı/arma yok).
## pattern: 0 = yarım yarım (dikey ikiye bölünmüş), 1 = dikey çubuklu

const ORDER: Array[String] = ["red_yellow", "yellow_navy", "black_white", "claret_blue"]
const KITS := {
	"red_yellow": {"a": Color("c8102e"), "b": Color("fdb913"), "pattern": 0, "shorts": Color("c8102e"), "socks": Color("c8102e"), "trim": Color("fdb913")},
	"yellow_navy": {"a": Color("ffd200"), "b": Color("0b2a6f"), "pattern": 1, "shorts": Color("ffffff"), "socks": Color("0b2a6f"), "trim": Color("0b2a6f")},
	"black_white": {"a": Color("141414"), "b": Color("f4f4f4"), "pattern": 1, "shorts": Color("141414"), "socks": Color("141414"), "trim": Color("f4f4f4")},
	"claret_blue": {"a": Color("7a1e3a"), "b": Color("5ec4f0"), "pattern": 1, "shorts": Color("7a1e3a"), "socks": Color("7a1e3a"), "trim": Color("5ec4f0")},
}
## Kalecinin forması: takım renginin tek ton, parlak bir çeşidi (oyuncudan ayırt edilsin diye)
const KEEPER := {
	"red_yellow": Color("1f8f4a"), "yellow_navy": Color("2a2a2a"), "black_white": Color("f28c1a"), "claret_blue": Color("1c3f94"),
}


func get_kit(id: String) -> Dictionary:
	return KITS.get(id, KITS["red_yellow"])


func name_key(id: String) -> String:
	return "kit_" + id
