class_name SalvageItem
extends Node2D
## Обычный предмет свалки (CM-R02, CM-R03). Притяжение — движение по delta
## с ограничением скорости; шаг клампится остатком дистанции, поэтому большой
## delta не может «перепрыгнуть» радиус захвата. Сбор проходит ровно один раз
## через единственный обработчик в MainGame.register_collection().

var game: MainGame
var item_id: StringName = &"nut"
var required_strength := 1
var visual_radius := 7.0
var color := Color.WHITE
var collected := false

var _hint_visible := false


func setup(type_def: Dictionary) -> void:
	item_id = type_def.get("id", &"nut")
	required_strength = int(type_def.get("required_strength", 1))
	visual_radius = float(type_def.get("radius", 7.0))
	color = type_def.get("color", Color.WHITE)
	rotation = randf() * TAU


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if collected or game == null:
		return
	rotation += 0.4 * delta
	var magnet_pos := game.magnet.position
	var to_magnet := magnet_pos - position
	var dist := to_magnet.length()

	if dist <= CMConfig.CAPTURE_RADIUS:
		_collect()
		return

	var can_lift := required_strength <= game.magnet.strength
	# Тяжёлый предмет остаётся на месте и показывает требуемую силу (CM-R02).
	_hint_visible = (not can_lift) and dist <= CMConfig.ATTRACTION_RADIUS

	if not can_lift or dist > CMConfig.ATTRACTION_RADIUS:
		queue_redraw()
		return

	# Скорость растёт ближе к магниту — плавное притяжение.
	var speed: float = remap(
		dist,
		CMConfig.CAPTURE_RADIUS,
		CMConfig.ATTRACTION_RADIUS,
		CMConfig.ITEM_SPEED_MAX,
		CMConfig.ITEM_SPEED_MIN,
	)
	speed = clampf(speed, CMConfig.ITEM_SPEED_MIN, CMConfig.ITEM_SPEED_MAX)
	# Кламп остатком дистанции: предмет не пролетает сквозь магнит ни при каком delta.
	var move := minf(speed * delta, dist - CMConfig.CAPTURE_RADIUS * 0.5)
	move = maxf(move, 0.0)
	position += to_magnet / dist * move
	if position.distance_to(magnet_pos) <= CMConfig.CAPTURE_RADIUS:
		_collect()
	else:
		queue_redraw()


func is_hint_visible() -> bool:
	return _hint_visible


func _collect() -> void:
	if collected:
		return
	collected = true
	game.register_collection(self)


func _draw() -> void:
	if item_id == &"plate":
		var half := visual_radius * 0.8
		draw_rect(Rect2(-half, -half * 0.62, half * 2.0, half * 1.24), color)
		draw_rect(
			Rect2(-half, -half * 0.62, half * 2.0, half * 1.24),
			Color(0.1, 0.1, 0.12),
			false,
			1.5,
		)
	else:
		draw_circle(Vector2.ZERO, visual_radius, color)
		draw_circle(Vector2.ZERO, visual_radius * 0.42, Color("1c2438"))
	if _hint_visible:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-14.0, -visual_radius - 6.0),
			"S%d?" % required_strength,
			HORIZONTAL_ALIGNMENT_CENTER,
			28.0,
			11,
			Color("e8a33d"),
		)
