class_name SalvageSite
extends Node2D
## Stable cover IDs survive trips/restarts. Only actual collection clears them.
var game: MainGame
var cleared: Array[int] = []
var released: Array[int] = []
var skiff_location: Vector2
var hardware: Array[SalvageItem] = []
var break_effects: Array[Dictionary] = []
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
	skiff_location = skiff_pos

func reset() -> void:
	cleared.clear()
	released.clear()
	break_effects.clear()
	skiff_location = skiff_pos
	module_found = false
	skiff_recovered = false

func restore(data: Dictionary) -> void:
	reset()
	for id in data.get("cleared", []):
		cleared.append(int(id))
	for id in data.get("released", []):
		released.append(int(id))
	var pos: Array = data.get("skiff_position", [skiff_pos.x, skiff_pos.y])
	skiff_location = Vector2(float(pos[0]),float(pos[1]))
	module_found = bool(data.get("module_found", false))
	skiff_recovered = bool(data.get("skiff_recovered", false))
	if skiff_recovered and not data.has("released"):
		for id in CMConfig.i("site.clamp_count"):
			released.append(id)

func snapshot() -> Dictionary:
	if is_instance_valid(skiff_item) and not skiff_item.is_queued_for_deletion():
		skiff_location = skiff_item.position
	return {"released":released.duplicate(),"skiff_position":[skiff_location.x,skiff_location.y],"cleared":cleared.duplicate(), "module_found":module_found, "skiff_recovered":skiff_recovered}

func excludes(pos: Vector2) -> bool:
	return pos.distance_to(module_pos) < CMConfig.f("site.radius") or pos.distance_to(skiff_pos) < 210.0 or pos.distance_to(extraction_pos()) < 65.0

func rebuild() -> void:
	hardware.clear()
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
		skiff_item = spawn_discovery(&"skiff", skiff_location, CMConfig.i("site.skiff_mass"), CMConfig.i("site.skiff_strength"))
	if module_found and not skiff_recovered:
		ensure_hardware()
	queue_redraw()

func can_collect(item: SalvageItem) -> bool:
	if item.discovery == &"module":
		return not module_found and cleared.size() == CMConfig.i("site.cover_count")
	if item.discovery == &"skiff":
		return module_found and released.size() == CMConfig.i("site.clamp_count") and not skiff_recovered and game.pulse.unlocked() and game.magnet.strength >= CMConfig.i("site.skiff_strength") and game.can_take(item.mass)
	if item.discovery in [&"relay", &"clamp"]:
		return false
	return true

func collected(item: SalvageItem) -> void:
	if item.cover_id >= 0 and not cleared.has(item.cover_id):
		cleared.append(item.cover_id)
		cleared.sort()
		game.save_now()
		ensure_discoveries.call_deferred()
	if item.discovery == &"module":
		module_found = true
		ensure_discoveries.call_deferred()
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
		if released.size() < CMConfig.i("site.clamp_count"):
			return "BREAK THE MOORINGS  /  aim at a cyan relay → chain pulse  %d / %d" % [released.size(),CMConfig.i("site.clamp_count")]
		return "TOW TO THE BEACON  /  pulse near skiff, move toward EXIT  /  %d%%" % tow_progress()
	if cleared.size() == CMConfig.i("site.cover_count"):
		return "SIGNAL UNCOVERED  /  collect the golden module"
	return "UNCOVER THE SIGNAL  /  clear marked debris  %d / %d" % [cleared.size(), CMConfig.i("site.cover_count")]

