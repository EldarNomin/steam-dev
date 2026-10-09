class_name MainGame
extends Node2D
## Корневая сцена: меню → DOCK ↔ SALVAGE (CM-R04–R07) с сохранением (CM-R10–12).
## В DOCK магнит стоит и открыт магазин; в SALVAGE тратится заряд и идёт сбор.
## Возврат — единая точка request_return (авто по заряду/трюму и ручная
## кнопка), разгрузка — единая идемпотентная unload. Сохранение — по CM-R10:
## покупка, разгрузка, уникальная находка, штатный выход; загрузка возвращает
## в безопасный DOCK; закрытие посреди вылета не начисляет груз (CM-R11).
## Границы CM-003: без финала корабля, полного арта, локализации, Steam.

enum GameState { DOCK, SALVAGE }

const FIELD_BG := Color("101a3c")
const STAR_COLOR := Color(1.0, 1.0, 1.0, 0.16)
const DEFAULT_VOLUME := 0.8

var state: GameState = GameState.DOCK
var economy := Economy.new()
var is_paused := false

var charge := 0.0
var cargo_mass := 0
var cargo_value := 0
var collected_count := 0

## Прогресс забега, попадающий в сохранение (CM-R10).
var unique_collected := false
var tutorial_stage := 0
var master_volume := DEFAULT_VOLUME

var menu_visible := true
var _stars: PackedVector2Array = []

@onready var magnet: Magnet = $Magnet
@onready var spawner: Spawner = $ItemField
@onready var ship: ShipWreck = $ShipWreck
@onready var scrap_label: Label = $UI/HUD/MarginContainer/HBoxContainer/ScrapLabel
@onready var charge_label: Label = $UI/HUD/MarginContainer/HBoxContainer/ChargeLabel
@onready var cargo_label: Label = $UI/HUD/MarginContainer/HBoxContainer/CargoLabel
@onready var stats_label: Label = $UI/HUD/MarginContainer/HBoxContainer/StatsLabel
@onready var pause_overlay: Control = $UI/PauseOverlay
@onready var resume_button: Button = $UI/PauseOverlay/CenterContainer/PauseBox/ResumeButton
@onready var menu_button: Button = $UI/PauseOverlay/CenterContainer/PauseBox/MenuButton
@onready var strength_button: Button = $UI/SidePanel/StrengthButton
@onready var radius_button: Button = $UI/SidePanel/RadiusButton
@onready var capacity_button: Button = $UI/SidePanel/CapacityButton
@onready var launch_button: Button = $UI/SidePanel/LaunchButton
@onready var return_button: Button = $UI/SidePanel/ReturnButton
@onready var status_label: Label = $UI/SidePanel/StatusLabel
@onready var tutorial_label: Label = $UI/TutorialLabel
@onready var main_menu: Control = $UI/MainMenu
@onready var continue_button: Button = $UI/MainMenu/MenuPanel/ContinueButton
@onready var new_game_button: Button = $UI/MainMenu/MenuPanel/NewGameButton
@onready var quit_button: Button = $UI/MainMenu/MenuPanel/QuitButton
@onready var volume_slider: HSlider = $UI/MainMenu/MenuPanel/VolumeSlider
@onready var new_game_confirm: Control = $UI/NewGameConfirm
@onready var confirm_yes: Button = $UI/NewGameConfirm/ConfirmPanel/ConfirmYes
@onready var confirm_no: Button = $UI/NewGameConfirm/ConfirmPanel/ConfirmNo


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
	resume_button.pressed.connect(toggle_pause)
	menu_button.pressed.connect(_save_and_open_menu)
	continue_button.pressed.connect(continue_game)
	new_game_button.pressed.connect(_on_new_game_pressed)
	quit_button.pressed.connect(handle_close_request)
	confirm_yes.pressed.connect(confirm_new_game)
	confirm_no.pressed.connect(_hide_new_game_confirm)
	volume_slider.value_changed.connect(_on_volume_changed)
	# Штатное закрытие окна проходит через handle_close_request (CM-R11).
	get_tree().auto_accept_quit = false
	_show_menu()
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
	if ship != null:
		ship.queue_redraw()


## Вылет из дока. Заряд восстанавливается только разгрузкой (CM-R05).
func launch() -> void:
	if state != GameState.DOCK:
		return
	state = GameState.SALVAGE
	magnet.visible = true
	magnet.position = CMConfig.FIELD_RECT.get_center()
	if tutorial_stage < 1:
		tutorial_stage = 1
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
	if cargo_value > 0 and tutorial_stage < 3:
		tutorial_stage = 3
	cargo_value = 0
	cargo_mass = 0
	charge = max_charge()
	save_now()
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
	if tutorial_stage < 2:
		tutorial_stage = 2
	if item.is_unique:
		# Уникальная находка (CM-R08): в очередь возрождения не попадает,
		# факт находки сохраняется немедленно (CM-R10 «важная находка»).
		unique_collected = true
		save_now()
	else:
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
		if tutorial_stage < 4:
			tutorial_stage = 4
		save_now()  # CM-R10: сохранение при покупке
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
	_update_tutorial()


