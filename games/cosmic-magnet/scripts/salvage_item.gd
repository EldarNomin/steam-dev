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
	# Уникальная находка не занимает груз — гейт ёмкости к ней не применяется.
	var fits := game.can_take(mass) or is_unique
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


const ART := {
	&"nut": preload("res://assets/art/nut.svg"),
	&"plate": preload("res://assets/art/plate.svg"),
	&"battery": preload("res://assets/art/battery.svg"),
	&"relic_core": preload("res://assets/art/relic.svg"),
}

func _draw() -> void:
	var size := visual_radius * 3.8
	var texture: Texture2D = ART.get(item_id, ART[&"nut"])
	if is_unique:
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 450.0)
		for i in range(4, 0, -1):
			draw_circle(Vector2.ZERO, size * (0.65 + i * 0.13) * pulse, Color(1.0, 0.7, 0.25, 0.018))
		draw_arc(Vector2.ZERO, size * 0.85 * pulse, 0.0, TAU, 48, Color(1.0, 0.78, 0.36, 0.55), 1.0, true)
	draw_texture_rect(texture, Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size), false)
	if _hint != "":
		# Cancel object rotation so the requirement is always readable.
		draw_set_transform(Vector2.ZERO, -rotation)
		draw_style_box(_hint_box(), Rect2(-22, -size * 0.6 - 19, 44, 18))
		draw_string(ThemeDB.fallback_font, Vector2(-21, -size * 0.6 - 6), _hint, HORIZONTAL_ALIGNMENT_CENTER, 42, 11, Color("ffd490"))

func _hint_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("101f2b")
	box.border_color = Color("6f5841")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	return box
