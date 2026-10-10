# Visual polish — проверка Codex

Дата: 2026-10-10. PR: https://github.com/EldarNomin/steam-dev/pull/8
Проверенный head: `8f3db771edd7c3c69f5191d5310b6d526336755b`.
База: `e31b8629110014c01a30e514a813bbdbd308e707` (visual-refresh).

**Решение: CHANGES_REQUESTED. Три P2-дефекта анимаций. Механика/экономика/сохранения не требуют переработки по этому diff.**

Прочитаны AGENTS, README, SPEC, PLAN, STATUS, REVIEW, полный diff пяти скриптов и обсуждение PR. Замечания также найдены автоматическим Codex review; ниже они самостоятельно подтверждены запуском проверенного head. Код реализации не исправлялся, PR не сливался.

## Выполненные проверки

Среда собственного запуска: Linux, Godot `4.5.1.stable.official.f62fdbde1`, Compatibility OpenGL, Xvfb 1280×720, Mesa llvmpipe, Dummy audio. Отдельный временный профиль `user://codex_visual_polish_review` удалён после проверки.

Из корня checkout, `GODOT` — официальный бинарник 4.5.1:

```sh
$GODOT --headless --path games/cosmic-magnet --editor --import
$GODOT --headless --path games/cosmic-magnet --quit-after 120
$GODOT --headless --path games/cosmic-magnet --script tests/test_core.gd
$GODOT --headless --path games/cosmic-magnet --script tests/test_economy.gd
$GODOT --headless --path games/cosmic-magnet --script tests/test_save.gd
```

Import/smoke PASS; suites 37/37 + 61/61 + 60/60 = **158 PASS**. Сообщения Parse JSON failed и предупреждение backup относятся к намеренным негативным тестам сохранения; импорт и smoke без SCRIPT ERROR/ERROR. Последний shell exit 1 был результатом `rg` без совпадений в import.log, не падением тестов.

CI проверенного head: https://github.com/EldarNomin/steam-dev/actions/runs/38079031093 — три jobs success: headless 114291942271, gameplay video 114292028554, Windows 114292028582. Артефакты: gameplay 11678654654; Windows 11678504395. Запись CI в этой проверке не просматривалась, локальный GLM путь `C:/Users/user/godot/polish.mp4` недоступен. Windows игровой цикл/звук/производительность здесь NOT_RUN. CI success не проверяет правильность анимаций.

Дополнительно запущена настоящая сцена с отрисовкой; мышь перемещена через DisplayServer.warp_mouse. После короткого прогрева остановлена обработка прочих предметов для изолированных измерений. Для авторазгрузки использован настоящий register_collection последнего подходящего предмета. Два реальных кадра проверены визуально: смещённое свечение хвоста видно далеко от магнита, при повторном вылете видна старая вспышка.

## Замечания

### F1 — P2: хвост рисуется в неверной системе координат

`scripts/magnet.gd:37, 68–70`. В _trail записана parent-space position, но draw_circle исполняется в локальной системе магнита. Трансформация применяется повторно: при магните (420,300) образец (420,300) рисуется в (840,600). Хвост оторван от магнита и у правого/нижнего края уходит за окно.

Ремонт: хранить мировые координаты и перед рисованием преобразовывать to_local либо вычитать текущую position из parent-space образца при текущем identity transform родителя. Очистить историю при новом вылете/новой игре. Проверить движение в центре и у всех краёв: след остаётся на пройденном пути, не удваивает координаты.

### F2 — P2: корабль и огни остаются неподвижны

`scripts/ship_wreck.gd:27–40`. Время читается в _draw, но нет processing callback с queue_redraw. Перерисовка родительского MainGame не вызывает повторное построение draw-команд ребёнка; _apply_stats обновляет корабль только при изменении характеристик/запуске забега. Счётчик сигнала draw после прогрева: **0 новых отрисовок за 1 секунду**. Дрейф и мигание заморожены до следующего обновления статистики.

