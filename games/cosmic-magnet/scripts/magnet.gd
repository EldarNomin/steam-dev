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


func _ready() -> void:
	game = get_parent() as MainGame
	strength = CMConfig.i("magnet.base_strength")
	attraction_radius = CMConfig.f("magnet.attraction_radius")
	_target = position


func _physics_process(delta: float) -> void:
	if game == null or game.state != MainGame.GameState.SALVAGE:
		return
	_target = clamp_to_field(get_global_mouse_position())
	position = position.move_toward(_target, CMConfig.f("magnet.follow_speed") * delta)
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


const MAGNET_ART := preload("res://assets/art/magnet.webp")

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 500.0)
	for i in range(5, 0, -1):
		draw_circle(Vector2.ZERO, 22.0 + i * 8.0, Color(0.15, 0.95, 0.85, 0.014))
	# Exact gameplay radius, broken into restrained instrument marks.
	for i in 48:
		var begin := float(i) / 48.0 * TAU
		draw_arc(Vector2.ZERO, attraction_radius, begin, begin + TAU / 96.0, 4, Color(0.32, 0.93, 0.85, 0.38), 1.0, true)
	draw_arc(Vector2.ZERO, attraction_radius - 4.0, -0.4 + pulse * 0.1, 0.4 + pulse * 0.1, 24, Color(0.55, 1.0, 0.94, 0.5), 1.3, true)
	draw_texture_rect(MAGNET_ART, Rect2(-32, -32, 64, 64), false)
	draw_circle(Vector2.ZERO, 4.0, Color(0.75, 1.0, 0.98, 0.15 + pulse * 0.12))
