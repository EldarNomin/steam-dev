class_name CMConfig
extends RefCounted
## Числа CM-001. Стартовые значения из GAME-SPEC (раздел «Исходные числа»).
## В CM-002 переезжают в единый машиночитаемый конфиг экономики.

# Поле: окно 1280x720, сверху HUD высотой 60, справа панель шириной 300.
const FIELD_RECT := Rect2(0.0, 60.0, 980.0, 660.0)
const FIELD_MARGIN := 24.0

const ATTRACTION_RADIUS := 100.0
const CAPTURE_RADIUS := 12.0
const MAGNET_STRENGTH := 1

const MAGNET_SPEED := 900.0
const ITEM_SPEED_MIN := 80.0
const ITEM_SPEED_MAX := 280.0

const MAX_ITEMS := 40
const RESPAWN_DELAY := 2.0
const SPAWN_INSET := 30.0

## Два типа обычных предметов CM-001. required_strength по CM-R02.
const ITEM_TYPES: Array[Dictionary] = [
	{"id": &"nut", "required_strength": 1, "radius": 7.0, "color": Color("a7b4c4")},
	{"id": &"plate", "required_strength": 1, "radius": 9.0, "color": Color("d99a2b")},
]
