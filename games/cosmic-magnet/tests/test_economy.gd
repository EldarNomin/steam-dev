extends SceneTree
## Headless-тест экономики CM-002 (CM-R04–R08).
## Запуск: godot --headless --path games/cosmic-magnet --script tests/test_economy.gd
## Проверяет: кривую цен из конфига, атомарные покупки и лимиты уровней,
## заряд и авто-возврат, массу груза и невлезающие предметы, однократную
## разгрузку (включая одновременные причины возврата), неотрицательность лома.

var passed := 0
var failed := 0


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	# Отдельный временный профиль (требование приёмки): экономика пишет сейвы
	# при покупках/разгрузках — сохранение игрока не трогаем.
	SaveService.save_dir = "user://cm3_tests/econ_%d" % (Time.get_ticks_msec() + randi() % 100000)
	DirAccess.make_dir_recursive_absolute(SaveService.save_dir)
	SaveService.wipe_files()

	_test_cost_curve_and_caps()
	_test_unavailable_buy_changes_nothing()

	var main: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)

	_test_launch_and_return(main)
	_test_charge_drain_and_auto_return(main)
	_test_cargo_fit_rules(main)
	_test_full_cargo_auto_return_and_unload(main)
	_test_unload_idempotent(main)
	_test_simultaneous_return_reasons_single_payout(main)
	_test_buy_applies_stats(main)
	_test_strength_unlocks_battery(main)
	_test_magnet_frozen_in_dock(main)
	_test_nut_guarantee(main)
	_test_first_purchase_affordable()
	_test_ui_inside_screen(main)
	await _test_first_purchase_benchmark()

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


func _item_def(id: StringName) -> Dictionary:
	for def in CMConfig.items():
		if StringName(def["id"]) == id:
			return def
	return {}


func _make_item(main: MainGame, id: StringName) -> SalvageItem:
	var item := SalvageItem.new()
	item.game = main
	item.setup(_item_def(id))
	main.spawner.add_child(item)
	return item


## Кривая цен: ceil(base_cost × multiplier ^ bought_levels) для каждого уровня
## и каждой ветки; потолок уровней из конфига не даёт купить лишний уровень.
func _test_cost_curve_and_caps() -> void:
	for def in CMConfig.upgrades():
		var id := StringName(def["id"])
		var econ := Economy.new()
		econ.scrap = 100000
		var ok_curve := true
		var ctx := ""
		for lvl in int(def["max_levels"]):
			var expected := int(ceil(float(def["base_cost"]) * pow(float(def["cost_multiplier"]), float(lvl))))
			if econ.upgrade_cost(id) != expected:
				ok_curve = false
				ctx = "lvl %d: got %d expected %d" % [lvl, econ.upgrade_cost(id), expected]
				break
			if not econ.buy(id):
				ok_curve = false
				ctx = "buy refused at lvl %d with scrap %d" % [lvl, econ.scrap]
				break
		_check(ok_curve, "cost curve: %s follows ceil(base×mult^lvl)" % def["id"], ctx)
		_check(econ.level(id) == int(def["max_levels"]), "cap: %s reaches max level" % def["id"],
			"level=%d" % econ.level(id))
		var scrap_before := econ.scrap
		_check(not econ.buy(id), "cap: %s refuses buy beyond max" % def["id"], "")
		_check(econ.scrap == scrap_before, "cap: %s refused buy keeps scrap" % def["id"], "")
	# Эффекты уровней применяются по ключам конфига.
	var econ2 := Economy.new()
	econ2.scrap = 100000
	econ2.buy(&"strength")
	econ2.buy(&"radius")
	_check(econ2.effect_sum("strength") == 1, "effects: strength L1 gives +1", "")
	_check(econ2.effect_sum("attraction_radius") == 20, "effects: radius L1 gives +20", "")
	_check(econ2.effect_sum("cargo_capacity") == 0, "effects: untouched key sums to 0", "")