func _draw() -> void:
	if game == null or game.menu_visible:
		return
	for effect in break_effects:
		var tint := Color(1,0.75,0.4,float(effect["life"])*2.0)
		draw_line(effect["from"],effect["to"],tint,3,true)
		draw_arc(effect["to"],20+(0.5-float(effect["life"]))*60,0,TAU,32,tint,2,true)
	var exit := extraction_pos()
	draw_circle(exit, CMConfig.f("site.extraction_radius"),Color(0.2,1,0.7,0.05))
	draw_arc(exit, CMConfig.f("site.extraction_radius"),0,TAU,48,Color(0.3,1,0.8,0.7),2,true)
	draw_string(ThemeDB.fallback_font,exit+Vector2(-42,-52),"EXIT BEACON",HORIZONTAL_ALIGNMENT_CENTER,84,12,Color("62e7d4"))
	if module_found and not skiff_recovered:
		for obj in hardware:
			if is_instance_valid(obj) and not obj.collected and obj.discovery == &"clamp":
				draw_line(obj.position,skiff_location,Color(1,0.5,0.25,0.5),2,true)
	var progress := float(cleared.size()) / CMConfig.i("site.cover_count")
	draw_arc(module_pos, CMConfig.f("site.radius"), 0, TAU, 64, Color(0.5,0.85,0.8,0.12),1,true)
	if progress > 0:
		draw_arc(module_pos, CMConfig.f("site.radius"), -PI/2, -PI/2+progress*TAU,64,Color(0.95,0.72,0.4,0.45),2,true)
	if not module_found and cleared.size() < CMConfig.i("site.cover_count"):
		draw_texture_rect(preload("res://assets/art/relic.svg"),Rect2(module_pos-Vector2(22,22),Vector2(44,44)),false,Color(1,1,1,0.12))
		draw_string(ThemeDB.fallback_font,module_pos+Vector2(-60,30),"BURIED SIGNAL",HORIZONTAL_ALIGNMENT_CENTER,120,11,Color("9b8460"))

func extraction_pos() -> Vector2:
	return Vector2(CMConfig.f("site.extraction_x"), CMConfig.f("site.extraction_y"))

func clamp_pos(id: int) -> Vector2:
	var offsets: Array = CMConfig.node("site.clamp_offsets")
	return skiff_pos+Vector2(float(offsets[id][0]),float(offsets[id][1]))

func ensure_hardware() -> void:
	for id in CMConfig.i("site.clamp_count"):
		if released.has(id):
			continue
		var exists := false
		for obj in hardware:
			if is_instance_valid(obj) and not obj.is_queued_for_deletion() and obj.clamp_id == id:
				exists = true
		if exists:
			continue
		for kind in [&"relay", &"clamp"]:
			var pos := clamp_pos(id)
			if kind == &"relay":
				pos.x += CMConfig.f("site.relay_offset_x")
			var obj := spawn_discovery(kind,pos,0,1)
			obj.clamp_id = id
			hardware.append(obj)

func pulse_fired(links: Array[Array]) -> void:
	# Only an actual matching relay hop counts; prefer the relay the player aimed at.
	var selected := -1
	var nearest := INF
	var effect := {}
	for link in links:
		if not is_instance_valid(link[0]) or not is_instance_valid(link[1]):
			continue
		var source: SalvageItem = link[0]
		var target: SalvageItem = link[1]
		if source.discovery != &"relay" or target.discovery != &"clamp" or source.clamp_id != target.clamp_id or released.has(target.clamp_id):
			continue
		var distance := source.position.distance_squared_to(game.magnet.position)
		if distance < nearest:
			nearest = distance
			selected = target.clamp_id
			effect = {"from":source.position,"to":target.position,"life":0.5}
	if selected < 0:
		return
	break_effects.append(effect)
	if game.has_node("Presentation"):
		game.get_node("Presentation").collected(effect["to"],0,true,"MOORING RELEASED")
	released.append(selected)
	released.sort()
	for obj in hardware:
		if is_instance_valid(obj) and obj.clamp_id == selected:
			obj.collected = true
			obj.queue_free()
	game.save_now()
	game.notify_hud()
	queue_redraw()

func tow(item: SalvageItem, delta: float) -> void:
	if not can_collect(item) or not game.pulse.affects(item):
		return
	item.position = item.position.move_toward(game.magnet.position, CMConfig.f("site.tow_speed")*delta)
	skiff_location = item.position
	if item.position.distance_to(extraction_pos()) <= CMConfig.f("site.extraction_radius"):
		game.register_collection(item)
	queue_redraw()

func tow_progress() -> int:
	var initial := skiff_pos.distance_to(extraction_pos())
	return int(clampf(1.0-skiff_location.distance_to(extraction_pos())/initial,0.0,1.0)*100.0)

func _process(delta: float) -> void:
	if game.is_paused or game.menu_visible:
		return
	for effect in break_effects:
		effect["life"] -= delta
	break_effects = break_effects.filter(func(effect: Dictionary) -> bool: return effect["life"] > 0.0)
