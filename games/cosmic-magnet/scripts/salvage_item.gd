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
var clamp_id := -1
var cover_id := -1
var discovery: StringName = &""

var _hint := ""
## Чисто визуальные поля: фаза бобинга и сила притяжения (0..1) для анимации.
var _phase := 0.0
var _pull := 0.0

func setup(type_def: Dictionary) -> void:
	item_id = StringName(type_def.get("id", &"nut"))
	required_strength = int(type_def.get("required_strength", 1))
	mass = int(type_def.get("mass", 1))
	price = int(type_def.get("price", 1))
	visual_radius = float(type_def.get("radius", 7.0))
	color = type_def.get("color", Color.WHITE)
	rotation = 0.0 if item_id == &"skiff" else randf() * TAU
	_phase = randf() * TAU


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if collected or game == null:
		return
	if discovery in [&"relay", &"clamp"]:
		queue_redraw()
		return
	if item_id != &"skiff":
		rotation += 0.4 * delta
	_pull = maxf(_pull - delta * 2.0, 0.0)
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
	var fits := game.can_take(mass) or (is_unique and discovery != &"skiff")
	if discovery != &"" and game.site != null and not game.site.can_collect(self):
		_hint = "MODULE?" if discovery == &"skiff" and not game.site.module_found else "PULSE?" if discovery == &"skiff" and not game.pulse.unlocked() else "CHAIN" if discovery == &"skiff" and game.site.released.size() < CMConfig.i("site.clamp_count") else "FULL" if not fits else "S%d?" % required_strength
		queue_redraw()
		return
	_hint = ""
	if not can_lift and dist <= magnet_node.attraction_radius:
		_hint = "S%d?" % required_strength
	elif can_lift and not fits and dist <= magnet_node.attraction_radius:
		_hint = "FULL"
	if not can_lift or not fits:
		queue_redraw()
		return

	if discovery == &"skiff":
		_hint = "PULSE" if not game.pulse.affects(self) else "TOW"
		game.site.tow(self,delta)
		queue_redraw()
		return

	if dist <= CMConfig.f("magnet.capture_radius"):
		_collect()
		return

	var pulsed := game.pulse != null and game.pulse.affects(self)
	if dist > magnet_node.attraction_radius and not pulsed:
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
	if pulsed:
		speed = minf(speed * CMConfig.f("pulse.speed_multiplier"), CMConfig.f("pulse.max_speed"))
	# Визуальный отклик: предмет «оживает» на притяжении — крутится быстрее.
	_pull = clampf(_pull + delta * 3.0, 0.0, 1.0)
	if item_id != &"skiff":
		rotation += delta * 1.8 * _pull
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
	&"nut": preload("res://assets/void/nut.svg"),
	&"plate": preload("res://assets/void/plate.svg"),
}

func _draw() -> void:
	if discovery in [&"relay", &"clamp"]:
		draw_set_transform(Vector2.ZERO,-rotation)
		if discovery == &"relay":
			VoidArt.draw_sheet(self,VoidArt.RELAY,Rect2(-24,-24,48,48),game.visual_time,Vector2(32,32))
		else:
			draw_rect(Rect2(-15,-11,30,22),Color("393646"))
			draw_rect(Rect2(-15,-11,6,22),Color("dc9362"))
			draw_rect(Rect2(9,-11,6,22),Color("dc9362"))
			draw_rect(Rect2(-9,-4,18,8),Color("9a7869"))
		if game.magnet.position.distance_to(position) < 100 and game.state == MainGame.GameState.SALVAGE:
			draw_string(ThemeDB.fallback_font,Vector2(-35,33),"RELAY" if discovery == &"relay" else "CLAMP",HORIZONTAL_ALIGNMENT_CENTER,70,11,Color("b8d6de"))
		return
	var t := game.visual_time
	var size := visual_radius * 3.8 * (1.0 + 0.10 * _pull)
	var texture: Texture2D = VoidArt.SKIFF if item_id == &"skiff" else ART.get(item_id, ART[&"nut"])
	# Мягкий бобинг поверх геймплейной позиции (только отрисовка).
	draw_set_transform(Vector2(0.0, sin(t * 1.7 + _phase) * 2.5), rotation, Vector2.ONE)
	if cover_id >= 0:
		draw_arc(Vector2.ZERO, size * 0.65, -PI/4, PI*1.25, 32, Color(0.95,0.72,0.4,0.65), 1.2, true)
	if is_unique and item_id != &"skiff":
		var pulse := 1.0 + 0.12 * sin(t * 2.2)
		for i in range(4, 0, -1):
			draw_circle(Vector2.ZERO, size * (0.65 + i * 0.13) * pulse, Color(1.0, 0.7, 0.25, 0.018))
		draw_arc(Vector2.ZERO, size * 0.85 * pulse, 0.0, TAU, 48, Color(1.0, 0.78, 0.36, 0.55), 1.0, true)
		# Три искры на орбите — находку видно даже краем глаза.
		for i in 3:
			var angle := t * 1.9 + float(i) * TAU / 3.0 + _phase
			var orbit := size * (1.05 + 0.08 * sin(t * 2.6 + float(i)))
			draw_circle(Vector2.from_angle(angle) * orbit, 1.8, Color(1.0, 0.85, 0.45, 0.85))
	if item_id == &"skiff":
		# Rotate only artwork: towing coordinates/save data do not change.
		draw_set_transform(Vector2(0,sin(t*1.7+_phase)*2),-PI/2)
		var rect := Rect2(-48,-48,96,96)
		draw_texture_rect(VoidArt.SKIFF,rect,false)
		draw_texture_rect(VoidArt.ENGINE,rect,false)
		# Rescue engines wake only while the actual tow impulse is moving the ship.
		if game.pulse.affects(self) and game.site.can_collect(self):
			VoidArt.draw_sheet(self,VoidArt.POWER,rect,t,Vector2(48,48))
	elif item_id == &"battery" or item_id == &"relic_core":
		VoidArt.draw_sheet(self,VoidArt.MODULE if item_id == &"relic_core" else VoidArt.BATTERY,Rect2(-size/2,-size/2,size,size),t+_phase,Vector2(32,32))
	else:
		draw_texture_rect(texture,Rect2(-Vector2.ONE*size/2,Vector2.ONE*size),false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
