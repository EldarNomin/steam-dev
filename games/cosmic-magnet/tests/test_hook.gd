extends SceneTree
var passed := 0
var failed := 0
var game: MainGame

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("PASS " if ok else "FAIL ", label)

func clear_field() -> void:
	for item in game.spawner.get_children():
		item.free()
	game.spawner.clear_pending_respawns()

func item(pos: Vector2, strength := 1, mass := 1) -> SalvageItem:
	var obj := SalvageItem.new()
	obj.game = game
	obj.setup({"id":"nut", "required_strength":strength, "mass":mass, "price":1, "radius":7})
	obj.position = pos
	game.spawner.add_child(obj)
	obj.set_physics_process(false)
	return obj

func run() -> void:
	SaveService.save_dir = "user://hook_test_%d" % randi()
	game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.set_physics_process(false)
	game.spawner.set_physics_process(false)
	game.magnet.set_physics_process(false)
	game.pulse.set_physics_process(false)
	var pulse := game.pulse
	game.launch()
	check(not pulse.begin(Vector2(400,300)), "pulse locked before purchase")
	game._on_buy(&"pulse")
	check(not pulse.unlocked(), "cannot purchase during flight")
	game.request_return()
	game.economy.scrap = 14
	game._on_buy(&"pulse")
	check(not pulse.unlocked() and game.economy.scrap == 14, "unaffordable pulse leaves economy intact")
	game.economy.scrap = game.economy.upgrade_cost(&"pulse")
	game._on_buy(&"pulse")
	check(pulse.unlocked() and game.economy.scrap == 0, "purchase installs pulse exactly once")
	game._on_buy(&"pulse")
	check(game.economy.scrap == 0, "repeat purchase no debit")
	game.continue_game()
	check(pulse.unlocked(), "pulse installation survives continue")
	game.launch()
	clear_field()
	game.magnet.position = Vector2(400,300)
	for i in 8:
		item(Vector2(520+i*5,300))
	var heavy := item(Vector2(510,300),2)
	check(not pulse.begin(Vector2(1100,300)), "cannot arm over shop")
	check(pulse.begin(Vector2(400,300)), "arm in field")
	pulse.step(0.1)
	check(not pulse.release(Vector2(400,300)) and pulse.cooldown == 0, "short click cancels")
	pulse.begin(Vector2(400,300))
	pulse.step(100)
	check(pulse.held == CMConfig.f("pulse.hold_max"), "hold capped")
	check(pulse.release(Vector2(400,300)) and pulse.targets.size() == 8, "snapshot includes eight outside normal radius")
	check(not pulse.targets.has(heavy), "pulse cannot bypass strength")
	check(not pulse.begin(Vector2(400,300)), "cooldown prevents repeat")
	var extra := item(Vector2(520,302))
	check(not pulse.targets.has(extra), "later respawn not added to snapshot")
	var before := game.collected_count
	for obj in pulse.targets.duplicate():
		obj.step(30)
	check(game.collected_count == before+8, "large delta captures group once")
	check(heavy.position == Vector2(510,300), "heavy remains in place")
	game.request_return()
	var cd := pulse.cooldown
	game.launch()
	check(pulse.cooldown == cd and pulse.targets.is_empty(), "dock launch cancels active without bypassing cooldown")
	pulse.step(cd)
	pulse.begin(Vector2(400,300))
	pulse.step(0.8)
	check(not pulse.release(Vector2(1100,300)), "release over shop cancels")
	pulse.begin(Vector2(400,300))
	game.toggle_pause()
	check(not pulse.holding, "pause cancels armed gesture")
	var frozen := pulse.cooldown
	pulse.step(5)
	check(pulse.cooldown == frozen, "paused cooldown frozen")
	game.toggle_pause()
	check(not pulse.release(Vector2(400,300)), "resume release does not fire")
	clear_field()
	pulse.reset(true)
	game.cargo_mass = game.capacity()-1
	var last := item(Vector2(550,300))
	var remaining := item(Vector2(560,300))
	pulse.begin(Vector2(400,300))
	pulse.step(0.8)
	pulse.release(Vector2(400,300))
	last.step(30)
	remaining.step(30)
	check(game.state == MainGame.GameState.DOCK and not remaining.collected, "full hold cancels group and preserves remaining item")
	check(pulse.active == 0 and pulse.targets.is_empty(), "auto return clears transient pulse")
	# Legacy profile has no pulse upgrade key.
	var legacy := {"version":1,"scrap":73,"levels":{"strength":1,"radius":0,"capacity":2},"unique_collected":false,"tutorial_stage":4,"settings":{"master_volume":0.5}}
	check(SaveService.is_valid_save(legacy), "legacy three-upgrade save valid")
	SaveService.save_data(legacy)
	game.continue_game()
	check(not pulse.unlocked() and game.economy.scrap == 73 and game.economy.level(&"capacity") == 2, "legacy continue preserves old progression")
	game.new_game()
	game.launch()
	var covers: Array[SalvageItem] = []
	for obj in game.spawner.get_children():
		if obj is SalvageItem and obj.cover_id >= 0:
			covers.append(obj)
	check(covers.size() == 12 and game.spawner.field_count() <= 40, "twelve stable covers fit original field cap")
	var first := covers[0]
	var first_id := first.cover_id
	first.position += Vector2(10,0)
	check(game.site.cleared.is_empty(), "moving debris does not clear cover")
	game.register_collection(first)
	game.register_collection(first)
	check(game.site.cleared.size() == 1, "actual collection clears cover once")
	game.save_on_exit()
	game.continue_game()
	check(game.site.cleared == [first_id], "unfinished flight persists discovery progress")
	game.launch()
	covers.clear()
	for obj in game.spawner.get_children():
		if obj is SalvageItem and obj.cover_id >= 0:
			covers.append(obj)
	check(covers.size() == 11, "cleared cover never respawns on rebuild")
	for obj in covers:
		game.register_collection(obj)
	await process_frame
	check(game.site.cleared.size() == 12 and is_instance_valid(game.site.module_item), "all covers reveal real module")
	var module := game.site.module_item
	game.register_collection(module)
	check(game.site.module_found and not game.unique_collected, "module unlock independent of old relic")
	check(not game.site.can_collect(game.site.skiff_item), "skiff locked without purchased equipment")
	game.request_return()
	game.economy.scrap = 100
	game._on_buy(&"pulse")
	game._on_buy(&"strength")
	game.launch()
	game.site.ensure_discoveries()
	check(not game.site.can_collect(game.site.skiff_item), "ship remains anchored despite purchased equipment")
	check(game.site.hardware.size() == 6 and game.spawner.field_count() <= 40, "three real relay and clamp pairs fit field cap")
	var clamp: SalvageItem
	var relay: SalvageItem
	for obj in game.site.hardware:
		if obj.clamp_id == 2:
			if obj.discovery == &"clamp":
				clamp = obj
			else:
				relay = obj
	check(not pulse.eligible(clamp) and pulse.eligible(clamp,true), "clamp excluded from direct pulse seeds")
	game.register_collection(clamp)
	game.register_collection(relay)
	check(not clamp.collected and not relay.collected, "hardware cannot be collected as ordinary scrap")
	var relay_pos := relay.position
	relay.step(30)
	check(relay.position == relay_pos, "relay remains a fixed conductor")
	pulse.reset(true)
	game.magnet.position = relay_pos
	pulse.begin(relay_pos)
	pulse.step(0.8)
	pulse.release(relay_pos)
	check(game.site.released == [2], "chain releases the aimed relay rather than earlier field order")
	game.save_on_exit()
	game.continue_game()
	check(game.site.released.size() == 1 and game.site.hardware.size() == 4, "released mooring persists without hardware respawn")
	game.launch()
	for connection in 2:
		var next_relay: SalvageItem
		for obj in game.site.hardware:
			if is_instance_valid(obj) and not obj.collected and obj.discovery == &"relay":
				next_relay = obj
				break
		pulse.step(4)
		game.magnet.position = next_relay.position
		pulse.begin(next_relay.position)
		pulse.step(0.8)
		pulse.release(next_relay.position)
	check(game.site.released.size() == 3 and game.site.can_collect(game.site.skiff_item), "all three chain connections unlock towing")
	game.cargo_mass = game.capacity()-19
	check(not game.site.can_collect(game.site.skiff_item), "skiff respects twenty cargo mass")
	game.cargo_mass = 0
	clear_field()
	pulse.reset(true)
	game.magnet.position = Vector2(300,250)
	var seed := item(Vector2(450,250))
	var hop1 := item(Vector2(520,250))
	var hop2 := item(Vector2(590,250))
	var hop3 := item(Vector2(660,250))
	var chain_heavy := item(Vector2(520,255), 3)
	pulse.begin(Vector2(300,250))
	pulse.step(0.8)
	pulse.release(Vector2(300,250))
	check(pulse.targets.has(seed) and pulse.targets.has(hop1) and pulse.targets.has(hop2) and not pulse.targets.has(hop3), "chain extends exactly two hops")
	check(not pulse.targets.has(chain_heavy), "chain retains strength restrictions")
	pulse.reset(true)
	for n in 30:
		item(Vector2(515+n*0.5,252))
	pulse.begin(Vector2(300,250))
	pulse.step(0.8)
	pulse.release(Vector2(300,250))
	check(pulse.targets.size() <= 20, "chain bounded by twelve seeds plus eight extras")
	clear_field()
	game.site.ensure_discoveries()
	var skiff := game.site.skiff_item
	var money := game.economy.scrap
	game.register_collection(skiff)
	check(not skiff.collected, "skiff requires an active pulse, not just installed upgrade")
	pulse.reset(true)
	game.magnet.position = skiff.position
	pulse.begin(skiff.position)
	pulse.step(0.8)
	pulse.release(skiff.position)
	game.register_collection(skiff)
	check(not skiff.collected, "pulse at original ship location cannot finish extraction")
	var old_position := skiff.position
	game.magnet.position = old_position+Vector2(-150,0)
	skiff.step(0.1)
	check(is_equal_approx(skiff.position.distance_to(old_position),16.0), "towing respects configured speed")
	pulse.step(0.8)
	var checkpoint := skiff.position
	skiff.step(0.1)
	check(skiff.position == checkpoint, "ship stops when impulse expires")
	game.save_on_exit()
	game.continue_game()
	skiff = game.site.skiff_item
	check(skiff.position.is_equal_approx(checkpoint) and game.site.released.size() == 3, "tow position survives unfinished trip and reload")
	game.launch()
	pulse.reset(true)
	game.magnet.position = skiff.position
	pulse.begin(skiff.position)
	pulse.step(0.8)
	pulse.release(skiff.position)
	game.toggle_pause()
	skiff.step(1)
	check(skiff.position.is_equal_approx(checkpoint), "pause prevents ship movement")
	game.toggle_pause()
	skiff.position = game.site.extraction_pos()
	game.register_collection(skiff)
	game.register_collection(skiff)
	check(game.site.skiff_recovered and game.state == MainGame.GameState.DOCK and game.economy.scrap == money+100, "skiff rewards once and finishes in dock")
	game.continue_game()
	check(game.site.skiff_recovered and not is_instance_valid(game.site.skiff_item), "completed skiff persists without respawn")
	check(not SaveService.valid_hook({"cleared":[0,0],"module_found":false,"skiff_recovered":false}), "duplicate cover IDs rejected")
	check(not SaveService.valid_hook({"cleared":[12],"module_found":false,"skiff_recovered":false}), "out of range cover rejected")
	check(not SaveService.valid_hook({"cleared":[],"module_found":true,"skiff_recovered":false}), "premature module save rejected")
	check(not SaveService.valid_hook({"cleared":[],"module_found":false,"skiff_recovered":true}), "premature completed save rejected")
	var completed_legacy := game.site.snapshot()
	completed_legacy.erase("released")
	completed_legacy.erase("skiff_position")
	game.site.restore(completed_legacy)
	check(game.site.skiff_recovered and SaveService.valid_hook(game.site.snapshot()), "completed H01 profile migrates without reopening ship")
	var bad := game.site.snapshot()
	bad["released"] = [0,0]
	check(not SaveService.valid_hook(bad), "duplicate moorings rejected")
	bad = game.site.snapshot()
	bad["skiff_position"] = [1200,900]
	check(not SaveService.valid_hook(bad), "off-field ship save rejected")
	bad["skiff_position"] = ["bad",220]
	check(not SaveService.valid_hook(bad), "nonnumeric ship position rejected")
	game.new_game()
	check(game.site.released.is_empty() and game.site.skiff_location == game.site.skiff_pos, "new game resets tow and moorings")
	check(game.site.cleared.is_empty() and not game.site.module_found and not game.site.skiff_recovered and not pulse.unlocked(), "new game resets whole hook")
	var deleted: Variant = item(Vector2(300,250))
	deleted.free()
	check(not pulse.eligible(deleted), "freed pulse target safely rejected during drawing")
	SaveService.wipe_files()
	DirAccess.remove_absolute(SaveService.save_dir)
	game.free()
	print("SUMMARY passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)
