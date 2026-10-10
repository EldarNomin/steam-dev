extends Node2D
## Presentation only: textures, styles, bounded particles and live meters.
## Does not own rewards, simulation, upgrade costs or save data.

const CYAN := Color("62e7d4")
const GOLD := Color("efbd74")
var game: MainGame
var sparks: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var charge_bar: ProgressBar
var cargo_bar: ProgressBar
var goal_bar: ProgressBar
var _configured := false
var pulse_hint: Label
var objective_hint: Label
var completion: ColorRect
var completion_seen := false
var end_panel: Panel
var rescue_remaining := 0.0
var rescue_origin := Vector2.ZERO
const RESCUE_DURATION := 1.1

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
	var icons: Array[Texture2D] = [preload("res://assets/void/magnet.svg"), preload("res://assets/art/radius.svg"), preload("res://assets/art/capacity.svg")]
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
	game.pulse_button = Button.new()
	game.pulse_button.name = "PulseButton"
	side.add_child(game.pulse_button)
	game.pulse_button.position = Vector2(16, 328)
	game.pulse_button.size = Vector2(268, 62)
	game.pulse_button.add_theme_stylebox_override("normal", normal)
	game.pulse_button.add_theme_stylebox_override("hover", hover)
	game.pulse_button.add_theme_stylebox_override("disabled", disabled)
	game.pulse_button.add_theme_font_size_override("font_size", 15)
	game.pulse_button.pressed.connect(game._on_buy.bind(&"pulse"))
	pulse_hint = _label(ui, "", Vector2(24, 82), Vector2(500, 24), 14, CYAN)
	objective_hint = _label(ui, "", Vector2(24, 108), Vector2(850, 24), 13, GOLD)
	completion = ColorRect.new()
	completion.color = Color(0.02, 0.04, 0.07, 0.85)
	completion.size = Vector2(1280, 720)
	completion.visible = false
	ui.add_child(completion)
	end_panel = Panel.new()
	end_panel.position = Vector2(340, 210)
	end_panel.size = Vector2(600, 300)
	end_panel.add_theme_stylebox_override("panel", _box(Color("0b202d"), GOLD, 12))
	completion.add_child(end_panel)
	_label(end_panel, "SKIFF RECOVERED", Vector2(32, 30), Vector2(535, 40), 30, GOLD)
	_label(end_panel, "You uncovered a signal, broke the moorings\nand towed a lost ship to safety.\n\n+100 scrap  /  Your progress is saved.", Vector2(32, 90), Vector2(535, 110), 18, Color("d7e2e5"))
	var back := Button.new()
	back.text = "BACK TO DOCK"
	back.position = Vector2(32, 224)
	back.size = Vector2(536, 46)
	back.add_theme_stylebox_override("normal", normal)
	back.add_theme_stylebox_override("hover", hover)
	back.pressed.connect(func() -> void: completion.hide())
	end_panel.add_child(back)
	game.status_label.position = Vector2(20, 396)
	game.status_label.size = Vector2(260, 38)
	game.status_label.add_theme_font_size_override("font_size", 12)
	_label(side, "THE FINAL SALVAGE", Vector2(20, 435), Vector2(260, 23), 12, GOLD)
	var goal := TextureRect.new()
	goal.texture = VoidArt.DERELICT
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
	menu_panel.get_node("SubtitleLabel").text = "Uncover a signal. Build a chain magnet.\nBring a lost ship home."
	# Existing confirmation panel was shorter than its cancel button.
	game.new_game_confirm.get_node("ConfirmPanel").size.y = 230
	game.tutorial_label.add_theme_font_size_override("font_size", 15)
	# Pause controls must remain above the full-screen completion interceptor.
	ui.move_child(game.pause_overlay,ui.get_child_count()-1)
	_configured = true
	game.notify_hud()

