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
	_test_strict_validation()
	_test_backup_never_overwritten_by_corrupt_main()
	_test_write_failure_keeps_files_intact()
	_test_quarantine_and_confirmed_new_game()
	_test_midflight_close_no_cargo_credit()
	_test_relic_payout_survives_midflight_exit()
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
	SaveService.save_data({"scrap": 10, "levels": {"strength": 0, "radius": 0, "capacity": 0}, "unique_collected": false,
		"tutorial_stage": 0, "settings": {"master_volume": 0.8}})
	SaveService.save_data({"scrap": 99, "levels": {"strength": 0, "radius": 0, "capacity": 0}, "unique_collected": false,
		"tutorial_stage": 2, "settings": {"master_volume": 0.8}})
	_write_raw(SaveService._main_path(), "{broken json,,,")
	var d := SaveService.load_data()
	_check(int(d.get("scrap", -1)) == 10 and int(d.get("tutorial_stage", -1)) == 0,
		"corrupt main: recovered previous save from backup", str(d))
	_check(SaveService._parse_valid(SaveService._read_raw(SaveService._main_path())).get("scrap", -1) == 10,
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


## F3: строгая валидация — целые числа, диапазоны, лимиты конфига,
## неизвестные ключи уровней.
func _test_strict_validation() -> void:
	SaveService.wipe_files()
	var base := {"version": SaveService.SAVE_VERSION, "unique_collected": false,
		"tutorial_stage": 2, "settings": {"master_volume": 0.8}}
	var good_levels := {"strength": 1, "radius": 0, "capacity": 2}
	var cases := {
		"fractional scrap": {"scrap": 4.5, "levels": good_levels},
		"negative scrap": {"scrap": -1, "levels": good_levels},
		"huge scrap": {"scrap": SaveService.MAX_SCRAP + 1.0, "levels": good_levels},
		"level beyond config cap": {"scrap": 1, "levels": {"strength": 99, "radius": 0, "capacity": 0}},
		"negative level": {"scrap": 1, "levels": {"strength": -1, "radius": 0, "capacity": 0}},
		"fractional level": {"scrap": 1, "levels": {"strength": 1.5, "radius": 0, "capacity": 0}},
		"unknown level key": {"scrap": 1, "levels": {"strength": 1, "radius": 0, "capacity": 0, "luck": 1}},
		"missing level key": {"scrap": 1, "levels": {"strength": 1, "radius": 0}},
		"fractional tutorial": {"scrap": 1, "levels": good_levels, "tutorial_stage": 2.5},
		"negative tutorial": {"scrap": 1, "levels": good_levels, "tutorial_stage": -1},
		"string scrap": {"scrap": "42", "levels": good_levels},
	}
	for case_name: String in cases:
		var payload := base.duplicate(true)
		payload.merge(cases[case_name], true)
		_write_raw(SaveService._main_path(), JSON.stringify(payload))
		_write_raw(SaveService._bak_path(), "garbage")
		_check(SaveService.load_data().is_empty(),
			"strict validation: %s rejected" % case_name, "")
	# Валидные целые (JSON отдаёт float) проходят: 42.0 == целое.
	var ok_payload := base.duplicate(true)
	ok_payload["scrap"] = 42
	ok_payload["levels"] = good_levels
	_write_raw(SaveService._main_path(), JSON.stringify(ok_payload))
	_check(SaveService.load_data().get("scrap", 0) == 42,
		"strict validation: integral float accepted", "")


## F1: повреждённый main не перезаписывает валидный .bak при новой записи.
func _test_backup_never_overwritten_by_corrupt_main() -> void:
	SaveService.wipe_files()
	SaveService.save_data({"scrap": 10, "levels": {"strength": 0, "radius": 0, "capacity": 0}, "unique_collected": false,
		"tutorial_stage": 0, "settings": {"master_volume": 0.8}})
	SaveService.save_data({"scrap": 20, "levels": {"strength": 0, "radius": 0, "capacity": 0}, "unique_collected": false,
		"tutorial_stage": 0, "settings": {"master_volume": 0.8}})
	# Теперь bak = scrap 10 (валидный), main = scrap 20. Портим main:
	_write_raw(SaveService._main_path(), "{corrupted,,")
	# Запись при битом main: .bak обязан остаться прежним валидным (scrap 10).
	var ok := SaveService.save_data({"scrap": 777, "levels": {"strength": 0, "radius": 0, "capacity": 0}, "unique_collected": false,
		"tutorial_stage": 0, "settings": {"master_volume": 0.8}})
	_check(ok, "backup guard: save with corrupt main succeeds", "")
	var bak := SaveService._parse_valid(SaveService._read_raw(SaveService._bak_path()))
	_check(bak.get("scrap", -1) == 10, "backup guard: corrupt main did not overwrite valid .bak",
		str(bak))
	var main := SaveService._parse_valid(SaveService._read_raw(SaveService._main_path()))
	_check(main.get("scrap", -1) == 777, "backup guard: main holds fresh data", str(main))


## F1: сбои записи — занятые tmp/main пути возвращают false и не портят файлы.
func _test_write_failure_keeps_files_intact() -> void:
	SaveService.wipe_files()
	SaveService.save_data({"scrap": 55, "levels": {"strength": 0, "radius": 0, "capacity": 0}, "unique_collected": false,
		"tutorial_stage": 1, "settings": {"master_volume": 0.8}})
	SaveService.save_data({"scrap": 56, "levels": {"strength": 0, "radius": 0, "capacity": 0}, "unique_collected": false,
		"tutorial_stage": 1, "settings": {"master_volume": 0.8}})
	# Теперь main = 56, bak = 55.
	var payload := {"scrap": 66, "levels": {"strength": 0, "radius": 0, "capacity": 0}, "unique_collected": false,
		"tutorial_stage": 1, "settings": {"master_volume": 0.8}}
	# tmp занят каталогом → запись невозможна.
	DirAccess.make_dir_recursive_absolute(SaveService._tmp_path())
	_check(not SaveService.save_data(payload), "write failure: tmp-as-directory returns false", "")
	DirAccess.remove_absolute(SaveService._tmp_path())
	_check(SaveService._parse_valid(SaveService._read_raw(SaveService._main_path())).get("scrap", -1) == 56,
		"write failure: main untouched", "")
	# main занят каталогом → rename невозможен, всё цело.
	DirAccess.remove_absolute(SaveService._main_path())
	DirAccess.make_dir_recursive_absolute(SaveService._main_path())
	_check(not SaveService.save_data(payload), "write failure: main-as-directory returns false", "")
	DirAccess.remove_absolute(SaveService._main_path())
	_check(SaveService._parse_valid(SaveService._read_raw(SaveService._bak_path())).get("scrap", -1) == 55,
		"write failure: bak untouched", "")


## F4: повреждённые main+bak уходят в *.corrupt карантин; перезапись — только
## через подтверждённый новый забег.
func _test_quarantine_and_confirmed_new_game() -> void:
	SaveService.wipe_files()
	var game: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.economy.scrap = 123
	game.save_now()
	_write_raw(SaveService._main_path(), "{damaged main")
	_write_raw(SaveService._bak_path(), "{damaged bak")
	game.queue_free()

	var game2: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game2)
	game2.continue_game()
	_check(game2.new_game_confirm.visible and SaveService.corrupt_files_quarantined,
		"quarantine: corrupt save asks for confirmation instead of silent rewrite", "")
	_check(FileAccess.file_exists(SaveService._main_path() + ".corrupt")
		and FileAccess.file_exists(SaveService._bak_path() + ".corrupt"),
		"quarantine: diagnostic .corrupt copies saved", "")
	var diag := FileAccess.open(SaveService._main_path() + ".corrupt", FileAccess.READ).get_as_text()
	_check(diag == "{damaged main", "quarantine: diagnostic copy holds damaged content", diag)
	_check(SaveService._read_raw(SaveService._main_path()) == "{damaged main",
		"quarantine: damaged files not overwritten before confirmation", "")
	game2.confirm_new_game()
	_check(not game2.new_game_confirm.visible and game2.economy.scrap == 0,
		"quarantine: confirmed new game starts fresh", "")
	_check(FileAccess.file_exists(SaveService._main_path() + ".corrupt"),
		"quarantine: diagnostic copies survive the rewrite", "")
	game2.queue_free()


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