## Недоступная покупка не меняет ни лом, ни уровень (CM-R06).
func _test_unavailable_buy_changes_nothing() -> void:
	var econ := Economy.new()
	econ.scrap = 0
	_check(not econ.buy(&"strength"), "no scrap: buy refused", "")
	_check(econ.scrap == 0 and econ.level(&"strength") == 0, "no scrap: state unchanged", "")
	var cost := econ.upgrade_cost(&"strength")
	econ.scrap = cost - 1
	_check(not econ.buy(&"strength"), "scrap = cost-1: buy refused", "")
	_check(econ.scrap == cost - 1 and econ.level(&"strength") == 0, "scrap = cost-1: state unchanged", "")
	_check(econ.scrap >= 0, "scrap never negative", "scrap=%d" % econ.scrap)


func _test_launch_and_return(main: MainGame) -> void:
	main.launch()
	_check(main.state == MainGame.GameState.SALVAGE and main.magnet.visible, "launch: salvage state, magnet shown", "")
	main.request_return()
	_check(main.state == MainGame.GameState.DOCK and not main.magnet.visible, "return: dock state, magnet hidden", "")
	_check(is_equal_approx(main.charge, main.max_charge()), "return: charge refilled", "charge=%f" % main.charge)
	main.request_return()  # повтор в DOCK ничего не делает
	_check(main.state == MainGame.GameState.DOCK, "return: repeat in dock is a no-op", "")


func _test_charge_drain_and_auto_return(main: MainGame) -> void:
	main.launch()
	var before := main.charge
	main.advance_flight(5.0)
	_check(is_equal_approx(before - main.charge, 5.0), "charge drains in salvage", "delta=%f" % (before - main.charge))
	main.charge = 0.5
	main.advance_flight(1.0)
	_check(main.state == MainGame.GameState.DOCK, "charge empty: auto-return to dock", "")
	_check(is_equal_approx(main.charge, main.max_charge()), "charge empty: refilled after unload", "")


## Груз не превышает ёмкость: невлезающий предмет не собирается и остаётся
## на поле с подсказкой FULL (SPEC); влезающий — собирается и заполняет трюм
## до авто-возврата с разгрузкой.
func _test_cargo_fit_rules(main: MainGame) -> void:
	main.launch()
	var cap := main.capacity()
	main.cargo_mass = cap - 1  # симулируем почти полный трюм
	var big := _make_item(main, &"plate")  # подъёмная, но mass 2 > 1 остатка
	big.position = main.magnet.position + Vector2(5, 0)
	big.step(0.016)
	_check(not big.collected and main.cargo_mass == cap - 1,
		"oversized item: not collected, cargo untouched", "cargo=%d" % main.cargo_mass)
	_check(big.is_hint_visible() and big.hint_text() == "FULL", "oversized item: FULL hint", big.hint_text())
	big.free()

	var scrap_before := main.economy.scrap
	var small := _make_item(main, &"nut")  # mass 1 == остаток
	small.position = main.magnet.position + Vector2(5, 0)
	main.register_collection(small)
	_check(small.collected and main.state == MainGame.GameState.DOCK,
		"fitting item: fills cargo, auto-return with unload", "state=%d" % main.state)
	_check(main.economy.scrap == scrap_before + int(small.price),
		"fitting item: unload credited it", "scrap delta=%d" % (main.economy.scrap - scrap_before))
	_check(main.cargo_mass == 0, "fitting item: cargo cleared after unload", "cargo=%d" % main.cargo_mass)


## Полный трюм — авто-возврат и автоматическая разгрузка без потери добычи.
func _test_full_cargo_auto_return_and_unload(main: MainGame) -> void:
	main.launch()
	var cap := main.capacity()
	var scrap_before := main.economy.scrap
	var mass := 0
	var value := 0
	while mass + int(_item_def(&"nut")["mass"]) <= cap:
		var item := _make_item(main, &"nut")
		main.register_collection(item)
		mass += int(item.mass)
		value += int(item.price)
	_check(main.state == MainGame.GameState.DOCK, "full cargo: returned on last fitting item", "")
	_check(main.economy.scrap == scrap_before + value, "full cargo: unload credited whole cargo",
		"scrap=%d expected=%d" % [main.economy.scrap, scrap_before + value])
	_check(main.cargo_mass == 0, "full cargo: cargo cleared", "cargo=%d" % main.cargo_mass)


