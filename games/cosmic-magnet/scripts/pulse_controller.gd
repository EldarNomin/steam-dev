class_name PulseController
extends Node2D
## One bounded target snapshot; item.step remains the only movement/collection owner.
var game: MainGame
var holding := false
var held := 0.0
var cooldown := 0.0
var active := 0.0
var fired_radius := 0.0
var targets: Array[SalvageItem] = []
var shots := 0
var chain_links: Array[Array] = []

func _ready() -> void:
	game = get_parent() as MainGame
	z_index = 25

func unlocked() -> bool:
	return game.economy.level(&"pulse") > 0

func allowed() -> bool:
	return game.state == MainGame.GameState.SALVAGE and not game.menu_visible and not game.is_paused

func cancel() -> void:
	holding = false
	held = 0.0

func reset(all := false) -> void:
	cancel()
	active = 0.0
	targets.clear()
	chain_links.clear()
	if all:
		cooldown = 0.0
	queue_redraw()

func begin(pos: Vector2) -> bool:
	if not unlocked() or not allowed() or cooldown > 0.0 or not CMConfig.FIELD_RECT.has_point(pos):
		return false
	holding = true
	held = 0.0
	return true

func radius() -> float:
	return game.magnet.attraction_radius * (1.0 + clampf(held / CMConfig.f("pulse.hold_max"), 0.0, 1.0))

func eligible(item: Variant, chain := false) -> bool:
	if is_instance_valid(item) and item is SalvageItem and item.discovery in [&"relay", &"clamp"]:
		return not item.collected and not item.is_queued_for_deletion() and game.site.module_found and (item.discovery == &"relay" or chain)
	return is_instance_valid(item) and item is SalvageItem and not item.collected and not item.is_queued_for_deletion() and item.required_strength <= game.magnet.strength and (item.is_unique or game.can_take(item.mass)) and (item.discovery == &"" or game.site.can_collect(item))

func release(pos: Vector2) -> bool:
	if not holding:
		return false
	var ready := allowed() and CMConfig.FIELD_RECT.has_point(pos) and held >= CMConfig.f("pulse.hold_min")
	fired_radius = radius()
	cancel()
	if not ready or cooldown > 0.0:
		return false
	targets.clear()
	chain_links.clear()
	for child in game.spawner.get_children():
		if child is SalvageItem and eligible(child) and child.position.distance_to(game.magnet.position) <= fired_radius:
			targets.append(child)
	targets.sort_custom(func(a: SalvageItem, b: SalvageItem) -> bool:
		var da := a.position.distance_squared_to(game.magnet.position)
		var db := b.position.distance_squared_to(game.magnet.position)
		return a.get_index() < b.get_index() if is_equal_approx(da, db) else da < db)
	if targets.size() > CMConfig.i("pulse.max_targets"):
		targets.resize(CMConfig.i("pulse.max_targets"))
	if targets.is_empty():
		return false
	if game.site != null and game.site.module_found:
		add_chain_targets()
	active = CMConfig.f("pulse.duration")
	cooldown = CMConfig.f("pulse.cooldown")
	shots += 1
	if game.site != null:
		game.site.pulse_fired(chain_links)
	queue_redraw()
	return true

func add_chain_targets() -> void:
	var frontier: Array[SalvageItem] = targets.duplicate()
	var extra := 0
	for hop in CMConfig.i("pulse.chain_hops"):
		var next: Array[SalvageItem] = []
		for child in game.spawner.get_children():
			if not child is SalvageItem or targets.has(child) or not eligible(child, true):
				continue
			for source in frontier:
				if child.discovery == &"clamp" and (source.discovery != &"relay" or source.clamp_id != child.clamp_id):
					continue
				if child.position.distance_to(source.position) <= CMConfig.f("pulse.chain_radius"):
					targets.append(child)
					chain_links.append([source, child])
					next.append(child)
					extra += 1
					break
			if extra >= CMConfig.i("pulse.chain_targets"):
				return
		frontier = next
		if frontier.is_empty():
			break

func affects(item: SalvageItem) -> bool:
	return active > 0.0 and allowed() and targets.has(item)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and holding and not CMConfig.FIELD_RECT.has_point(get_global_mouse_position()):
		cancel()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		release(get_global_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		begin(get_global_mouse_position())

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if not allowed():
		cancel()
		return
	cooldown = maxf(0.0, cooldown - delta)
	var was_active := active > 0.0
	active = maxf(0.0, active - delta)
	if was_active and active <= 0.0 and game.site != null and game.site.module_found:
		game.save_now()
	if holding:
		held = minf(held + delta, CMConfig.f("pulse.hold_max"))
	if active <= 0.0:
		targets.clear()
		chain_links.clear()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game) or not allowed():
		return
	var center := game.magnet.position
	if holding:
		var k := held / CMConfig.f("pulse.hold_max")
		draw_circle(center, radius(), Color(0.25, 1.0, 0.9, 0.025 + k * 0.025))
		draw_arc(center, radius(), 0, TAU, 96, Color(0.4, 1.0, 0.9, 0.55), 1.5, true)
		draw_arc(center, 38, -PI / 2, -PI / 2 + maxf(k, 0.01) * TAU, 48, Color("efbd74"), 3.0, true)
	if active > 0.0:
		var k := 1.0 - active / CMConfig.f("pulse.duration")
		draw_arc(center, fired_radius * k, 0, TAU, 96, Color(0.5, 1.0, 0.94, (1.0-k)*0.7), 2.5, true)
		for link in chain_links:
			if is_instance_valid(link[0]) and is_instance_valid(link[1]):
				draw_line(link[0].position, link[1].position, Color(1.0,0.75,0.35,0.8), 2.0, true)
		for item in targets:
			if eligible(item):
				draw_line(item.position, center, Color(0.4, 1.0, 0.9, 0.4), 1.4, true)