## F2: стоимость реликвии не теряется при выходе посреди вылета — она
## выплачивается сразу при сборе, минуя груз (CM-R08 делает находку
## невосполнимой, поэтому грузовая модель для неё запрещена).
func _test_relic_payout_survives_midflight_exit() -> void:
	var game: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.launch()
	var relic: SalvageItem = null
	for c in game.spawner.get_children():
		if c is SalvageItem and c.is_unique:
			relic = c
	if relic == null:
		_check(false, "relic payout: relic present in fresh run", "")
		game.queue_free()
		return
	var price := int(CMConfig.unique_item()["price"])
	game.register_collection(relic)
	_check(game.economy.scrap == price and game.cargo_mass == 0,
		"relic payout: credited immediately, not via cargo",
		"scrap=%d cargo=%d" % [game.economy.scrap, game.cargo_mass])
	_check(game.unique_collected, "relic payout: find registered", "")
	# Немного обычного груза и выход посреди вылета: груз сбрасывается,
	# выплата за реликвию остаётся.
	for c in game.spawner.get_children():
		if c is SalvageItem and not c.is_unique and not c.collected and c.required_strength <= game.magnet.strength:
			game.register_collection(c)
			break
	game.save_on_exit()
	_check(game.economy.scrap == price,
		"relic payout: survives midflight exit", "scrap=%d" % game.economy.scrap)
	var d := SaveService.load_data()
	_check(float(d.get("scrap", 0)) == float(price) and bool(d.get("unique_collected", false)),
		"relic payout: file holds credited scrap and collected flag", str(d))
	var game3: MainGame = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game3)
	game3.continue_game()
	_check(game3.economy.scrap == price and game3.cargo_mass == 0,
		"relic payout: restored after reload", "scrap=%d" % game3.economy.scrap)
	var relic2: SalvageItem = null
	for c in game3.spawner.get_children():
		if c is SalvageItem and c.is_unique:
			relic2 = c
	_check(relic2 == null, "relic payout: no relic after restart of the same run", "")
	game.queue_free()
	game3.queue_free()


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
