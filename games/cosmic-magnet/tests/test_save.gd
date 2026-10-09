extends SceneTree
## Headless-тест сохранения CM-003 (CM-R10–R12).
## Запуск: godot --headless --path games/cosmic-magnet --script tests/test_save.gd
## Все операции — во временном профиле SaveService (не сохранение игрока);
## профиль создаётся уникальным и удаляется в конце.

var passed := 0
var failed := 0
var profile := ""


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	profile = "user://cm3_tests/run_%d" % (Time.get_ticks_msec() + randi() % 100000)
	SaveService.save_dir = profile
	DirAccess.make_dir_recursive_absolute(profile)
	SaveService.wipe_files()

	_test_roundtrip()
	_test_corrupt_main_recovers_from_backup()
	_test_invalid_version_rejected()
	_test_midflight_close_no_cargo_credit()
	_test_unique_find_not_duplicated()
	_test_levels_and_tutorial_restore()
	_test_volume_persisted()

	SaveService.wipe_files()
	DirAccess.remove_absolute(profile)
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


func _write_raw(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()


func _test_roundtrip() -> void:
	var ok := SaveService.save_data({
		"scrap": 42, "levels": {"strength": 1, "radius": 0, "capacity": 2},
		"unique_collected": true, "tutorial_stage": 4,
		"settings": {"master_volume": 0.5},
	})
	_check(ok, "save: atomic write succeeds", "")
	var d := SaveService.load_data()
	_check(d.get("scrap", 0) == 42 and d.get("unique_collected", false) == true
		and int(d.get("tutorial_stage", -1)) == 4
		and int(d.get("levels", {}).get("capacity", -1)) == 2
		and absf(float(d.get("settings", {}).get("master_volume", 0.0)) - 0.5) < 0.001,
		"save: roundtrip restores all fields", str(d))


func _test_corrupt_main_recovers_from_backup() -> void:
	# A → B: после второй записи bak = A, main = B. Портим main → загрузка
	# восстанавливает A из бакапа и чинит основной файл (CM-R12).
	SaveService.save_data({"scrap": 10, "levels": {}, "unique_collected": false,
		"tutorial_stage": 0, "settings": {"master_volume": 0.8}})
	SaveService.save_data({"scrap": 99, "levels": {}, "unique_collected": false,
		"tutorial_stage": 2, "settings": {"master_volume": 0.8}})
	_write_raw(SaveService._main_path(), "{broken json,,,")
	var d := SaveService.load_data()
	_check(int(d.get("scrap", -1)) == 10 and int(d.get("tutorial_stage", -1)) == 0,
		"corrupt main: recovered previous save from backup", str(d))
	_check(SaveService._read_valid(SaveService._main_path()).get("scrap", -1) == 10,
		"corrupt main: main file repaired from backup", "")


func _test_invalid_version_rejected() -> void:
	_write_raw(SaveService._main_path(), JSON.stringify(
		{"version": 99, "scrap": 5, "levels": {}, "unique_collected": false,
		"tutorial_stage": 0, "settings": {"master_volume": 0.8}}))
	var d := SaveService.load_data()
	_check(int(d.get("version", -1)) == SaveService.SAVE_VERSION,
		"invalid version: rejected main, backup served", str(d))
	# Оба файла невалидны → безопасный пустой результат (новая игра).
	_write_raw(SaveService._main_path(), "garbage")
	_write_raw(SaveService._bak_path(), "garbage")
	_check(SaveService.load_data().is_empty(), "invalid everywhere: safe empty state", "")


## CM-R11: закрытие посреди вылета — незавершённый груз не начисляется,
## выгруженный лом и покупки не теряются, следующая загрузка — в DOCK.
func _test_midflight_close_no_cargo_credit() -> void:
	var game: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.economy.scrap = 30
	game._on_buy(&"strength")  # scrap 10, сила 2, сохранение при покупке
	_check(game.magnet.strength == 2, "midflight: strength bought", "")
	game.launch()
	game.cargo_mass = 10
	game.cargo_value = 40  # незавершённый груз
	game.save_on_exit()  # штатное сохранение при выходе (без quit)
	_check(game.cargo_mass == 0 and game.state == MainGame.GameState.DOCK,
		"midflight close: cargo dropped, back to dock", "")

	var game2: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game2)
	game2.continue_game()
	_check(game2.economy.scrap == 10, "midflight close: unloaded scrap kept, cargo not credited",
		"scrap=%d" % game2.economy.scrap)
	_check(game2.state == MainGame.GameState.DOCK and is_equal_approx(game2.charge, game2.max_charge()),
		"midflight close: loaded into safe dock with full charge", "")
	_check(game2.magnet.strength == 2, "midflight close: purchased levels restored", "")
	_check(game2.cargo_mass == 0 and game2.cargo_value == 0, "midflight close: no phantom cargo", "")
	game.queue_free()
	game2.queue_free()


## CM-R08: уникальная находка не возрождается после сбора и перезапуска.
func _test_unique_find_not_duplicated() -> void:
	var game: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var relic: SalvageItem = null
	for c in game.spawner.get_children():
		if c is SalvageItem and c.is_unique:
			relic = c
	_check(relic != null, "unique: relic present in a fresh run", "")
	game.launch()
	if relic != null:
		game.register_collection(relic)
	_check(game.unique_collected, "unique: collection registered", "")
	game.queue_free()

	var game2: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game2)
	game2.continue_game()
	var relic2: SalvageItem = null
	for c in game2.spawner.get_children():
		if c is SalvageItem and c.is_unique:
			relic2 = c
	_check(relic2 == null and game2.unique_collected,
		"unique: no relic after restart of the same run", "")
	game2.new_game()
	var relic3: SalvageItem = null
	for c in game2.spawner.get_children():
		if c is SalvageItem and c.is_unique:
			relic3 = c
	_check(relic3 != null, "unique: a brand-new run offers the relic again", "")
	game2.queue_free()


func _test_levels_and_tutorial_restore() -> void:
	var game: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.economy.scrap = 1000
	game._on_buy(&"radius")
	game._on_buy(&"capacity")
	game.tutorial_stage = 4
	game.save_now()
	game.queue_free()

	var game2: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game2)
	game2.continue_game()
	_check(game2.economy.level(&"radius") == 1 and game2.economy.level(&"capacity") == 1,
		"restore: purchased levels restored", "")
	_check(game2.economy.scrap == 1000 - 15 - 15, "restore: scrap spent on purchases", "")
	_check(is_equal_approx(game2.magnet.attraction_radius, 120.0) and game2.capacity() == 40,
		"restore: effects applied to stats", "")
	_check(game2.tutorial_stage == 4, "restore: tutorial stage persisted", "")
	game2.queue_free()


func _test_volume_persisted() -> void:
	var game: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game._on_volume_changed(35.0)
	_check(absf(game.master_volume - 0.35) < 0.001, "settings: volume slider applied", "")
	var d := SaveService.load_data()
	_check(absf(float(d.get("settings", {}).get("master_volume", 0.0)) - 0.35) < 0.001,
		"settings: volume persisted immediately", "")
	game.queue_free()
	var game2: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game2)
	game2.continue_game()
	_check(absf(game2.master_volume - 0.35) < 0.001, "settings: volume restored", "")
	game2.queue_free()
