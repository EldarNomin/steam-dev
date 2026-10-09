class_name SaveService
extends RefCounted
## Сохранение CM-003 (CM-R10–R12). Файл: user://cosmic_magnet/save_v1.json.
## Версия в файле, валидация при чтении, атомарная запись через tmp с
## сохранением предыдущей версии в .bak и восстановлением из него.
## Тесты подменяют save_dir на отдельный временный профиль (не сохранение
## игрока) и очищают его в конце.

const SAVE_VERSION := 1

## Точка подмены профиля для тестов.
static var save_dir := "user://cosmic_magnet"


static func _main_path() -> String:
	return save_dir + "/save_v1.json"


static func _bak_path() -> String:
	return save_dir + "/save_v1.json.bak"


static func _tmp_path() -> String:
	return save_dir + "/save_v1.json.tmp"


static func has_save() -> bool:
	return FileAccess.file_exists(_main_path()) or FileAccess.file_exists(_bak_path())


## Атомарная запись (CM-R12): tmp → бакап старого → rename. Сбой на любом
## шаге оставляет предыдущий целый файл (или его бакап).
static func save_data(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	if DirAccess.make_dir_recursive_absolute(save_dir) != OK:
		if not DirAccess.dir_exists_absolute(save_dir):
			return false
	var f := FileAccess.open(_tmp_path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.flush()
	f.close()
	if FileAccess.file_exists(_main_path()):
		DirAccess.copy_absolute(_main_path(), _bak_path())
	return DirAccess.rename_absolute(_tmp_path(), _main_path()) == OK


## Чтение с восстановлением: основной файл бит/невалиден → пробуем .bak и
## возвращаем его в основной. Оба нечитаемы → {} (безопасный старт новой игры),
## никаких падений и тихой потери единственной копии.
static func load_data() -> Dictionary:
	var main := _read_valid(_main_path())
	if not main.is_empty():
		return main
	var backup := _read_valid(_bak_path())
	if not backup.is_empty():
		DirAccess.copy_absolute(_bak_path(), _main_path())
		return backup
	return {}


static func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not is_valid_save(parsed):
		return {}
	return parsed


## Жёсткая валидация: версия, типы и диапазоны. Невалидный файл = битый.
static func is_valid_save(d: Variant) -> bool:
	if not (d is Dictionary) or int(d.get("version", -1)) != SAVE_VERSION:
		return false
	if d.get("scrap") is not float and d.get("scrap") is not int:
		return false
	if float(d.get("scrap", -1.0)) < 0.0:
		return false
	var levels: Variant = d.get("levels")
	if not (levels is Dictionary):
		return false
	for key: String in ["strength", "radius", "capacity"]:
		var v: Variant = levels.get(key, 0)
		if v is not int and v is not float:
			return false
		if int(v) < 0 or int(v) > 99:
			return false
	if d.get("unique_collected") is not bool:
		return false
	if d.get("tutorial_stage") is not int and d.get("tutorial_stage") is not float:
		return false
	var settings: Variant = d.get("settings")
	if not (settings is Dictionary):
		return false
	var vol: Variant = settings.get("master_volume", 0.8)
	if vol is not int and vol is not float:
		return false
	return float(vol) >= 0.0 and float(vol) <= 1.0


## Полная очистка профиля (тесты).
static func wipe_files() -> void:
	for p: String in [_main_path(), _bak_path(), _tmp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
