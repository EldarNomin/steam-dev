extends SceneTree
## Headless-тест правил сбора CM-001/CM-002 (CM-R01–R03 + часть R08).
## Запуск: godot --headless --path games/cosmic-magnet --script tests/test_core.gd
## Сборные проверки вызывают шаги вручную; soak-блок использует реальные кадры
## дерева (await process_frame), поэтому проверяет инварианты-потолки, а не
## конкретные траектории: во время кадров движок сам двигает магнит и предметы.

var passed := 0
var failed := 0


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	# Отдельный временный профиль: игра пишет сейвы (покупка/разгрузка),
	# тесты не должны трогать сохранение игрока.
	SaveService.save_dir = "user://cm3_tests/core_%d" % (Time.get_ticks_msec() + randi() % 100000)
	DirAccess.make_dir_recursive_absolute(SaveService.save_dir)
	SaveService.wipe_files()

	var main: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.new_game()  # выходим из главного меню в забег

	_test_initial_fill(main)
	main.launch()  # правила сбора действуют в SALVAGE
	_test_outside_radius_not_collected(main)
	_test_inside_radius_attracts(main)
	_test_capture_collects_exactly_once(main)
	_test_large_delta_does_not_lose_capture(main)
	_test_heavy_item_stays_and_hints(main)
	_test_heavy_item_not_captured_in_capture_radius(main)
	_test_respawn_bounded(main)
	_test_field_clamp()
	_test_pause_stops_simulation(main)
	_test_focus_loss_autopause(main)
	_test_magnet_visual_state_reset(main)
	await _test_soak_collect_respawn_600s(main)

	SaveService.wipe_files()
	DirAccess.remove_absolute(SaveService.save_dir)
	SaveService.save_dir = "user://cosmic_magnet"

	print("SUMMARY passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(cond: bool, test_name: String, context: String = "") -> void:
	if cond:
		passed += 1
		print("PASS ", test_name)
	else:
		failed += 1
		print("FAIL ", test_name, " — ", context)


func _center_magnet(main: MainGame) -> void:
	main.magnet.position = Vector2(490, 390)


## Первый предмет, который текущий магнит может поднять и который влезает
## в трюм (в soak поле содержит и недоступные батареи — их честно пропускаем).
func _pick_free_item(main: MainGame, skip: Array = []) -> SalvageItem:
	for c in main.spawner.get_children():
		if (
			c is SalvageItem
			and not c.collected
			and c.discovery == &""  # ordinary collection soak; scenario hardware is tested in test_hook
			and not skip.has(c)
			and c.required_strength <= main.magnet.strength
			and main.can_take(c.mass)
		):
			return c
	return null


func _test_initial_fill(main: MainGame) -> void:
	var types := {}
	for c in main.spawner.get_children():
		types[c.item_id] = true
	_check(main.spawner.field_count() == CMConfig.i("field.max_items"),
		"fill: field has max_items at start", "count=%d" % main.spawner.field_count())
	_check(types.has(&"nut") and types.has(&"plate") and types.has(&"battery"),
		"fill: three item types present")


func _test_outside_radius_not_collected(main: MainGame) -> void:
	_center_magnet(main)
	var item := _pick_free_item(main)
	item.position = main.magnet.position + Vector2(250, 0)
	var before := main.collected_count
	for i in 10:
		item.step(0.05)
	_check(item.position == main.magnet.position + Vector2(250, 0),
		"outside attraction radius: item does not move",
		"pos=%s" % item.position)
	_check(main.collected_count == before, "outside attraction radius: not collected")


func _test_inside_radius_attracts(main: MainGame) -> void:
	_center_magnet(main)
	var item := _pick_free_item(main)
	item.position = main.magnet.position + Vector2(80, 0)
	var dist_before := item.position.distance_to(main.magnet.position)
	for i in 20:
		item.step(1.0 / 60.0)
	var dist_after := item.position.distance_to(main.magnet.position)
	_check(
		dist_after <= dist_before - 25.0 or item.collected,
		"inside attraction radius: item moves toward magnet",
		"before=%f after=%f" % [dist_before, dist_after]
	)


func _test_capture_collects_exactly_once(main: MainGame) -> void:
	_center_magnet(main)
	# F2 из ревью CM-001: прямые повторные вызовы обработчика до удаления узла.
	var direct := _pick_free_item(main)
	direct.position = main.magnet.position + Vector2(7, 0)
	var before_direct := main.collected_count
	main.register_collection(direct)
	main.register_collection(direct)
	_check(main.collected_count == before_direct + 1,
		"capture: direct double register_collection adds exactly once",
		"delta=%d" % (main.collected_count - before_direct))
	_check(direct.collected and direct.is_queued_for_deletion(),
		"capture: direct item marked collected and freed")

	var item := _pick_free_item(main)
	item.position = main.magnet.position + Vector2(5, 0)
	var before := main.collected_count
	item.step(0.016)
	var after_first := main.collected_count
	item.step(0.016)
	item.step(0.016)
	main.register_collection(item)  # повтор после обычного захвата
	_check(after_first == before + 1, "capture: collected exactly once", "delta=%d" % (after_first - before))
	_check(main.collected_count == before + 1, "capture: repeated calls do not add",
		"delta=%d" % (main.collected_count - before))
	_check(item.collected and item.is_queued_for_deletion(), "capture: item is freed")
	_check(main.cargo_label.text.begins_with("Cargo: %d/" % main.cargo_mass),
		"HUD cargo reflects real state", main.cargo_label.text)


func _test_large_delta_does_not_lose_capture(main: MainGame) -> void:
	_center_magnet(main)
	var item := _pick_free_item(main)
	item.position = main.magnet.position + Vector2(95, 0)
	var before := main.collected_count
	item.step(30.0)
	_check(main.collected_count == before + 1,
		"large delta: capture intersection is not lost",
		"delta=%d" % (main.collected_count - before))


func _make_heavy_item(main: MainGame) -> SalvageItem:
	var item := SalvageItem.new()
	item.game = main
	item.setup({"id": &"wreck", "required_strength": 2, "mass": 8, "price": 20, "radius": 8.0, "color": Color("7fd0e8")})
	main.spawner.add_child(item)
	return item


func _test_heavy_item_stays_and_hints(main: MainGame) -> void:
	_center_magnet(main)
	var item := _make_heavy_item(main)
	item.position = main.magnet.position + Vector2(60, 0)
	var pos_before := item.position
	var before := main.collected_count
	for i in 10:
		item.step(0.1)
	_check(item.position == pos_before, "heavy item: stays in place", "pos=%s" % item.position)
	_check(main.collected_count == before, "heavy item: not collected")
	_check(item.is_hint_visible(), "heavy item: shows required strength near magnet")
	item.free()  # синтетический предмет не влияет на счётчики поля


## F1 из ревью CM-001: захват не должен обходить требование силы (CM-R02).
func _test_heavy_item_not_captured_in_capture_radius(main: MainGame) -> void:
	_center_magnet(main)
	for d in [0.0, 5.0, 12.0, 13.0, 100.0]:
		var item := _make_heavy_item(main)
		item.position = main.magnet.position + Vector2(d, 0)
		var before := main.collected_count
		item.step(0.016)
		_check(
			main.collected_count == before and not item.collected,
			"heavy capture: not collected at distance %s" % d,
			"delta=%d" % (main.collected_count - before)
		)
		item.free()
	# Повышение силы до 2 открывает тяжёлый предмет — сбор однократный.
	var item := _make_heavy_item(main)
	item.position = main.magnet.position + Vector2(60, 0)
	main.magnet.strength = 2
	var before := main.collected_count
	for i in 30:
		item.step(1.0 / 60.0)
	main.magnet.strength = CMConfig.i("magnet.base_strength")
	_check(main.collected_count == before + 1, "heavy capture: strength 2 allows single collection",
		"delta=%d" % (main.collected_count - before))
	item.free()


func _test_respawn_bounded(main: MainGame) -> void:
	_center_magnet(main)
	var max_seen := 0
	var before := main.spawner.field_count()
	for i in 5:
		var item := _pick_free_item(main)
		item.position = main.magnet.position + Vector2(3, 0)
		item.step(0.016)
	_check(main.spawner.field_count() == before - 5, "respawn: field emptied by 5",
		"count=%d expected=%d" % [main.spawner.field_count(), before - 5])
	# Проигрываем время возрождения мелкими шагами и следим за потолком.
	for i in 60:
		main.spawner.step(0.1)
		max_seen = maxi(max_seen, main.spawner.field_count())
	_check(main.spawner.field_count() == CMConfig.i("field.max_items"), "respawn: field refilled to cap",
		"count=%d" % main.spawner.field_count())
	_check(max_seen <= CMConfig.i("field.max_items"), "respawn: field count never exceeds cap",
		"max=%d" % max_seen)


## Активный 600-секундный цикл сбора/возрождения (см. замечание ревью CM-001
## о детерминированности): каждую секунду собираем до 5 предметов, удаления
## проходят реальными кадрами, экономика живёт своим ходом (заряд → авто-возврат
## → разгрузка → перезапуск вылета). Проверяются потолки и восстановление.
func _test_soak_collect_respawn_600s(main: MainGame) -> void:
	_center_magnet(main)
	var max_children := 0
	var max_field := 0
	var manual_ok := 0
	for sec in 600:
		if main.state != MainGame.GameState.SALVAGE:
			main.launch()
		for i in 5:
			var item := _pick_free_item(main)
			if item == null:
				break
			item.position = main.magnet.position + Vector2(3, 0)
			item.step(0.016)
			if item.collected:
				manual_ok += 1
		await process_frame  # queue_free доводит удаления до конца между секундами
		max_children = maxi(max_children, main.spawner.get_child_count())
		max_field = maxi(max_field, main.spawner.field_count())
		for t in 10:
			main.spawner.step(0.1)
		max_children = maxi(max_children, main.spawner.get_child_count())
		max_field = maxi(max_field, main.spawner.field_count())
	for t in 120:  # хвост очереди возрождения после последнего сбора
		await process_frame
		main.spawner.step(0.1)
	var cap := CMConfig.i("field.max_items")
	_check(max_field <= cap, "soak 600s: field count capped at every step",
		"max=%d" % max_field)
	_check(max_children <= cap, "soak 600s: real node count capped at every step",
		"max=%d" % max_children)
	_check(main.spawner.field_count() == cap, "soak 600s: field restored to cap",
		"count=%d" % main.spawner.field_count())
	_check(manual_ok >= 2500, "soak 600s: at least 2500 manual collections registered",
		"manual=%d" % manual_ok)


## Визуальное состояние магнита между вылетами (F1–F3 ревью visual-polish):
## вспышка тает и в DOCK, хвост сбрасывается при вылете, to_local не удваивает
## координаты следа.
func _test_magnet_visual_state_reset(main: MainGame) -> void:
	main.request_return()  # гарантированный DOCK
	main.launch()          # вылет №1: trail сброшен
	main.magnet.position = Vector2(420, 300)
	main.magnet._trail.push_front(Vector2(420, 300))
	main.magnet.flash()
	_check(main.magnet._flash > 0.0, "visual: flash set by collection hook", "")
	_check(main.magnet._trail.size() == 1, "visual: trail records flight", "")
	main.request_return()
	_check(main.state == MainGame.GameState.DOCK, "visual: decay probe is in dock", "")
	main.magnet._physics_process(2.0)  # 2 с в DOCK: вспышка обязана погаснуть
	_check(main.magnet._flash == 0.0, "visual: flash decays in dock",
		"flash=%f" % main.magnet._flash)
	main.request_return()  # штатный возврат в док
	main.magnet.flash()    # новый вылет сразу после сбора, без ожидания
	main.launch()          # вылет №2 — чистый старт
	_check(main.magnet._flash == 0.0, "visual: flash cleared on immediate sortie", "")
	_check(main.magnet._trail.is_empty(), "visual: trail cleared on new sortie", "")
	main.magnet.position = Vector2(420, 300)
	main.magnet._trail.push_front(Vector2(420, 300))
	_check(main.magnet.to_local(Vector2(420, 300)) == Vector2.ZERO,
		"visual: trail converts to magnet-local (no doubled coords)",
		str(main.magnet.to_local(Vector2(420, 300))))
	main.magnet.reset_trail()
	main.request_return()
	main.magnet.flash()
	main.new_game()
	_check(main.magnet._flash == 0.0, "visual: new game clears flash", "")
	main.magnet.flash()
	main.continue_game()
	_check(main.magnet._flash == 0.0, "visual: continue clears flash", "")


func _test_field_clamp() -> void:
	var c1 := Magnet.clamp_to_field(Vector2(1200, 100))
	_check(c1 == Vector2(956, 100), "clamp: mouse over side panel stays in field", str(c1))
	var c2 := Magnet.clamp_to_field(Vector2(-30, 10))
	_check(c2 == Vector2(24, 84), "clamp: HUD/top side clamped", str(c2))
	var c3 := Magnet.clamp_to_field(Vector2(500, 800))
	_check(c3 == Vector2(500, 696), "clamp: bottom clamped", str(c3))


func _test_pause_stops_simulation(main: MainGame) -> void:
	main.toggle_pause()
	_check(main.is_paused and paused, "pause: tree paused")
	_check(not main.magnet.can_process(), "pause: magnet does not process")
	_check(not main.spawner.can_process(), "pause: spawner does not process")
	_check(main.pause_overlay.visible, "pause: overlay visible")
	main.toggle_pause()
	_check(not main.is_paused and not paused, "pause: resumes")


func _test_focus_loss_autopause(main: MainGame) -> void:
	main.handle_focus_lost()
	_check(main.is_paused and paused, "focus loss: simulation auto-paused")
	main.toggle_pause()
