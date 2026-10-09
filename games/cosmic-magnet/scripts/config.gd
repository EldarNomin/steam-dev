class_name CMConfig
extends RefCounted
## Единственный машиночитаемый источник баланса (с CM-002) — data/balance.json.
## Здесь только типизированный доступ к данным; правила расчёта (цены, уровни)
## живут в Economy и не дублируются.

# Раскладка окна (не экономика): поле слева от панели улучшений.
const FIELD_RECT := Rect2(0.0, 60.0, 980.0, 660.0)
const FIELD_MARGIN := 24.0

static var _balance: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if f == null:
		push_error("CMConfig: data/balance.json not found")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_balance = parsed
		_loaded = true
	else:
		push_error("CMConfig: data/balance.json is not a JSON object")


static func node(path: String) -> Variant:
	ensure_loaded()
	var cur: Variant = _balance
	for part in path.split("."):
		if cur is Dictionary and cur.has(part):
			cur = cur[part]
		else:
			push_error("CMConfig: missing key '%s' in balance.json" % path)
			return null
	return cur


static func f(path: String) -> float:
	return float(node(path))


static func i(path: String) -> int:
	return int(node(path))


static func items() -> Array:
	return node("items")


static func upgrades() -> Array:
	return node("upgrades")
