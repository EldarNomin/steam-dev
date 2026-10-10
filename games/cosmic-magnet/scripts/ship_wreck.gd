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


const SHIP_ART := preload("res://assets/art/derelict.webp")

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# Separate transparent sprite, not a background containing fake UI.
	# Медленное покачивание — корабль дрейфует, а не прибит к фону.
	draw_set_transform(Vector2(0.0, sin(t * 0.5) * 3.0), 0.0, Vector2.ONE)
	draw_texture_rect(SHIP_ART, Rect2(-205, -82, 410, 164), false, Color.WHITE)
	# Мигающие навигационные огни по корпусу и маячок на надстройке.
	for i in 5:
		var phase := float(i) * 1.7
		var on := sin(t * 1.1 + phase) > 0.1
		draw_circle(Vector2(-150 + i * 62.0, -4.0 + (2.0 if i % 2 == 0 else 0.0)),
			2.2, Color(1.0, 0.72, 0.3, 0.55 if on else 0.12))
	if sin(t * 2.4) > 0.0:
		draw_circle(Vector2(-2.0, -66.0), 2.6, Color(1.0, 0.35, 0.3, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.055, 0.085, 0.9)
	panel.border_color = Color(0.6, 0.4, 0.22, 0.75)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	draw_style_box(panel, Rect2(-160, 88, 320, 48))
	draw_string(ThemeDB.fallback_font, Vector2(-145, 108), "DERELICT  /  STRENGTH %d" % CMConfig.ship_strength(), HORIZONTAL_ALIGNMENT_LEFT, 290, 13, Color("efc081"))
	draw_string(ThemeDB.fallback_font, Vector2(-145, 126), "Final target · locked in this fragment", HORIZONTAL_ALIGNMENT_LEFT, 290, 11, Color("92a7b6"))
