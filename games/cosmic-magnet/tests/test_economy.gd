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
	_test_first_purchase_reachable(main)
	_test_ui_inside_screen(main)

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


## Одновременные причины возврата (полный трюм + пустой заряд + ручная кнопка
## + прямой повтор разгрузки) дают одну разгрузку и одно начисление.
func _test_simultaneous_return_reasons_single_payout(main: MainGame) -> void:
	main.launch()
	var scrap_before := main.economy.scrap
	var item := _make_item(main, &"plate")
	main.register_collection(item)
	var gained := int(item.price)
	main.charge = 0.0  # зарядная причина готова simultанно с ручной
	main.request_return()  # причина 1: ручная кнопка (внутри — авто-разгрузка)
	main.advance_flight(1.0)  # причина 2: пустой заряд — уже DOCK, no-op
	main.unload()  # причина 3: прямой повторный сигнал разгрузки
	_check(main.economy.scrap == scrap_before + gained, "simultaneous: paid exactly once",
		"scrap=%d expected=%d" % [main.economy.scrap, scrap_before + gained])
	_check(main.cargo_mass == 0 and is_equal_approx(main.charge, main.max_charge()),
		"simultaneous: cargo cleared and charge refilled", "")


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


## Первая покупка достижима за 60–120 с обычной игры: полный трюм гаек
## стоит больше цены первой силы, а полный трюм собирается максимум за
## два вылета по заряду из конфига.
func _test_first_purchase_reachable(main: MainGame) -> void:
	var cap := main.capacity()
	var nut := _item_def(&"nut")
	var full_nut_value: int = int(nut["price"]) * int(floor(cap / float(nut["mass"])))
	var econ := Economy.new()
	_check(full_nut_value >= econ.upgrade_cost(&"strength"),
		"first purchase: full nut cargo covers first strength cost",
		"value=%d cost=%d" % [full_nut_value, econ.upgrade_cost(&"strength")])
	_check(2.0 * CMConfig.f("flight.charge_seconds") <= 120.0,
		"first purchase: two sorties fit into 120s",
		"2×charge=%f" % (2.0 * CMConfig.f("flight.charge_seconds")))
