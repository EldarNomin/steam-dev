extends Node2D
## Presentation only: textures, styles, bounded particles and live meters.
## Does not own rewards, simulation, upgrade costs or save data.

const CYAN := Color("62e7d4")
const GOLD := Color("efbd74")
var game: MainGame
var sparks: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var charge_bar: ProgressBar
var cargo_bar: ProgressBar
var goal_bar: ProgressBar
var _configured := false

func _ready() -> void:
	game = get_parent() as MainGame
	_rng.seed = 4072
	call_deferred("_configure")

func _box(background: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0, 0, 0, 0.22)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 3)
	return box

func _label(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _bar(parent: Node, pos: Vector2, size: Vector2, tint: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = size
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _box(Color("132735"), Color("213d4b"), 2)
	var fill := _box(tint, tint, 2)
	for box in [background, fill]:
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 0
		box.shadow_size = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	bar.size = size
	return bar

func _configure() -> void:
	if not is_instance_valid(game):
		return
	var ui := game.get_node("UI")
	var normal := _box(Color("142c3b"), Color("31576a"))
	var disabled := _box(Color("101e2a"), Color("273c48"))
	var hover := _box(Color("204758"), Color("70e5d0"))
	var pressed := _box(Color("0c2531"), CYAN)
	var focus := _box(Color(0, 0, 0, 0), GOLD)
	var panel := _box(Color("081723"), Color("264c5b"), 0)
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("d7e2e5"))
	for control in ui.find_children("*", "Control", true, false):
		control.theme = theme
		if control is Button:
			control.add_theme_stylebox_override("normal", normal)
			control.add_theme_stylebox_override("disabled", disabled)
			control.add_theme_stylebox_override("hover", hover)
			control.add_theme_stylebox_override("pressed", pressed)
			control.add_theme_stylebox_override("focus", focus)
			control.add_theme_color_override("font_color", Color("e3ecec"))
			control.add_theme_color_override("font_disabled_color", Color("77909e"))
			control.add_theme_color_override("font_hover_color", Color("ffffff"))
		elif control is Panel:
			control.add_theme_stylebox_override("panel", panel)
	var hud: Panel = ui.get_node("HUD")
	_label(hud, "COSMIC  MAGNET", Vector2(24, 10), Vector2(290, 30), 23, CYAN)
	var margin: MarginContainer = hud.get_node("MarginContainer")
	margin.add_theme_constant_override("margin_left", 330)
	var row: HBoxContainer = margin.get_node("HBoxContainer")
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 28)
	for label in [game.scrap_label, game.charge_label, game.cargo_label, game.stats_label]:
		label.add_theme_font_size_override("font_size", 16)
	charge_bar = _bar(hud, Vector2(600, 47), Vector2(130, 3), CYAN)
	cargo_bar = _bar(hud, Vector2(790, 47), Vector2(120, 3), GOLD)
	var side: Panel = ui.get_node("SidePanel")
	side.get_node("TitleLabel").text = "UPGRADE BAY"
	side.get_node("TitleLabel").add_theme_font_size_override("font_size", 21)
	var buttons: Array[Button] = [game.strength_button, game.radius_button, game.capacity_button]
	var icons: Array[Texture2D] = [preload("res://assets/art/magnet.webp"), preload("res://assets/art/radius.svg"), preload("res://assets/art/capacity.svg")]
	for i in buttons.size():
		var button := buttons[i]
		button.position = Vector2(16, 56 + i * 92)
		button.size = Vector2(268, 80)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = icons[i]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 42)
		button.add_theme_constant_override("h_separation", 14)
		button.add_theme_font_size_override("font_size", 16)
	game.status_label.position = Vector2(20, 348)
	game.status_label.size = Vector2(260, 72)
	game.status_label.add_theme_font_size_override("font_size", 14)
	_label(side, "THE FINAL SALVAGE", Vector2(20, 435), Vector2(260, 23), 12, GOLD)
	var goal := TextureRect.new()
	goal.texture = preload("res://assets/art/derelict.webp")
	goal.position = Vector2(20, 458)
	goal.size = Vector2(116, 50)
	goal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	goal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(goal)
	goal.position = Vector2(20, 458)
	goal.size = Vector2(116, 50)
	_label(side, "DERELICT\nStrength 12", Vector2(150, 464), Vector2(130, 44), 13, Color("9bb2bf"))
	goal_bar = _bar(side, Vector2(20, 519), Vector2(260, 4), GOLD)
	game.launch_button.add_theme_stylebox_override("normal", _box(GOLD, Color("ffe0a0")))
	game.launch_button.add_theme_stylebox_override("hover", _box(Color("ffd391"), Color("ffebc0")))
	game.launch_button.add_theme_stylebox_override("pressed", _box(Color("c99b5e"), GOLD))
	game.launch_button.add_theme_color_override("font_color", Color("1c2630"))
	game.launch_button.add_theme_color_override("font_hover_color", Color("14222c"))
	game.launch_button.text = "LAUNCH  →"
	game.main_menu.color = Color(0.015, 0.035, 0.06, 0.79)
	var menu_panel: Panel = game.main_menu.get_node("MenuPanel")
	menu_panel.add_theme_stylebox_override("panel", _box(Color("0b202d"), Color("467385"), 12))
	menu_panel.get_node("TitleLabel").add_theme_font_size_override("font_size", 29)
	menu_panel.get_node("SubtitleLabel").text = "Salvage the forgotten.\nBuild your magnet. Reach the derelict."
	# Existing confirmation panel was shorter than its cancel button.
	game.new_game_confirm.get_node("ConfirmPanel").size.y = 230
	game.tutorial_label.add_theme_font_size_override("font_size", 15)
	_configured = true
	game.notify_hud()

