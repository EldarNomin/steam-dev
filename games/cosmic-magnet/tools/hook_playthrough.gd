## QA autopilot: fresh isolated profile; real mouse events; no granted progression.
## Godot --script res://tools/hook_playthrough.gd; optional CM_EVIDENCE_DIR.
extends SceneTree
var game: MainGame
var ticks := 0
var phase := 0
var aiming := Vector2(350,420)
var pressed := false
var dwell := 0
func _initialize() -> void:
 run.call_deferred()
func screen_pos(pos: Vector2) -> Vector2:
 return pos * Vector2(DisplayServer.window_get_size()) / Vector2(1280,720)
func button(pos: Vector2, down: bool) -> void:
 DisplayServer.warp_mouse(screen_pos(pos))
 var event := InputEventMouseButton.new()
 event.position = screen_pos(pos)
 event.global_position = screen_pos(pos)
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = down
 Input.parse_input_event(event)
func click(pos: Vector2) -> void:
 button(pos,true)
 await process_frame
 button(pos,false)
func screenshot(name: String) -> void:
 if OS.get_environment("CM_EVIDENCE_DIR").is_empty():
  return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("CM_EVIDENCE_DIR")+"/"+name+".png")
func run() -> void:
 SaveService.save_dir = "user://hook_render_test"
 SaveService.wipe_files()
 game = preload("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.new_game()
 await process_frame
 await screenshot("hook-start")
 await click(Vector2(1120,680 if game.state == MainGame.GameState.DOCK else 624))
 while ticks < 7200 and not game.site.skiff_recovered:
  ticks += 1
  if ticks % 600 == 0:
   print("PLAY_PROGRESS ticks=",ticks," covers=",game.site.cleared.size()," scrap=",game.economy.scrap," cargo=",game.cargo_mass)
  if game.state == MainGame.GameState.DOCK:
   if not game.pulse.unlocked() and game.economy.can_buy(&"pulse"):
    await click(Vector2(1120,420))
   if game.pulse.unlocked() and game.magnet.strength < 2 and game.economy.can_buy(&"strength"):
    await click(Vector2(1120,155))
   await click(Vector2(1120,680 if game.state == MainGame.GameState.DOCK else 624))
  if game.site.module_found and game.pulse.unlocked() and game.magnet.strength >= 2:
   if game.cargo_mass > game.capacity()-20:
    await click(Vector2(1120,680 if game.state == MainGame.GameState.DOCK else 624))
    continue
   aiming = game.site.skiff_item.position
  elif dwell <= 0:
   dwell = 60
   var best: SalvageItem
   var score := INF
   for obj in game.spawner.get_children():
    if not obj is SalvageItem or obj.collected or obj.is_queued_for_deletion() or obj.required_strength > game.magnet.strength or not game.can_take(obj.mass):
     continue
    if obj.discovery == &"skiff":
     continue
    var d: float = obj.position.distance_squared_to(game.magnet.position)
    if obj.cover_id >= 0 or obj.discovery == &"module":
     d -= 1000000
    if d < score:
     best=obj
     score=d
   if best != null:
    aiming=best.position
  dwell -= 1
  DisplayServer.warp_mouse(screen_pos(aiming))
  if game.pulse.unlocked() and game.pulse.cooldown <= 0:
   if not pressed:
    button(aiming,true)
    pressed=true
   elif game.pulse.held >= 0.75:
    button(aiming,false)
    pressed=false
    if game.pulse.active > 0 and phase==0:
     phase=1
     await screenshot("hook-pulse")
  if game.site.module_found and phase < 2:
   phase=2
   await screenshot("hook-module")
  # Manual dock when enough earned for the next required upgrade.
  if game.state == MainGame.GameState.SALVAGE and ((not game.pulse.unlocked() and game.economy.scrap+game.cargo_value >= 15) or (game.pulse.unlocked() and game.magnet.strength < 2 and game.economy.scrap+game.cargo_value >= 20)):
   button(aiming,false)
   pressed=false
   await click(Vector2(1120,680 if game.state == MainGame.GameState.DOCK else 624))
  await physics_frame
 await process_frame
 await screenshot("hook-end")
 for frame in 240:
  await physics_frame
 print("PLAY_RESULT ticks=",ticks," shots=",game.pulse.shots," covers=",game.site.cleared.size()," module=",game.site.module_found," skiff=",game.site.skiff_recovered," scrap=",game.economy.scrap)
 SaveService.wipe_files()
 quit(0 if game.site.skiff_recovered else 1)