func _process(delta: float) -> void:
	if not _configured or not is_instance_valid(game):
		return
	objective_hint.visible = not game.menu_visible
	objective_hint.text = game.site.objective()
	advance_rescue(delta)
	if not game.site.skiff_recovered:
		completion_seen = false
		completion.hide()
	elif not game.menu_visible and not completion_seen:
		completion_seen = true
		completion.show()
	if game.menu_visible:
		completion.hide()
	# The overlay still intercepts clicks as before; only its reveal is animated.
	var reveal := 1.0 - rescue_remaining / RESCUE_DURATION
	completion.color.a = 0.85 * reveal
	end_panel.visible = rescue_remaining <= 0.4
	end_panel.modulate.a = clampf(1.0 - rescue_remaining / 0.4, 0.0, 1.0)
	pulse_hint.visible = not game.menu_visible
	if game.pulse != null:
		if not game.pulse.unlocked():
			pulse_hint.text = "FIRST DISCOVERY  /  Install a magnetic pulse in the dock"
		elif game.pulse.holding:
			pulse_hint.text = "CHARGING PULSE  /  release LMB to pull the group"
		elif game.pulse.cooldown > 0.0:
			pulse_hint.text = "PULSE RECHARGING  /  %.1fs" % game.pulse.cooldown
		else:
			pulse_hint.text = "PULSE READY  /  Hold LMB → release"
	# Бары догоняют значения плавно, а не прыгают.
	var lerp_speed := minf(1.0, delta * 9.0)
	charge_bar.value = lerpf(charge_bar.value, 100.0 * game.charge / game.max_charge(), lerp_speed)
	cargo_bar.value = lerpf(cargo_bar.value, 100.0 * game.cargo_mass / game.capacity(), lerp_speed)
	goal_bar.value = lerpf(goal_bar.value, 100.0 * game.magnet.strength / CMConfig.ship_strength(), lerp_speed)
	# Низкий заряд в вылете — шкала и цифры пульсируют тёплым.
	var low_charge := game.state == MainGame.GameState.SALVAGE and game.charge < 10.0 and not game.is_paused and not game.menu_visible
	if low_charge:
		var wave := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 150.0)
		game.charge_label.modulate = Color(1.0, wave, wave * 0.8)
		charge_bar.modulate = Color(1.0, wave, wave * 0.8)
	else:
		game.charge_label.modulate = Color.WHITE
		charge_bar.modulate = Color.WHITE
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
	for ring in rings:
		ring["life"] -= delta
	sparks = sparks.filter(func(s: Dictionary) -> bool: return s["life"] > 0)
	popups = popups.filter(func(s: Dictionary) -> bool: return s["life"] > 0)
	rings = rings.filter(func(s: Dictionary) -> bool: return s["life"] > 0)
	queue_redraw()

func collected(pos: Vector2, value: int, unique: bool, text := "") -> void:
	var tint := GOLD if unique else CYAN
	if game.magnet != null:
		game.magnet.flash()
	if rings.size() < 16:
		rings.append({"pos": pos, "life": 0.38})
	for i in 7:
		if sparks.size() >= 120:
			break
		var angle := _rng.randf_range(0, TAU)
		sparks.append({"pos": pos, "vel": Vector2.from_angle(angle) * _rng.randf_range(35, 110), "life": 0.55, "color": tint})
	if popups.size() < 24:
		popups.append({"pos": pos, "value": value, "text":text if text != "" else "+%d" % value, "life": 0.8, "color": tint})
	queue_redraw()

func rescued(pos: Vector2) -> void:
	# Called only after the real collection/reward/save, never when loading a save.
	rescue_origin = pos
	rescue_remaining = RESCUE_DURATION
	queue_redraw()

func advance_rescue(delta: float) -> void:
	if game.is_paused or game.menu_visible:
		return
	rescue_remaining = maxf(0.0, rescue_remaining - delta)

func reset_feedback() -> void:
	rescue_remaining = 0.0
	completion_seen = false
	sparks.clear()
	popups.clear()
	rings.clear()
	if completion != null:
		completion.hide()
	queue_redraw()

func _draw() -> void:
	if rescue_remaining > 0.0:
		var k := 1.0 - rescue_remaining / RESCUE_DURATION
		var pos := rescue_origin.lerp(game.site.extraction_pos(),smoothstep(0.0,1.0,k))
		var alpha := 1.0 - smoothstep(0.25,1.0,k)
		var size := Vector2.ONE * lerpf(96.0,36.0,k)
		draw_set_transform(pos,-PI/2)
		draw_texture_rect(VoidArt.SKIFF,Rect2(-size/2,size),false,Color(0.65,1.0,0.9,alpha))
		draw_set_transform(Vector2.ZERO)
		draw_arc(game.site.extraction_pos(),42+k*70,0,TAU,64,Color(0.4,1,0.8,alpha),3,true)
	for ring in rings:
		var k: float = 1.0 - float(ring["life"]) / 0.38
		var tint_r := Color(0.6, 1.0, 0.95, (1.0 - k) * 0.7)
		draw_arc(ring["pos"], 6.0 + k * 30.0, 0.0, TAU, 40, tint_r, 1.6, true)
	for spark in sparks:
		var tint: Color = spark["color"]
		tint.a = clampf(spark["life"] / 0.55, 0, 1)
		draw_circle(spark["pos"], 1.7, tint)
	for popup in popups:
		var tint: Color = popup["color"]
		tint.a = clampf(popup["life"] / 0.5, 0, 1)
		draw_string(ThemeDB.fallback_font, popup["pos"] + Vector2(-8, -20), popup.get("text", "+%d" % popup["value"]), HORIZONTAL_ALIGNMENT_LEFT, 180, 17, tint)
