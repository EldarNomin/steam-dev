class_name SalvageItem
extends Node2D
## Обычный предмет свалки (CM-R02, CM-R03, CM-R04). Притяжение — движение по
## delta с ограничением скорости; шаг клампится остатком дистанции, поэтому
## большой delta не может «перепрыгнуть» радиус захвата. Сбор проходит ровно
## один раз через единственный обработчик в MainGame.register_collection().
## Предмет не собирается, если: не хватает силы ИЛИ он не влезает в трюм —
## в обоих случаях остаётся на месте и показывает подсказку.

var game: MainGame
var item_id: StringName = &"nut"
var required_strength := 1
var mass := 1
var price := 1
var visual_radius := 7.0
var color := Color.WHITE
var collected := false
## Уникальная находка (CM-R08): спавнится один раз за забег, не возрождается.
var is_unique := false

var _hint := ""

func setup(type_def: Dictionary) -> void:
	item_id = StringName(type_def.get("id", &"nut"))
	required_strength = int(type_def.get("required_strength", 1))
	mass = int(type_def.get("mass", 1))
	price = int(type_def.get("price", 1))
	visual_radius = float(type_def.get("radius", 7.0))
	color = type_def.get("color", Color.WHITE)
	rotation = randf() * TAU


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if collected or game == null:
		return
	rotation += 0.4 * delta
	# Поле заморожено вне вылета (DOCK/меню): ничто не ползёт к скрытому магниту.
	if game.state != MainGame.GameState.SALVAGE:
		queue_redraw()
		return
	var magnet_node := game.magnet
	var magnet_pos := magnet_node.position
	var to_magnet := magnet_pos - position
	var dist := to_magnet.length()

	# Недоступный по силе предмет не собирается даже вплотную к магниту (CM-R02)
	# и показывает требуемую силу, пока магнит в радиусе притяжения.
	# Невлезающий в трюм — остаётся на поле с подсказкой FULL (SPEC: груз не
	# превышает ёмкость).
	var can_lift := required_strength <= magnet_node.strength
	var fits := game.can_take(mass)
	_hint = ""
	if not can_lift and dist <= magnet_node.attraction_radius:
		_hint = "S%d?" % required_strength
	elif can_lift and not fits and dist <= magnet_node.attraction_radius:
		_hint = "FULL"
	if not can_lift or not fits:
		queue_redraw()
		return

	if dist <= CMConfig.f("magnet.capture_radius"):
		_collect()
		return

	if dist > magnet_node.attraction_radius:
		queue_redraw()
		return

	# Скорость растёт ближе к магниту — плавное притяжение.
	var speed: float = remap(
		dist,
		CMConfig.f("magnet.capture_radius"),
		magnet_node.attraction_radius,
		CMConfig.f("magnet.item_speed_max"),
		CMConfig.f("magnet.item_speed_min"),
	)
	speed = clampf(speed, CMConfig.f("magnet.item_speed_min"), CMConfig.f("magnet.item_speed_max"))
	# Кламп остатком дистанции: предмет не пролетает сквозь магнит ни при каком delta.
	var move := minf(speed * delta, dist - CMConfig.f("magnet.capture_radius") * 0.5)
	move = maxf(move, 0.0)
	position += to_magnet / dist * move
	if position.distance_to(magnet_pos) <= CMConfig.f("magnet.capture_radius"):
		_collect()
	else:
		queue_redraw()


func is_hint_visible() -> bool:
	return _hint != ""


func hint_text() -> String:
	return _hint


func _collect() -> void:
	# Единственный владелец однократности — MainGame.register_collection.
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
	elif item_id == &"battery":
		draw_rect(Rect2(-visual_radius * 0.55, -visual_radius, visual_radius * 1.1, visual_radius * 2.0), color)
		draw_rect(
			Rect2(-visual_radius * 0.55, -visual_radius, visual_radius * 1.1, visual_radius * 2.0),
			Color(0.1, 0.1, 0.12),
			false,
			1.5,
		)
		draw_rect(Rect2(-visual_radius * 0.2, -visual_radius - 3.0, visual_radius * 0.4, 3.0), color)
	else:
		draw_circle(Vector2.ZERO, visual_radius, color)
		draw_circle(Vector2.ZERO, visual_radius * 0.42, Color("1c2438"))
	if is_unique:
		# Пульсирующие янтарные кольца — находку видно издалека.
		var pulse := 1.4 + 0.35 * sin(Time.get_ticks_msec() / 240.0)
		draw_arc(Vector2.ZERO, visual_radius * pulse, 0.0, TAU, 40, Color("ffd166"), 2.0)
		draw_arc(Vector2.ZERO, visual_radius * pulse * 1.6, 0.0, TAU, 40, Color(1.0, 0.82, 0.4, 0.35), 1.5)
	if _hint != "":
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-18.0, -visual_radius - 6.0),
			_hint,
			HORIZONTAL_ALIGNMENT_CENTER,
			36.0,
			11,
			Color("e8a33d"),
		)
