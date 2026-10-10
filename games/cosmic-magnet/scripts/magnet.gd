class_name Magnet
extends Node2D
## Магнит следует за мышью внутри поля только в SALVAGE (CM-R01, CM-R07):
## в DOCK магнит стоит и скрыт; мышь над HUD или правой панелью не затаскивает
## его в область интерфейса — цель клампится к полю. Радиус притяжения
## растёт улучшением и перерисовывается каждый кадр.

var strength := 1
var attraction_radius := 100.0

var game: MainGame
var _target := Vector2.ZERO
## Затухающая вспышка сбора (0..1): кольцо-волна и подсветка корпуса.
var _flash := 0.0
## Короткий хвост из последних позиций — движение читается плавнее.
var _trail: Array[Vector2] = []


func _ready() -> void:
	game = get_parent() as MainGame
	strength = CMConfig.i("magnet.base_strength")
	attraction_radius = CMConfig.f("magnet.attraction_radius")
	_target = position


## Визуальный хук: presentation вызывает при успешном сборе.
func flash() -> void:
	_flash = 1.0
	queue_redraw()


## Сброс визуального хвоста: при вылете/новой игре магнит «телепортируется»,
## и старый след не должен тянуться за ним (F3 ревью visual-polish).
func reset_trail() -> void:
	_trail.clear()
	_flash = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	# Затухание вспышки НЕ привязано к SALVAGE (F3): иначе DOCK замораживает
	# вспышку прошлого сбора и следующий вылет начинается с чужой подсветкой.
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 2.2, 0.0)
		queue_redraw()
	if game == null or game.state != MainGame.GameState.SALVAGE:
		return
	_target = clamp_to_field(get_global_mouse_position())
	position = position.move_toward(_target, CMConfig.f("magnet.follow_speed") * delta)
	_trail.push_front(position)
	if _trail.size() > 9:
		_trail.resize(9)
	queue_redraw()


## Общая точка входа для шага и для тестов.
func step(delta: float) -> void:
	position = position.move_toward(_target, CMConfig.f("magnet.follow_speed") * delta)
	queue_redraw()


func set_target(pos: Vector2) -> void:
	_target = clamp_to_field(pos)


static func clamp_to_field(pos: Vector2) -> Vector2:
	var r := CMConfig.FIELD_RECT.grow(-CMConfig.FIELD_MARGIN)
	return Vector2(
		clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y)
	)


const MAGNET_ART := preload("res://assets/void/magnet.svg")

func _draw() -> void:
	var t := game.visual_time
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	# Хвост: точки хранятся в parent-space — переводим в локальные координаты
	# магнита перед рисованием (F1: иначе координаты удваиваются).
	for i in _trail.size():
		var p := to_local(_trail[i])
		var fade := (1.0 - float(i) / float(_trail.size())) * 0.10
		draw_circle(p, 10.0 + i * 1.2, Color(0.45, 1.0, 0.94, fade))
	for i in range(5, 0, -1):
		draw_circle(Vector2.ZERO, 22.0 + i * 8.0, Color(0.15, 0.95, 0.85, 0.014 + _flash * 0.02))
	# Exact gameplay radius, broken into restrained instrument marks.
	# Метки медленно вращаются — радиус читается как «прибор», а не статика.
	var spin := t * 0.35
	for i in 24:
		var begin := float(i) / 24.0 * TAU + spin
		draw_arc(Vector2.ZERO, attraction_radius, begin, begin + TAU / 96.0, 4, Color(0.32, 0.93, 0.85, 0.20), 1.0, true)
	draw_arc(Vector2.ZERO, attraction_radius - 4.0, -0.4 + pulse * 0.1, 0.4 + pulse * 0.1, 24, Color(0.55, 1.0, 0.94, 0.5), 1.3, true)
	# Вспышка сбора: расширяющееся кольцо от корпуса.
	if _flash > 0.0:
		var ring_radius := attraction_radius * (1.0 - _flash) + 26.0
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(0.6, 1.0, 0.95, _flash * 0.55), 2.0 + _flash * 2.0, true)
	var art_scale := 1.0 + 0.10 * _flash
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(art_scale, art_scale))
	draw_texture_rect(MAGNET_ART, Rect2(-32, -32, 64, 64), false)
	if _flash > 0.0:
		draw_texture_rect(MAGNET_ART, Rect2(-32, -32, 64, 64), false, Color(0.7, 1.0, 0.96, _flash * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 4.0, Color(0.75, 1.0, 0.98, 0.15 + pulse * 0.12 + _flash * 0.3))
