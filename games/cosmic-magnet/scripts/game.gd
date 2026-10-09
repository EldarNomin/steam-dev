class_name MainGame
extends Node2D
## Корневая сцена CM-001: поле, магнит, предметы, HUD и пауза.
## Границы этапа: нет заряда, магазина, сохранений, полного арта, финала, Steam.
## Сбор проходит через единственный обработчик register_collection (CM-R03).

const FIELD_BG := Color("101a3c")
const STAR_COLOR := Color(1.0, 1.0, 1.0, 0.16)

var collected_count := 0
var is_paused := false

var _stars: PackedVector2Array = []

@onready var magnet: Magnet = $Magnet
@onready var spawner: Spawner = $ItemField
@onready var collected_label: Label = $UI/HUD/MarginContainer/HBoxContainer/CollectedLabel
@onready var field_label: Label = $UI/HUD/MarginContainer/HBoxContainer/FieldLabel
@onready var strength_label: Label = $UI/HUD/MarginContainer/HBoxContainer/StrengthLabel
@onready var pause_overlay: Control = $UI/PauseOverlay


func _ready() -> void:
	randomize()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	for i in 90:
		var r := CMConfig.FIELD_RECT.grow(-6.0)
		_stars.append(
			Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		)
	notify_field_changed()
	queue_redraw()


func _draw() -> void:
	draw_rect(CMConfig.FIELD_RECT, FIELD_BG)
	for s in _stars:
		draw_rect(Rect2(s, Vector2(2.0, 2.0)), STAR_COLOR)


## Единственная точка начисления сбора (CM-R03: ровно один раз).
## Флаг collected ставится здесь синхронно: и прямой повторный вызов,
## и повторный сигнал предмета дают одно начисление и одну запись очереди.
func register_collection(item: SalvageItem) -> void:
	if item.collected or item.is_queued_for_deletion():
		return
	item.collected = true
	collected_count += 1
	spawner.notify_collected()
	item.queue_free()
	notify_field_changed()


func notify_field_changed() -> void:
	if collected_label == null:
		return
	collected_label.text = "Collected: %d" % collected_count
	field_label.text = "On field: %d / %d" % [spawner.field_count(), CMConfig.MAX_ITEMS]
	strength_label.text = "Strength: %d" % magnet.strength


func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_overlay.visible = is_paused


## Потеря фокуса останавливает симуляцию (CM-R01): авто-пауза, снятие — вручную.
func handle_focus_lost() -> void:
	if not is_paused:
		toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		handle_focus_lost()
