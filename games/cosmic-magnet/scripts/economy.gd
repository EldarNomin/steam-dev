class_name Economy
extends RefCounted
## Правила экономики CM-002 (CM-R06): расчёт цен и уровней живёт только здесь.
## Покупка меняет лом и уровень одной операцией; недоступная покупка
## не меняет ничего. Лом не может уйти в минус.


var scrap := 0
## upgrade_id -> куплено уровней
var _levels: Dictionary = {}


func _upgrade_def(id: StringName) -> Dictionary:
	for def in CMConfig.upgrades():
		if StringName(def["id"]) == id:
			return def
	push_error("Economy: unknown upgrade '%s'" % id)
	return {}


## ceil(base_cost × cost_multiplier ^ bought_levels) — формула SPEC.
func upgrade_cost(id: StringName) -> int:
	var def := _upgrade_def(id)
	var cost: float = float(def["base_cost"]) * pow(float(def["cost_multiplier"]), float(level(id)))
	return int(ceil(cost))


func level(id: StringName) -> int:
	return int(_levels.get(id, 0))


func max_level(id: StringName) -> int:
	return int(_upgrade_def(id)["max_levels"])


func can_buy(id: StringName) -> bool:
	return level(id) < max_level(id) and scrap >= upgrade_cost(id)


## Единственная операция изменения денег и уровня: либо обе величины, либо ничего.
func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	scrap -= upgrade_cost(id)
	_levels[id] = level(id) + 1
	return true


## Значение эффекта улучшения по ключу (strength / attraction_radius / cargo_capacity).
func effect_sum(key: String) -> int:
	var total := 0
	for def in CMConfig.upgrades():
		if level(StringName(def["id"])) > 0 and def["effect"].has(key):
			total += int(def["effect"][key]) * level(StringName(def["id"]))
	return total


## Восстановление купленных уровней из сохранения (CM-R10) с клампом к
## потолкам конфига — повреждённые значения не ломают правила.
func restore_levels(levels: Dictionary) -> void:
	_levels.clear()
	for def in CMConfig.upgrades():
		var id := StringName(def["id"])
		var v := int(levels.get(String(id), 0))
		_levels[id] = clampi(v, 0, int(def["max_levels"]))
