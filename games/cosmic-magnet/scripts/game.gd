class_name MainGame
extends Node2D
## Корневая сцена: DOCK ↔ SALVAGE (CM-R04–R07). В DOCK магнит стоит и открыт
## магазин; в SALVAGE тратится заряд и идёт сбор. Возврат — единая точка
## request_return (авто по заряду/трюму и ручная кнопка), разгрузка — единая
## идемпотентная unload: повторные сигналы не начисляют лом повторно.
## Границы CM-002: нет сохранений, уникальных находок, финала, Steam.

enum GameState { DOCK, SALVAGE }

const FIELD_BG := Color("101a3c")
const STAR_COLOR := Color(1.0, 1.0, 1.0, 0.16)

var state: GameState = GameState.DOCK
var economy := Economy.new()
var is_paused := false

var charge := 0.0
var cargo_mass := 0
var cargo_value := 0
var collected_count := 0

var _stars: PackedVector2Array = []

@onready var magnet: Magnet = $Magnet
@onready var spawner: Spawner = $ItemField
@onready var scrap_label: Label = $UI/HUD/MarginContainer/HBoxContainer/ScrapLabel
@onready var charge_label: Label = $UI/HUD/MarginContainer/HBoxContainer/ChargeLabel
@onready var cargo_label: Label = $UI/HUD/MarginContainer/HBoxContainer/CargoLabel
@onready var stats_label: Label = $UI/HUD/MarginContainer/HBoxContainer/StatsLabel
@onready var pause_overlay: Control = $UI/PauseOverlay
@onready var strength_button: Button = $UI/SidePanel/StrengthButton
@onready var radius_button: Button = $UI/SidePanel/RadiusButton
@onready var capacity_button: Button = $UI/SidePanel/CapacityButton
@onready var launch_button: Button = $UI/SidePanel/LaunchButton
@onready var return_button: Button = $UI/SidePanel/ReturnButton
@onready var status_label: Label = $UI/SidePanel/StatusLabel


func _ready() -> void:
	randomize()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	for i in 90:
		var r := CMConfig.FIELD_RECT.grow(-6.0)
		_stars.append(
			Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		)
	charge = max_charge()
	_apply_stats()
	magnet.visible = false
	strength_button.pressed.connect(_on_buy.bind(&"strength"))
	radius_button.pressed.connect(_on_buy.bind(&"radius"))
	capacity_button.pressed.connect(_on_buy.bind(&"capacity"))
	launch_button.pressed.connect(launch)
	return_button.pressed.connect(request_return)
	queue_redraw()
	notify_hud()


func _draw() -> void:
	draw_rect(CMConfig.FIELD_RECT, FIELD_BG)
	for s in _stars:
		draw_rect(Rect2(s, Vector2(2.0, 2.0)), STAR_COLOR)


func _physics_process(delta: float) -> void:
	advance_flight(delta)


## Тратит заряд в SALVAGE; пустой заряд — авто-возврат (CM-R04). Выделено
## отдельной функцией для прямых тестов.
func advance_flight(delta: float) -> void:
	if state != GameState.SALVAGE:
		return
	charge = maxf(charge - delta, 0.0)
	if charge <= 0.0:
		request_return()
	notify_hud()


## Текущие характеристики: база из конфига + сумма эффектов купленных уровней.
func max_charge() -> float:
	return CMConfig.f("flight.charge_seconds")


func capacity() -> int:
	return CMConfig.i("flight.cargo_capacity") + economy.effect_sum("cargo_capacity")


func _apply_stats() -> void:
	magnet.strength = CMConfig.i("magnet.base_strength") + economy.effect_sum("strength")
	magnet.attraction_radius = CMConfig.f("magnet.attraction_radius") + economy.effect_sum("attraction_radius")


## Вылет из дока. Заряд восстанавливается только разгрузкой (CM-R05).
func launch() -> void:
	if state != GameState.DOCK:
		return
	state = GameState.SALVAGE
	magnet.visible = true
	magnet.position = CMConfig.FIELD_RECT.get_center()
	notify_hud()


## Единственная точка возврата в док: и авто-причины (заряд, полный трюм),
## и ручная кнопка. Повторный вызов в DOCK ничего не делает.
func request_return() -> void:
	if state != GameState.SALVAGE:
		return
	state = GameState.DOCK
	magnet.visible = false
	unload()


## Единственная разгрузка (CM-R05): один раз начисляет стоимость груза,
## очищает трюм и восстанавливает заряд. Идемпотентна — повторные сигналы
## (в т.ч. одновременные причины возврата) не начисляют деньги повторно.
func unload() -> void:
	economy.scrap += cargo_value
	cargo_value = 0
	cargo_mass = 0
	charge = max_charge()
	notify_hud()


## Влезает ли предмет в трюм прямо сейчас.
func can_take(mass: int) -> bool:
	return state == GameState.SALVAGE and cargo_mass + mass <= capacity()


## Единственная точка начисления сбора (CM-R03: ровно один раз).
## Флаг collected ставится здесь синхронно: и прямой повторный вызов,
## и повторный сигнал предмета дают одно начисление и одну запись очереди.
## Предмет, не влезающий в трюм, не собирается и остаётся на поле (SPEC).
func register_collection(item: SalvageItem) -> void:
	if item.collected or item.is_queued_for_deletion():
		return
	if state != GameState.SALVAGE:
		return
	if cargo_mass + item.mass > capacity():
		return
	item.collected = true
	cargo_mass += item.mass
	cargo_value += item.price
	collected_count += 1
	spawner.notify_collected()
	item.queue_free()
	var full := cargo_mass >= capacity()
	notify_hud()
	if full:
		request_return()  # полный трюм — авто-возврат и разгрузка без потери добычи (CM-R04)


func _on_buy(id: StringName) -> void:
	if state != GameState.DOCK:
		return
	if economy.buy(id):
		_apply_stats()
	notify_hud()


func notify_field_changed() -> void:
	notify_hud()


func notify_hud() -> void:
	if scrap_label == null:
		return
	scrap_label.text = "Scrap: %d" % economy.scrap
	charge_label.text = "Charge: %ds" % int(ceil(charge))
	cargo_label.text = "Cargo: %d/%d" % [cargo_mass, capacity()]
	stats_label.text = "Str: %d  Rad: %d  Cap: %d" % [
		magnet.strength, int(magnet.attraction_radius), capacity()
	]
	_update_shop()


func _update_shop() -> void:
	var in_dock := state == GameState.DOCK
	status_label.text = (
		"In dock: buy upgrades, then launch.\nCharge refills on unload."
		if in_dock
		else "Salvage run: collect scrap.\nReturn early or wait for auto-dock."
	)
	for btn: Button in [strength_button, radius_button, capacity_button]:
		var id: StringName = _button_upgrade(btn)
		var lvl := economy.level(id)
		var at_max := lvl >= economy.max_level(id)
		var cost := economy.upgrade_cost(id)
		btn.text = "%s L%d — %d scrap" % [_title(id), lvl, cost] if not at_max else "%s L%d — MAX" % [_title(id), lvl]
		btn.disabled = not in_dock or at_max or economy.scrap < cost
	launch_button.visible = in_dock
	return_button.visible = not in_dock


func _button_upgrade(btn: Button) -> StringName:
	if btn == strength_button:
		return &"strength"
	if btn == radius_button:
		return &"radius"
	return &"capacity"


func _title(id: StringName) -> String:
	for def in CMConfig.upgrades():
		if StringName(def["id"]) == id:
			return String(def["title"])
	return String(id)


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
