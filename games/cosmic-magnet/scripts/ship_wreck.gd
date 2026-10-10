class_name ShipWreck
extends Node2D
## Силуэт финального корабля (CM-R09, в CM-003 только визуальная цель):
## виден с первого кадра, честно сообщает требуемую силу и границу
## прототипа — сбор корабля недоступен в этом фрагменте.

var game: MainGame

## Дрейф и мигание огней — анимация в _draw требует собственной
## перерисовки: перерисовка родителя команды детей не обновляет (F2).
func _process(_delta: float) -> void:
	queue_redraw()


func _ready() -> void:
	game = get_parent() as MainGame


func _draw() -> void:
	var t := game.visual_time
	# Dormant large hull; no running engines on an abandoned ship.
	draw_set_transform(Vector2(0,sin(t*0.5)*3),-PI/2)
	draw_texture_rect(VoidArt.DERELICT,Rect2(-160,-160,320,320),false,Color("8795ab"))
	draw_set_transform(Vector2.ZERO)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.055, 0.085, 0.9)
	panel.border_color = Color(0.6, 0.4, 0.22, 0.75)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	draw_style_box(panel, Rect2(-160, 88, 320, 48))
	draw_string(ThemeDB.fallback_font, Vector2(-145, 108), "DERELICT  /  STRENGTH %d" % CMConfig.ship_strength(), HORIZONTAL_ALIGNMENT_LEFT, 290, 13, Color("efc081"))
	draw_string(ThemeDB.fallback_font, Vector2(-145, 126), "Final target · locked in this fragment", HORIZONTAL_ALIGNMENT_LEFT, 290, 11, Color("92a7b6"))
