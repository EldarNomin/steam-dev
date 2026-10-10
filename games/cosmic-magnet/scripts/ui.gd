extends CanvasLayer
## Слой интерфейса. Обрабатывает Esc даже в паузе (process_mode = ALWAYS),
## сама симуляция остановлена через SceneTree.paused (CM-R01).
## Esc в главном меню/подтверждении не ставит паузу: меню закрытием
## подтверждения, иначе игнорируется.

@onready var game: MainGame = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_ESCAPE
	):
		if game.menu_visible:
			if game.new_game_confirm.visible:
				game._hide_new_game_confirm()
				get_viewport().set_input_as_handled()
			return
		game.toggle_pause()
		get_viewport().set_input_as_handled()