## Разгрузка идемпотентна: повторные вызовы не начисляют деньги повторно (CM-R05).
func _test_unload_idempotent(main: MainGame) -> void:
	main.launch()
	var scrap_before := main.economy.scrap
	var item := _make_item(main, &"plate")
	main.register_collection(item)
	var gained := int(_item_def(&"plate")["price"])
	main.unload()
	main.unload()
	main.unload()
	_check(main.economy.scrap == scrap_before + gained, "unload: repeated calls pay once",
		"scrap=%d expected=%d" % [main.economy.scrap, scrap_before + gained])


## Одновременные причины возврата при ПОЛНОМ трюме (F2 ревью CM-002):
## старт каждого порядка — cargo = capacity − mass последнего предмета
## и почти пустой заряд, так что все причины готовы одновременно.
## Три порядка: (A) последний сбор завершает трюм; (B) раньше опустел
## заряд; (C) раньше сработала ручная кнопка. После каждого: остальные
## причины и повторные unload — no-op; ровно одна выплата, сброс груза
## и заряда, сбор в DOCK невозможен.
func _test_simultaneous_return_reasons_single_payout(main: MainGame) -> void:
	var plate := _item_def(&"plate")
	var pm := int(plate["mass"])
	var pp := int(plate["price"])

	# Порядок A: последний сбор (полный трюм) при уже пустом заряде.
	main.launch()
	var scrap_a := main.economy.scrap
	main.cargo_mass = main.capacity() - pm
	main.cargo_value = 0
	main.charge = 0.0
	var a_last := _make_item(main, &"plate")
	main.register_collection(a_last)  # причина 1: полный трюм → авто-возврат
	main.advance_flight(1.0)  # причина 2: пустой заряд — уже DOCK
	main.request_return()  # причина 3: ручная — уже DOCK
	main.unload()  # повторные сигналы разгрузки
	main.unload()
	_check(main.economy.scrap == scrap_a + pp, "simultaneous A (full cargo first): single payout",
		"got %d expected %d" % [main.economy.scrap, scrap_a + pp])
	_check(main.cargo_mass == 0 and is_equal_approx(main.charge, main.max_charge()),
		"simultaneous A: cargo cleared, charge refilled", "")
	var a_after := _make_item(main, &"nut")
	main.register_collection(a_after)  # сбор после возврата в DOCK невозможен
	_check(not a_after.collected and main.cargo_mass == 0, "simultaneous A: no collection in DOCK", "")
	a_after.free()

	# Порядок B: заряд опустошается раньше последнего сбора.
	main.launch()
	var scrap_b := main.economy.scrap
	main.cargo_mass = main.capacity() - pm
	main.cargo_value = pp  # стоимость уже собранного в трюме
	main.charge = 0.05
	main.advance_flight(0.1)  # причина 1: пустой заряд → авто-возврат и разгрузка
	var b_item := _make_item(main, &"plate")
	main.register_collection(b_item)  # причина 2: сбор в DOCK — no-op
	main.request_return()  # причина 3
	main.unload()
	_check(main.economy.scrap == scrap_b + pp, "simultaneous B (empty charge first): single payout",
		"got %d expected %d" % [main.economy.scrap, scrap_b + pp])
	_check(main.cargo_mass == 0 and is_equal_approx(main.charge, main.max_charge()),
		"simultaneous B: cargo cleared, charge refilled", "")
	_check(not b_item.collected, "simultaneous B: item not collected in DOCK", "")
	b_item.free()

	# Порядок C: ручной возврат раньше остальных причин.
	main.launch()
	var scrap_c := main.economy.scrap
	main.cargo_mass = main.capacity() - pm
	main.cargo_value = pp
	main.charge = 0.0
	main.request_return()  # причина 1: ручная кнопка → авто-разгрузка
	main.advance_flight(1.0)  # причина 2: пустой заряд — уже DOCK
	var c_item := _make_item(main, &"plate")
	main.register_collection(c_item)  # причина 3: сбор в DOCK — no-op
	main.unload()
	_check(main.economy.scrap == scrap_c + pp, "simultaneous C (manual first): single payout",
		"got %d expected %d" % [main.economy.scrap, scrap_c + pp])
	_check(main.cargo_mass == 0 and is_equal_approx(main.charge, main.max_charge()),
		"simultaneous C: cargo cleared, charge refilled", "")
	_check(not c_item.collected, "simultaneous C: item not collected in DOCK", "")
	c_item.free()