func _update_shop() -> void:
	if strength_button == null:
		return
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


## Обучение (простое, CM-003): короткие подсказки по ходу первого забега;
## шаг 3 явно называет открывшуюся силу 2: батареи и реликвия (замечание
## ревью CM-002). Скрывается после первого вылета с новой силой.
func _update_tutorial() -> void:
	if tutorial_label == null:
		return
	if menu_visible or tutorial_stage >= 5:
		tutorial_label.visible = false
		return
	tutorial_label.visible = true
	match tutorial_stage:
		0:
			tutorial_label.text = "Press LAUNCH to start a salvage run."
		1:
			tutorial_label.text = "Move the magnet with the mouse — collect scrap."
		2:
			tutorial_label.text = "Full cargo or empty charge returns you to dock and unloads."
		3:
			tutorial_label.text = "Buy MAGNET STRENGTH — level 2 unlocks batteries and the glowing relic."
		4:
			tutorial_label.text = "LAUNCH! Batteries and the relic are within reach now."
		_:
			tutorial_label.visible = false


# --- Меню и сохранение (CM-R10–R12) ---

func _show_menu() -> void:
	menu_visible = true
	main_menu.visible = true
	new_game_confirm.visible = false
	pause_overlay.visible = false
	is_paused = false
	get_tree().paused = false
	continue_button.disabled = not SaveService.has_save()
	volume_slider.set_value_no_signal(master_volume * 100.0)
	notify_hud()


func continue_game() -> void:
	var data := SaveService.load_data()
	if data.is_empty():
		# Битый/отсутствующий сейв — безопасный старт нового забега (CM-R12).
		new_game()
		return
	economy.scrap = int(data.get("scrap", 0))
	economy.restore_levels(data.get("levels", {}))
	unique_collected = bool(data.get("unique_collected", false))
	tutorial_stage = int(data.get("tutorial_stage", 0))
	var settings: Dictionary = data.get("settings", {})
	_set_volume(float(settings.get("master_volume", DEFAULT_VOLUME)), false)
	_start_run()


func _on_new_game_pressed() -> void:
	# Новая игра поверх существующего забега требует подтверждения (CM-R11).
	if SaveService.has_save():
		new_game_confirm.visible = true
	else:
		confirm_new_game()


func _hide_new_game_confirm() -> void:
	new_game_confirm.visible = false


func confirm_new_game() -> void:
	new_game_confirm.visible = false
	new_game()


func new_game() -> void:
	economy = Economy.new()
	unique_collected = false
	tutorial_stage = 0
	collected_count = 0
	charge = max_charge()
	cargo_mass = 0
	cargo_value = 0
	state = GameState.DOCK
	magnet.visible = false
	_apply_stats()
	save_now()  # файл сразу консистентен с новым забегом
	_start_run()


func _start_run() -> void:
	menu_visible = false
	main_menu.visible = false
	new_game_confirm.visible = false
	state = GameState.DOCK
	cargo_mass = 0
	cargo_value = 0
	charge = max_charge()
	magnet.visible = false
	_apply_stats()
	# Поле пересобирается под параметры забега: реликвия есть только если
	# она ещё не собрана (CM-R08).
	spawner.reset_field()
	notify_hud()


func _save_and_open_menu() -> void:
	save_on_exit()
	_show_menu()


## Сохранение при штатном выходе из забега (CM-R10) с правилом CM-R11:
## незавершённый груз не начисляется и не сохраняется; выгруженный лом
## и покупки не теряются; следующая загрузка начинается в DOCK.
func save_on_exit() -> void:
	if is_paused:
		toggle_pause()
	state = GameState.DOCK
	cargo_mass = 0
	cargo_value = 0
	magnet.visible = false
	charge = max_charge()
	save_now()


func handle_close_request() -> void:
	save_on_exit()
	get_tree().quit()


## Собирает текущее состояние в словарь сохранения (CM-R10).
func save_now() -> void:
	var levels := {}
	for def in CMConfig.upgrades():
		levels[String(def["id"])] = economy.level(StringName(def["id"]))
	SaveService.save_data({
		"scrap": economy.scrap,
		"levels": levels,
		"unique_collected": unique_collected,
		"tutorial_stage": tutorial_stage,
		"settings": {"master_volume": master_volume},
	})


func _on_volume_changed(v: float) -> void:
	_set_volume(v / 100.0, true)


func _set_volume(v: float, persist: bool) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))
	if persist:
		save_now()
	if volume_slider != null and persist == false:
		volume_slider.set_value_no_signal(master_volume * 100.0)


func toggle_pause() -> void:
	if menu_visible:
		return
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_overlay.visible = is_paused


## Потеря фокуса останавливает симуляцию (CM-R01): авто-пауза, снятие — вручную.
func handle_focus_lost() -> void:
	if not is_paused and not menu_visible:
		toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		handle_focus_lost()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		handle_close_request()