Ремонт: добавить собственный _process(delta) с queue_redraw, соблюдая паузу и выбранную политику меню. Проверить минимум 3 секунды без покупок: положение отрисованного корпуса и огни должны изменяться; gameplay-позиция корабля не должна дрейфовать.

### F3 — P2: вспышка последнего сбора переносится в следующий вылет

`scripts/magnet.gd:32–41`, `scripts/presentation.gd:192–195`; контекст game.gd:197–228 и launch/request_return. collected вызывает flash=1, последний предмет сразу переводит игру в DOCK. В DOCK _physics_process возвращается до затухания. Через секунду flash остаётся 1, launch её не сбрасывает: следующий вылет начинается вспышкой без нового сбора. Старые 9 образцов хвоста также сохраняются.

Ремонт: сбрасывать визуальное состояние при возврате/старте нового вылета или затухать независимо от SALVAGE; очищать историю при телепортации магнита. Проверить полный трюм → ждать в доке → LAUNCH, ручной возврат сразу после сбора, новую игру и продолжение. Новый вылет не показывает прошлую вспышку/старый след.

## Фактический вывод диагностического запуска

```text
SHIP additional_draws_in_1s=0
TRAIL magnet=(420.0, 300.0) stored_sample=(420.0, 300.0) drawn_world_center=(840.0, 600.0) intended=(420.0, 300.0)
FLASH after_full_cargo state=0 flash=1.0
FLASH after_1s_dock=1.0
FLASH immediately_on_relaunch=1.0 trail_samples_retained=9
```

## Следующая задача

GLM: исправить F1–F3 отдельным небольшим коммитом поверх PR #8; повторить import/smoke/158 проверок и показать доступную запись движения, корабля без покупок и двух последовательных вылетов. Добавить implementation-report по REVIEW с SHA, командами и ссылкой на CI artifact (локальный путь видео не является доступным доказательством). Не расширять механику. CM-005 полностью не принят: звук/уменьшение эффектов остаются вне этого среза.

## Воспроизводитель

Сохранить следующий скрипт вне проекта как /tmp/repro.gd и выполнить с настоящим дисплеем (Xvfb также подходит):

```sh
$GODOT --audio-driver Dummy --path games/cosmic-magnet --resolution 1280x720 --position 0,0 --script /tmp/repro.gd
```

```gdscript
extends SceneTree

var ship_draws := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	SaveService.save_dir = "user://codex_visual_polish_review"
	SaveService.wipe_files()
	var game = load("res://scenes/main.tscn").instantiate()
	game.get_node("ShipWreck").draw.connect(func(): ship_draws += 1)
	root.add_child(game)
	await process_frame
	game.new_game()
	game.launch()
	DisplayServer.warp_mouse(Vector2(420, 300))
	await create_timer(0.5).timeout
	# Keep unrelated item collection out of the animation probes.
	game.spawner.set_physics_process(false)
	for item in game.get_node("ItemField").get_children():
		item.set_physics_process(false)
	var ship_before := ship_draws
	await create_timer(1.0).timeout
	print("SHIP additional_draws_in_1s=", ship_draws - ship_before)
	var sample: Vector2 = game.magnet._trail[0]
	print("TRAIL magnet=", game.magnet.position, " stored_sample=", sample,
		" drawn_world_center=", game.magnet.to_global(sample), " intended=", sample)
	await RenderingServer.frame_post_draw
	game.cargo_mass = game.capacity() - 1
	var item := SalvageItem.new()
	item.mass = 1
	item.price = 1
	item.position = game.magnet.position
	game.get_node("ItemField").add_child(item)
	item.set_physics_process(false)
	game.register_collection(item)
	print("FLASH after_full_cargo state=", game.state, " flash=", game.magnet._flash)
	await create_timer(1.0).timeout
	print("FLASH after_1s_dock=", game.magnet._flash)
	game.launch()
	print("FLASH immediately_on_relaunch=", game.magnet._flash,
		" trail_samples_retained=", game.magnet._trail.size())
	game.magnet.set_physics_process(false)
	await RenderingServer.frame_post_draw
	SaveService.wipe_files()
	game.free()
	quit()
```