## Покупка в DOCK применяет эффекты к магниту/ёмкости; в SALVAGE магазин отключён.
func _test_buy_applies_stats(main: MainGame) -> void:
	main.economy.scrap = 200
	main._on_buy(&"strength")
	_check(main.magnet.strength == 2, "buy: strength applied to magnet", "str=%d" % main.magnet.strength)
	main._on_buy(&"radius")
	_check(is_equal_approx(main.magnet.attraction_radius, 120.0), "buy: radius applied",
		"rad=%f" % main.magnet.attraction_radius)
	main._on_buy(&"capacity")
	_check(main.capacity() == 40, "buy: capacity applied", "cap=%d" % main.capacity())
	main.launch()
	var scrap_before := main.economy.scrap
	main._on_buy(&"capacity")  # в SALVAGE покупка отключена
	_check(main.economy.scrap == scrap_before and main.capacity() == 40,
		"shop disabled in salvage: buy is a no-op", "")
	main.request_return()


## Сила открывает тяжёлый предмет: батарея не собирается при силе 1 и
## собирается после покупки силы (CM-R02/CM-R06).
func _test_strength_unlocks_battery(main: MainGame) -> void:
	main.economy.scrap = 200
	main._on_buy(&"strength")
	main.launch()
	var bat := _make_item(main, &"battery")
	bat.position = main.magnet.position + Vector2(40, 0)
	for i in 30:
		bat.step(1.0 / 60.0)
	_check(bat.collected, "battery: collected with strength 2", "")
	main.request_return()
	main.economy = Economy.new()  # сброс к силе 1
	main._apply_stats()
	main.launch()
	var bat2 := _make_item(main, &"battery")
	bat2.position = main.magnet.position + Vector2(40, 0)
	for i in 30:
		bat2.step(1.0 / 60.0)
	_check(not bat2.collected, "battery: locked at strength 1", "")
	bat2.free()
	main.request_return()


## Магнит не двигается в DOCK (модель состояния SPEC).
func _test_magnet_frozen_in_dock(main: MainGame) -> void:
	main.magnet.position = Vector2(500, 400)
	main.magnet.set_target(Vector2(100, 100))
	var pos := main.magnet.position
	main.magnet._physics_process(0.1)
	_check(main.magnet.position == pos, "dock: magnet frozen", "pos=%s" % main.magnet.position)
	main.launch()
	main.magnet.position = Vector2(500, 400)
	main.magnet._physics_process(0.05)
	_check(main.magnet.position != Vector2(500, 400), "salvage: magnet moves again", "")


## Если на поле не осталось предметов, которые магнит может поднять,
## возрождение даёт доступный тип (гайку) — прогресс не блокируется (SPEC).
func _test_nut_guarantee(main: MainGame) -> void:
	for c in main.spawner.get_children():
		if c is SalvageItem:
			c.free()
	main.spawner.clear_pending_respawns()
	# поле пусто: liftable нет → первый же спавн обязан быть доступным
	main.spawner.notify_collected()
	main.spawner.step(CMConfig.f("field.respawn_delay") + 0.1)
	var spawned: Array = main.spawner.get_children()
	_check(spawned.size() == 1, "nut guarantee: exactly one respawned", "n=%d" % spawned.size())
	if spawned.size() == 1:
		_check(spawned[0].required_strength <= CMConfig.i("magnet.base_strength"),
			"nut guarantee: respawned item is liftable", "req=%d" % spawned[0].required_strength)


