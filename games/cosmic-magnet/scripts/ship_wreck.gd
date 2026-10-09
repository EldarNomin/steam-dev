class_name ShipWreck
extends Node2D
## Силуэт финального корабля (CM-R09, в CM-003 только визуальная цель):
## виден с первого кадра, честно сообщает требуемую силу и границу
## прототипа — сбор корабля недоступен в этом фрагменте.

var game: MainGame

const HULL := Color("16203a")
const HULL_EDGE := Color("2c3a5e")
const WINDOW := Color("e8a33d")

var _points: PackedVector2Array = []


func _ready() -> void:
	game = get_parent() as MainGame
	_points = PackedVector2Array([
		Vector2(-110, 10), Vector2(-70, -18), Vector2(-10, -30), Vector2(60, -26),
		Vector2(105, -6), Vector2(120, 14), Vector2(60, 26), Vector2(-30, 30),
		Vector2(-80, 26),
	])


func _draw() -> void:
	# Корпус-обломок.
	draw_colored_polygon(_points, HULL)
	for i in _points.size():
		draw_line(_points[i], _points[(i + 1) % _points.size()], HULL_EDGE, 2.0)
	# Надстройка и антенны.
	draw_rect(Rect2(-30, -52, 44, 24), HULL)
	draw_rect(Rect2(-30, -52, 44, 24), HULL_EDGE, false, 2.0)
	draw_line(Vector2(-12, -52), Vector2(-12, -74), HULL_EDGE, 2.0)
	draw_line(Vector2(6, -52), Vector2(6, -68), HULL_EDGE, 2.0)
	# Трещина корпуса — корабль заброшен.
	draw_line(Vector2(-20, -30), Vector2(-2, 4), Color(0, 0, 0, 0.5), 3.0)
	draw_line(Vector2(-2, 4), Vector2(12, 28), Color(0, 0, 0, 0.5), 3.0)
	# Янтарные окна (часть погасла).
	for x in [-58, -38, -18, 2, 22, 42]:
		var lit: bool = fmod(absf(x * 7.3), 10.0) > 3.5
		var c := WINDOW if lit else Color(WINDOW, 0.15)
		draw_rect(Rect2(x - 3, -12, 6, 5), c)
	# Плашка с требованием (CM-R09: сообщение о нужной силе).
	var reachable := game != null and game.magnet.strength >= CMConfig.ship_strength()
	var line1 := "FINAL SHIP — requires strength %d" % CMConfig.ship_strength()
	var line2 := (
		"Approach to dock" if reachable else "Locked: not reachable in this prototype fragment"
	)
	var text_color := Color("37c8c3") if reachable else Color(0.62, 0.7, 0.82, 0.85)
	draw_string(ThemeDB.fallback_font, Vector2(-104, 52), line1, HORIZONTAL_ALIGNMENT_LEFT, 220.0, 13, text_color)
	draw_string(ThemeDB.fallback_font, Vector2(-104, 70), line2, HORIZONTAL_ALIGNMENT_LEFT, 220.0, 11, Color(0.62, 0.7, 0.82, 0.7))
