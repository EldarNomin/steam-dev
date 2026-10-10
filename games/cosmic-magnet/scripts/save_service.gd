class_name SaveService
extends RefCounted
## Сохранение CM-003 (CM-R10–R12). Файл: user://cosmic_magnet/save_v1.json.
## Версия в файле, строгая валидация при чтении (целые числа, диапазоны,
## лимиты конфига, без неизвестных ключей), атомарная запись через tmp.
## Бакап обновляется ТОЛЬКО с валидного main: повреждённый main не может
## перезаписать хороший .bak (F1 ревью). При повреждении и main, и .bak их
## содержимое копируется в диагностические *.corrupt, сами файлы не
## трогаются — перезапись только через подтверждённый новый забег (F4).
## Тесты подменяют save_dir на отдельный временный профиль.

const SAVE_VERSION := 1
const MAX_SCRAP := 999999999
const MAX_TUTORIAL_STAGE := 99

## Точка подмены профиля для тестов.
static var save_dir := "user://cosmic_magnet"

## true после load_data(), если повреждённые файлы были отправлены в карантин.
static var corrupt_files_quarantined := false


static func _main_path() -> String:
	return save_dir + "/save_v1.json"


static func _bak_path() -> String:
	return save_dir + "/save_v1.json.bak"


static func _tmp_path() -> String:
	return save_dir + "/save_v1.json.tmp"


static func has_save() -> bool:
	return FileAccess.file_exists(_main_path()) or FileAccess.file_exists(_bak_path())


static func _read_raw(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Атомарная запись (CM-R12): tmp → бакап валидного main → rename.
## Сбой на любом шаге возвращает false и не портит существующие файлы.
static func save_data(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	if DirAccess.make_dir_recursive_absolute(save_dir) != OK:
		if not DirAccess.dir_exists_absolute(save_dir):
			return false
	var f := FileAccess.open(_tmp_path(), FileAccess.WRITE)
	if f == null:
		return false  # тест: tmp занят каталогом — запись невозможна
	f.store_string(JSON.stringify(payload, "\t"))
	f.flush()
	f.close()
	# Бакапим только валидный main (F1): битый main не затирает хороший .bak.
	# Бакап пишем явной записью строки — copy_absolute на Windows ненадёжен
	# для файлов, созданных rename.
	var main_raw := _read_raw(_main_path())
	if main_raw != "" and not _parse_valid(main_raw).is_empty():
		var bak := FileAccess.open(_bak_path(), FileAccess.WRITE)
		if bak == null:
			# Бакап не обновился — старый .bak остаётся как есть; запись продолжаем.
			push_warning("SaveService: failed to refresh backup, keeping previous .bak")
		else:
			bak.store_string(main_raw)
			bak.close()
	var err := DirAccess.rename_absolute(_tmp_path(), _main_path())
	if err != OK:
		# main не заменён (например, путь занят каталогом) — прибираем tmp.
		DirAccess.remove_absolute(_tmp_path())
		return false
	return true


## Чтение с восстановлением: валидный main → ok; иначе валидный .bak →
## восстанавливаем main; иначе (отсутствуют или оба повреждены) — {} и
## карантин повреждённых в *.corrupt (F4). Никаких падений.
static func load_data() -> Dictionary:
	corrupt_files_quarantined = false
	var main_raw := _read_raw(_main_path())
	var main_d := _parse_valid(main_raw)
	if not main_d.is_empty():
		return main_d
	var bak_raw := _read_raw(_bak_path())
	var bak_d := _parse_valid(bak_raw)
	if not bak_d.is_empty():
		# Восстановление main из бакапа явной записью (copy_absolute
		# на Windows ненадёжен).
		var main_f := FileAccess.open(_main_path(), FileAccess.WRITE)
		if main_f != null:
			main_f.store_string(bak_raw)
			main_f.close()
		else:
			push_warning("SaveService: recovery from backup succeeded, main file not replaced")
		return bak_d
	# Оба отсутствуют или повреждены: повреждённые — в карантин (диагностика).
	if main_raw != "":
		_quarantine(_main_path(), main_raw)
		corrupt_files_quarantined = true
	if bak_raw != "":
		_quarantine(_bak_path(), bak_raw)
		corrupt_files_quarantined = true
	return {}


## Диагностическая копия рядом с оригиналом; сами main/bak не изменяются.
static func _quarantine(path: String, raw: String) -> void:
	var f := FileAccess.open(path + ".corrupt", FileAccess.WRITE)
	if f != null:
		f.store_string(raw)
		f.close()


static func _parse_valid(raw: String) -> Dictionary:
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if not is_valid_save(parsed):
		return {}
	return parsed


## Жёсткая валидация (F3): версия; целые числа без дробной части; диапазоны
## и лимиты из конфига; неизвестные ключи уровней запрещены.
static func is_valid_save(d: Variant) -> bool:
	if not (d is Dictionary) or int(d.get("version", -1)) != SAVE_VERSION:
		return false
	if not _is_integral(d.get("scrap")):
		return false
	var scrap := float(d.get("scrap", -1.0))
	if scrap < 0.0 or scrap > float(MAX_SCRAP):
		return false
	var levels: Variant = d.get("levels")
	if not (levels is Dictionary):
		return false
	var upgrade_defs: Array = CMConfig.upgrades()
	if levels.size() != upgrade_defs.size():
		return false  # неизвестные или недостающие ключи уровней
	for def: Dictionary in upgrade_defs:
		var key: String = String(def["id"])
		if not levels.has(key):
			return false
		if not _is_integral(levels[key]):
			return false
		var lvl := int(levels[key])
		if lvl < 0 or lvl > int(def["max_levels"]):
			return false
	if not _is_integral(d.get("tutorial_stage")):
		return false
	var stage := int(d.get("tutorial_stage", -1))
	if stage < 0 or stage > MAX_TUTORIAL_STAGE:
		return false
	if d.get("unique_collected") is not bool:
		return false
	var settings: Variant = d.get("settings")
	if not (settings is Dictionary):
		return false
	var vol: Variant = settings.get("master_volume")
	if vol is not int and vol is not float:
		return false
	return float(vol) >= 0.0 and float(vol) <= 1.0


## JSON в Godot отдаёт все числа как float; «целое» = число без дробной части.
static func _is_integral(v: Variant) -> bool:
	if v is int:
		return true
	if v is float:
		return absf(v - roundf(v)) < 0.0001
	return false


## Полная очистка профиля (тесты), включая диагностические копии.
static func wipe_files() -> void:
	var names: Array[String] = ["save_v1.json", "save_v1.json.bak", "save_v1.json.tmp",
		"save_v1.json.corrupt", "save_v1.json.bak.corrupt"]
	for n in names:
		var p := save_dir + "/" + n
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
