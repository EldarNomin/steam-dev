class_name SalvageSite
extends Node2D
## Stable cover IDs survive trips/restarts. Only actual collection clears them.
var game: MainGame
var cleared: Array[int] = []
var module_found := false
var skiff_recovered := false
var module_item: SalvageItem
var skiff_item: SalvageItem
var module_pos: Vector2
var skiff_pos: Vector2

func _ready() -> void:
	game = get_parent() as MainGame
	z_index = 0
	module_pos = Vector2(CMConfig.f("site.center_x"), CMConfig.f("site.center_y"))
	skiff_pos = Vector2(CMConfig.f("site.skiff_x"), CMConfig.f("site.skiff_y"))

func reset() -> void:
	cleared.clear()
	module_found = false
	skiff_recovered = false

func restore(data: Dictionary) -> void:
	reset()
	for id in data.get("cleared", []):
		cleared.append(int(id))
	module_found = bool(data.get("module_found", false))
	skiff_recovered = bool(data.get("skiff_recovered", false))

func snapshot() -> Dictionary:
	return {"cleared":cleared.duplicate(), "module_found":module_found, "skiff_recovered":skiff_recovered}

func excludes(pos: Vector2) -> bool:
	return pos.distance_to(module_pos) < CMConfig.f("site.radius") or pos.distance_to(skiff_pos) < 80.0

func rebuild() -> void:
	module_item = null
	skiff_item = null
	var index := 0
	for id in CMConfig.i("site.cover_count"):
		if cleared.has(id):
			continue
		var candidate: SalvageItem
		while index < game.spawner.get_child_count():
			var child = game.spawner.get_child(index)
			index += 1
			if child is SalvageItem and not child.is_unique:
				candidate = child
				break
		if candidate == null:
			break
		candidate.setup(CMConfig.items()[id % 2])
		candidate.cover_id = id
		var angle := float(id) / CMConfig.i("site.cover_count") * TAU
		candidate.position = module_pos + Vector2.from_angle(angle) * (85.0 if id % 2 == 0 else 115.0)
	ensure_discoveries()
	queue_redraw()

func room_for_discovery() -> void:
	if game.spawner.field_count() < CMConfig.i("field.max_items"):
		return
	# Reserve a real slot within the existing cap, without rewarding a removed ordinary item.
	for child in game.spawner.get_children():
		if child is SalvageItem and not child.is_unique and child.cover_id < 0:
			child.free()
			return

func spawn_discovery(kind: StringName, pos: Vector2, mass: int, strength: int) -> SalvageItem:
	room_for_discovery()
	var item := SalvageItem.new()
	item.game = game
	item.setup({"id":"skiff" if kind == &"skiff" else "relic_core", "required_strength":strength, "mass":mass, "price":0, "radius":24 if kind == &"skiff" else 12})
	item.is_unique = true
	item.discovery = kind
	item.position = pos
	game.spawner.add_child(item)
	return item

func ensure_discoveries() -> void:
	if cleared.size() == CMConfig.i("site.cover_count") and not module_found and not is_instance_valid(module_item):
		module_item = spawn_discovery(&"module", module_pos, 0, 1)
	if not skiff_recovered and not is_instance_valid(skiff_item):
		skiff_item = spawn_discovery(&"skiff", skiff_pos, CMConfig.i("site.skiff_mass"), CMConfig.i("site.skiff_strength"))
	queue_redraw()

func can_collect(item: SalvageItem) -> bool:
	if item.discovery == &"module":
		return not module_found and cleared.size() == CMConfig.i("site.cover_count")
	if item.discovery == &"skiff":
		return module_found and not skiff_recovered and game.pulse.unlocked() and game.magnet.strength >= CMConfig.i("site.skiff_strength") and game.can_take(item.mass)
	return true

func collected(item: SalvageItem) -> void:
	if item.cover_id >= 0 and not cleared.has(item.cover_id):
		cleared.append(item.cover_id)
		cleared.sort()
		game.save_now()
		ensure_discoveries.call_deferred()
	if item.discovery == &"module":
		module_found = true
		game.save_now()
	if item.discovery == &"skiff":
		skiff_recovered = true
		game.economy.scrap += CMConfig.i("site.skiff_reward")
		game.request_return()
		game.save_now()
	queue_redraw()

func objective() -> String:
	if skiff_recovered:
		return "SKIFF RECOVERED  /  the first salvage is complete"
	if module_found:
		return "CHAIN MODULE ONLINE  /  strength 2 + empty hold → PULSE the skiff"
	if cleared.size() == CMConfig.i("site.cover_count"):
		return "SIGNAL UNCOVERED  /  collect the golden module"
	return "UNCOVER THE SIGNAL  /  clear marked debris  %d / %d" % [cleared.size(), CMConfig.i("site.cover_count")]

func _draw() -> void:
	if game == null or game.menu_visible:
		return
	var progress := float(cleared.size()) / CMConfig.i("site.cover_count")
	draw_arc(module_pos, CMConfig.f("site.radius"), 0, TAU, 64, Color(0.5,0.85,0.8,0.12),1,true)
	if progress > 0:
		draw_arc(module_pos, CMConfig.f("site.radius"), -PI/2, -PI/2+progress*TAU,64,Color(0.95,0.72,0.4,0.45),2,true)
	if not module_found and cleared.size() < CMConfig.i("site.cover_count"):
		draw_texture_rect(preload("res://assets/art/relic.svg"),Rect2(module_pos-Vector2(22,22),Vector2(44,44)),false,Color(1,1,1,0.12))
		draw_string(ThemeDB.fallback_font,module_pos+Vector2(-60,30),"BURIED SIGNAL",HORIZONTAL_ALIGNMENT_CENTER,120,11,Color("9b8460"))
