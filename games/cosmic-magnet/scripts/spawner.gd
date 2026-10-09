class_name Spawner
extends Node2D
## Пополняет поле обычными предметами (CM-R08, часть для CM-001).
## На поле не больше MAX_ITEMS; собранный предмет ставится в очередь
## возрождения и обязательно возвращается, когда освобождается место.

var game: MainGame
# Соседний узел: @onready у MainGame ещё не разрешён во время нашего _ready.
@onready var magnet: Magnet = get_parent().get_node("Magnet")

var _respawn_queue: Array[float] = []


func _ready() -> void:
	game = get_parent() as MainGame
	# Начальное заполнение — детерминированный микс двух типов.
	for i in CMConfig.MAX_ITEMS:
		_spawn_item(CMConfig.ITEM_TYPES[i % CMConfig.ITEM_TYPES.size()])
	game.notify_field_changed()


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
		and _field_count() < CMConfig.MAX_ITEMS
	):
		_respawn_queue.remove_at(0)
		_spawn_item(CMConfig.ITEM_TYPES.pick_random())
	game.notify_field_changed()


func notify_collected() -> void:
	_respawn_queue.append(CMConfig.RESPAWN_DELAY)


func _spawn_item(type_def: Dictionary) -> void:
	if _field_count() >= CMConfig.MAX_ITEMS:
		return
	var item := SalvageItem.new()
	item.game = game
	item.setup(type_def)
	item.position = _random_spawn_position()
	add_child(item)


## Поле минус поля UI и минус область притяжения магнита (GAME-SPEC, «Спавн»).
func _random_spawn_position() -> Vector2:
	var r := CMConfig.FIELD_RECT.grow(-CMConfig.SPAWN_INSET)
	var pos := Vector2.ZERO
	for i in 64:
		pos = Vector2(
			randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y)
		)
		if pos.distance_to(magnet.position) > CMConfig.ATTRACTION_RADIUS:
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
