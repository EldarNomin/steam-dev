class_name Spawner
extends Node2D
## Пополняет поле обычными предметами (CM-R08). На поле не больше max_items;
## собранный предмет ставится в очередь возрождения и обязательно
## возвращается, когда освобождается место. Доступные гайки спавнятся всегда:
## если на поле не осталось предметов, которые магнит может поднять, спавнится
## гайка — прогресс нельзя заблокировать покупкой одного направления.

var game: MainGame
# Соседний узел: @onready у MainGame ещё не разрешён во время нашего _ready.
@onready var magnet: Magnet = get_parent().get_node("Magnet")

var _respawn_queue: Array[float] = []
var _defs_cache: Array = []


func _ready() -> void:
	game = get_parent() as MainGame
	_defs_cache = CMConfig.items()
	_fill_field()
	game.notify_field_changed()


## Первичное заполнение: микс по весам + уникальная находка, если она ещё
## не собрана в этом забеге (CM-R08: не возрождается после сбора).
func _fill_field() -> void:
	var cap := CMConfig.i("field.max_items")
	var relic_spawned := false
	var relic: Dictionary = CMConfig.unique_item()
	if not relic.is_empty() and not game.unique_collected:
		_spawn_item(relic, true)
		relic_spawned = true
	var schedule := _initial_schedule()
	for i in mini(cap - (1 if relic_spawned else 0), schedule.size()):
		_spawn_item(schedule[i])


## Сброс поля для новой игры (меню): всё очищается и заполняется заново.
func reset_field() -> void:
	for c in get_children():
		if c is SalvageItem:
			c.free()
	_respawn_queue.clear()
	_fill_field()
	game.notify_field_changed()


## Начальный микс по весам: 50% гаек / 30% пластин / 20% аккумуляторов.
func _initial_schedule() -> Array:
	var schedule: Array = []
	var total := 0.0
	for def in _defs_cache:
		total += float(def.get("weight", 1))
	for def in _defs_cache:
		var cnt := int(round(float(def.get("weight", 1)) / total * CMConfig.i("field.max_items")))
		for i in cnt:
			schedule.append(def)
	return schedule


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _respawn_queue.is_empty():
		return
	for i in _respawn_queue.size():
		_respawn_queue[i] -= delta
	while (
		not _respawn_queue.is_empty()
		and _respawn_queue[0] <= 0.0
		and _field_count() < CMConfig.i("field.max_items")
	):
		_respawn_queue.remove_at(0)
		_spawn_item(_pick_type())
	game.notify_field_changed()


func notify_collected() -> void:
	_respawn_queue.append(CMConfig.f("field.respawn_delay"))


## Для тестов: сбросить отложенные возрождения.
func clear_pending_respawns() -> void:
	_respawn_queue.clear()


## Возрождение даёт только типы, которые магнит уже может поднять (SPEC:
## «всегда спавнятся доступные гайки»; батареи из начального микса остаются
## на поле как видимый стимул прокачки и пополняются после покупки силы).
func _pick_type() -> Dictionary:
	var pool: Array = []
	for def in _defs_cache:
		if int(def["required_strength"]) <= magnet.strength:
			pool.append(def)
	if pool.is_empty():
		pool = _defs_cache
	var total := 0.0
	for def in pool:
		total += float(def.get("weight", 1))
	var roll := randf() * total
	for def in pool:
		roll -= float(def.get("weight", 1))
		if roll <= 0.0:
			return def
	return pool[0]


func _spawn_item(type_def: Dictionary, unique := false) -> void:
	if _field_count() >= CMConfig.i("field.max_items") and not unique:
		return
	var item := SalvageItem.new()
	item.game = game
	item.setup(type_def)
	item.is_unique = unique
	item.position = _random_spawn_position()
	add_child(item)


## Поле минус поля UI и минус область притяжения магнита (GAME-SPEC, «Спавн»).
func _random_spawn_position() -> Vector2:
	var r := CMConfig.FIELD_RECT.grow(-CMConfig.f("field.spawn_inset"))
	var pos := Vector2.ZERO
	for i in 64:
		pos = Vector2(
			randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y)
		)
		if game.site != null and game.site.excludes(pos):
			continue
		if pos.distance_to(magnet.position) > magnet.attraction_radius:
			return pos
	return pos


func _field_count() -> int:
	var n := 0
	for c in get_children():
		if c is SalvageItem and not c.collected:
			n += 1
	return n


func field_count() -> int:
	return _field_count()