func _process(delta: float) -> void:
	if not _configured or not is_instance_valid(game):
		return
	charge_bar.value = 100.0 * game.charge / game.max_charge()
	cargo_bar.value = 100.0 * game.cargo_mass / game.capacity()
	goal_bar.value = 100.0 * game.magnet.strength / CMConfig.ship_strength()
	# Follow actual label layout rather than assuming a text width.
	charge_bar.position.x = game.charge_label.global_position.x
	charge_bar.size.x = game.charge_label.size.x
	cargo_bar.position.x = game.cargo_label.global_position.x
	cargo_bar.size.x = game.cargo_label.size.x
	if game.is_paused or game.menu_visible:
		return
	for spark in sparks:
		spark["life"] -= delta
		spark["pos"] += spark["vel"] * delta
		spark["vel"] *= maxf(0.0, 1.0 - delta * 4.0)
	for popup in popups:
		popup["life"] -= delta
		popup["pos"].y -= delta * 22
	sparks = sparks.filter(func(s: Dictionary) -> bool: return s["life"] > 0)
	popups = popups.filter(func(s: Dictionary) -> bool: return s["life"] > 0)
	queue_redraw()

func collected(pos: Vector2, value: int, unique: bool) -> void:
	var tint := GOLD if unique else CYAN
	for i in 7:
		if sparks.size() >= 120:
			break
		var angle := _rng.randf_range(0, TAU)
		sparks.append({"pos": pos, "vel": Vector2.from_angle(angle) * _rng.randf_range(35, 110), "life": 0.55, "color": tint})
	if popups.size() < 24:
		popups.append({"pos": pos, "value": value, "life": 0.8, "color": tint})
	queue_redraw()

func _draw() -> void:
	for spark in sparks:
		var tint: Color = spark["color"]
		tint.a = clampf(spark["life"] / 0.55, 0, 1)
		draw_circle(spark["pos"], 1.7, tint)
	for popup in popups:
		var tint: Color = popup["color"]
		tint.a = clampf(popup["life"] / 0.5, 0, 1)
		draw_string(ThemeDB.fallback_font, popup["pos"] + Vector2(-8, -20), "+%d" % popup["value"], HORIZONTAL_ALIGNMENT_LEFT, 55, 17, tint)
