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


func _draw() -> void:
	# Радиус притяжения — бирюзовое кольцо (палитра концепта).
	draw_arc(Vector2.ZERO, attraction_radius, 0.0, TAU, 96, Color(0.22, 0.78, 0.76, 0.28), 1.5)
	# Радиус захвата.
	draw_circle(Vector2.ZERO, CMConfig.f("magnet.capture_radius"), Color(0.43, 0.95, 0.93, 0.35))
	# Корпус магнита — простая заглушка.
	draw_circle(Vector2.ZERO, 14.0, Color("c7d3e0"))
	draw_circle(Vector2.ZERO, 14.0, Color("5d6b7d"), false, 2.0)
	draw_circle(Vector2.ZERO, 5.0, Color("2b3b4d"))
	# Янтарные полюса.
	draw_rect(Rect2(-11.0, -16.0, 7.0, 8.0), Color("e8a33d"))
	draw_rect(Rect2(4.0, -16.0, 7.0, 8.0), Color("e8a33d"))
