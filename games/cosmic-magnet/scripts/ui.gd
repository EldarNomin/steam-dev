extends CanvasLayer
## Слой интерфейса. Обрабатывает Esc даже в паузе (process_mode = ALWAYS),
## сама симуляция остановлена через SceneTree.paused (CM-R01).

@onready var game: MainGame = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_ESCAPE
	):
		game.toggle_pause()
		get_viewport().set_input_as_handled()