## Все интерактивные кнопки и метки HUD лежат внутри окна 1280×720
## (регрессия: офсеты детей панели задаются относительно родителя).
func _test_ui_inside_screen(main: MainGame) -> void:
	var screen := Rect2(0, 0, 1280, 720)
	var ok := true
	var ctx := ""
	for btn: Button in [main.strength_button, main.radius_button, main.capacity_button, main.launch_button, main.return_button]:
		if not screen.encloses(btn.get_global_rect()):
			ok = false
			ctx = "%s rect=%s" % [btn.name, btn.get_global_rect()]
			break
	_check(ok, "ui: all buttons inside the window", ctx)
	_check(screen.encloses(main.scrap_label.get_global_rect()) and screen.encloses(main.stats_label.get_global_rect()),
		"ui: HUD labels inside the window", "")


## Арифметика доступности первой покупки (НЕ измерение времени): полный трюм
## гаек покрывает цену первой силы, а заряда хватает на уверенный вылет.
## Ориентир темпа (15–30 с от первого вылета при уверенном управлении,
## решение Эльдара 2026-10-09) проверяется benchmark-сценарием ниже и живой
## пробой на CM-004 — не этой проверкой.
func _test_first_purchase_affordable() -> void:
	var econ := Economy.new()
	var cap: int = CMConfig.i("flight.cargo_capacity")
	var nut: Dictionary = CMConfig.items()[0]
	var full_nut_value: int = int(nut["price"]) * int(floor(cap / float(nut["mass"])))
	_check(full_nut_value >= econ.upgrade_cost(&"strength"),
		"affordability: full nut cargo covers first strength cost",
		"value=%d cost=%d" % [full_nut_value, econ.upgrade_cost(&"strength")])
	_check(CMConfig.f("flight.charge_seconds") >= 15.0,
		"affordability: charge fits a confident 15s+ sortie",
		"charge=%f" % CMConfig.f("flight.charge_seconds"))


## Автоматический benchmark темпа первой покупки: отдельный экземпляр игры,
## скриптованное «уверенное» управление (скан поля синусоидой), предметы
## притягиваются и собираются только реальными обработчиками, лом начисляется
## только реальной разгрузкой. Прямого заполнения трюма/денег нет.
## Печатает фактические отметки времени (точка отсчёта — первый вылет);
## результат — benchmark управляемого маршрута, не оценка типичного новичка.
func _test_first_purchase_benchmark() -> void:
	var bench: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	bench.launch()
	var t_launch := 0.0
	var sim_t := 0.0
	var dt := 1.0 / 30.0
	var frame := 0
	var unload_times: Array[float] = []
	var purchase_time := -1.0
	var launch_count := 1
	while sim_t < 120.0 and purchase_time < 0.0:
		# Скан поля «уверенного игрока» — тот же паттерн, что водит мышью
		# tools/mouse_timeline.py в CI-видео (период 11с/5.5с, полное поле
		# не накрывается за один проход).
		var target := Vector2(
			460.0 + 430.0 * sin(TAU * sim_t / 11.0),
			380.0 + 220.0 * sin(TAU * sim_t / 5.5 + PI / 3.0)
		)
		if bench.state == MainGame.GameState.SALVAGE:
			bench.magnet.set_target(target)
		bench.magnet.step(dt)
		for c in bench.spawner.get_children():
			if c is SalvageItem:
				c.step(dt)
		bench.advance_flight(dt)
		bench.spawner.step(dt)
		sim_t += dt
		frame += 1
		if frame % 30 == 0:
			await process_frame  # флеш удалений между секундами
		if bench.state == MainGame.GameState.DOCK:
			unload_times.append(sim_t - t_launch)
			if bench.economy.can_buy(&"strength"):
				bench._on_buy(&"strength")
				purchase_time = sim_t - t_launch
			else:
				bench.launch()
				launch_count += 1
	print(
		"BENCHMARK first_purchase after first launch: %.2fs | unloads at: %s | sorties: %d | scrap after purchase: %d" % [
			purchase_time, ", ".join(unload_times.map(func(v: float) -> String: return "%.1fs" % v)), launch_count, bench.economy.scrap]
	)
	_check(purchase_time > 0.0, "benchmark: scripted confident collection buys first strength",
		"no purchase within 120s of simulation")
	_check(purchase_time <= 60.0, "benchmark: purchase within generous 60s sanity bound",
		"t=%.2fs (agreed target 15-30s)" % purchase_time)
	bench.free()
