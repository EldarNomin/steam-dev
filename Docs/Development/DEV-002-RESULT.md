# DEV-002: локальная проверка

Дата / исполнитель: 2026-10-07, локальный GLM (ZCode). Вторая итерация — исправления по ревью Codex (cf43a06).
ОС / GPU / Editor: Windows 11 Pro (10.0.26200) / NVIDIA GeForce RTX 4070 (standalone) / Unity 6000.3.25f1 (e1dba0a9aba4)
Ветка / base: `feature/DEV-002-player` от `37156ba`; мерж main в ветку выполнен (см. конец файла)
Мост: Unity CLI batchmode + GUI-прогоны через планировщик; standalone-ввод — scancode-инъекции (vk-инъекции Raw Input не видит)

## Исправления по ревью Codex

1. **Esc не закрывал меню** — `PlayerInputHub` отключал все actions, включая сам Esc. Исправлено: две карты — `Gameplay` (move/look/jump/interact) и `System` (menu); гейтинг отключает только Gameplay. Регрессия покрыта PlayMode-тестом `MenuGatingStopsMovementAndEscKeepsWorking` (Esc регистрируется при выключенном геймплее) и standalone-сценарием (Esc открыл → Esc закрыл).
2. **Маркер зоны без материала** — материал создавался после назначения, повторный Setup не лечил. Исправлено: `EnsureZoneMarkerMaterial()` вызывается до `EnsureLowGravityZone()`; повторный Setup «лечит» пустую ссылку (`HealZoneMarker`). В сцене ссылка заполнена.
3. **Ложные срабатывания валидатора** — `Tools/validate_project.py`: в известные пакетные сборки добавлен `Unity.InputSystem`; поиск `UnityEditor` в Runtime-коде игнорирует строчные и блочные комментарии (учёт кавычек). Прогон: `Repository checks: PASS`.
4. **Некорректное подтверждение Editor Play Mode** — «белый» кадр убран, снят настоящий: Editor 6000.3.25f1, Boot, Play Mode (▶ активен, DontDestroyOnLoad), Game View от лица игрока: «КОСМОЛОВ», прицел, станция, корабль; Console — только внутренний баг `UnityEditor.Search.SearchDatabase` при старте. Захват — PrintWindow окна редактора (пассивно, без фокуса/ввода). Evidence: `Docs/Evidence/DEV-001/boot-playmode.png`, обновлён [DEV-001-LOCAL-RESULT](DEV-001-LOCAL-RESULT.md).

Попутно найдено и исправлено реальным прогоном:
- **`CharacterController.minMoveDistance`** — при высоком FPS гравитационный шаг за кадр меньше дефолтного 0.001 и контроллер не «садится» на пол (висит на 0.58). `minMoveDistance = 0` в `FirstPersonController.Awake`.
- **`InputActionAsset`** в standalone обязан создаваться через `ScriptableObject.CreateInstance` (plain `new` кидал исключение — ввод не работал в сборке).
- asmdef Runtime: +`Unity.InputSystem`; манифест: +`com.unity.test-framework` 1.6.0.
- Спавн: игрок ставится лицом к грузовому терминалу в пределах 2 м (spawnPoint в definition, `SetStartPitch(-15°)`, идемпотентно при повторном Setup).

## Автоматические проверки

| Проверка | Статус | Как |
|---|---|---|
| EditMode (логика) | PASS 13/13 | нормализация движения (4), гравитационный blend 9.81↔3.0 за 0.3 с (4), interaction gate (3), сохранение настроек JSON (2) |
| PlayMode (поведение, виртуальная клавиатура, изолированная сцена) | PASS 5/5 | ходьба 5 м за 1 с (измерено), диагональ не быстрее (измерено), прыжок apex 1.25 м + нет двойного прыжка (измерено), триггер зоны низкой гравитации, гейтинг меню + Esc при выключенном геймплее |
| Компиляция | PASS | 0 ошибок после всех фиксов |
| Windows build | PASS | Succeeded, 0 ошибок / 0 предупреждений |
| Валидатор | PASS | `python Tools/validate_project.py` — PASS |

Замечание к методике PlayMode-тестов: тесты выполняются в изолированной сцене (`SceneManager.CreateScene` + активная сцена), ввод — полные `KeyboardState`-события виртуальной клавиатуры; кнопочные `performed`-фазы проверяются в кадре ручного `InputSystem.Update()` ( editor-update тик иначе поглощает событие).

## Standalone (Windows exe)

| Проверка | Статус | Результат |
|---|---|---|
| Полный сценарий: спавн → E (ответ терминала) → прыжок → Esc (открыть) → Esc (закрыть) → «Выйти» | PASS (функционально) | Сценарий выполняется целиком, Player.log без исключений, выход по «Выйти» кодом 0 (подтверждено в двух прогонах) |
| Кадры спавна/ходьбы/меню | PASS | [standalone-spawn](../Evidence/DEV-002/standalone-spawn.png) (прицел, «КОСМОЛОВ»), [standalone-walked](../Evidence/DEV-002/standalone-walked.png) (после 1.5 с W вид сместился), [standalone-menu](../Evidence/DEV-002/standalone-menu.png) (меню) |
| Свежие кадры подсказки/ответа терминала | NOT DONE | Синтетический ввод остановлен: пользователь работает за машиной, кадры захватиля чужие окна. Подсказка/ответ проверяются вручную (чек-лист ниже) либо повторным прогоном при пустой машине |

## Ручной чек-лист для Эльдара

1. Спавн: подсказка «E — Проверить терминал» видна сразу; E → «Терминал готов»; дальше 2 м / за стеной / взгляд в сторону — подсказки нет.
2. Прыжок: с земли — да, в воздухе — нет.
3. Синяя зона: вход/выход/повторный вход, «вечного полёта» нет.
4. Настройки: изменить → Сохранить → перезапуск exe → применились.
5. Alt-tab: управление не залипает; повторные Esc/Play Mode — курсор корректен.

TC-004/TC-028 не пройдены (скорость с грузом — DEV-005, полный MVP — не собран). Не объявлять их PASS.

## Итог

- Тесты: 18/18 (13 EditMode + 5 PlayMode).
- Сборка: Succeeded 0/0; exe работает, Player.log чист.
- Конфликты с main: устранены мержем (см. историю ветки).
- Commit: см. ветку `feature/DEV-002-player` (PR №2).

## Что реализовано

- `Runtime/Player/`: `PlayerMovementDefinition` (ScriptableObject; числа из balance.v0.1.json «movement»; создаются editor-сетапом, обновление — только синхронно с балансом), `PlayerInputHub` (Input System actions кодом; владение и Disable/Destroy), `FirstPersonController` (CharacterController; нормализация диагонали, прыжок с земли `sqrt(2·g·h)`, pitch clamp ±89°, blend гравитации, границы площадки, респавн ниже killY), `GravityBlender` (чистый линейный blend за 0.3 с), `MoveNormalizer` (чистый), `LowGravityZone` (триггер+маркер), `PlayerRig` (composition root: курсор, блокировка ввода в меню, применение настроек).
- `Runtime/Interaction/`: `InteractionTarget` (точка расширения), `Interactor` (raycast из камеры, 2 м, слой Player исключён, препятствие перекрывает цель — первый хит не-цель = блок), `InteractionGate` (чистая проверка), `Terminal` («Терминал готов»).
- `Runtime/Presentation/`: `StationHud` (прицел, «КОСМОЛОВ», подсказка `E — Проверить терминал`, ответ терминала; DEV-001 полноэкранный overlay заменён компактным), `PauseMenu` (Esc, Продолжить/Настройки/Выйти; в меню курсор свободен, геймплей заблокирован).
- `Runtime/Settings/GameSettings`: JSON в `persistentDataPath` (без AssetDatabase/Docs-путей), чувствительность/инверсия Y/громкость, применение на старте.
- `Editor/PlayerRigSetup` (`Cosmic Catch/Setup/Add DEV-002 player rig` + batch): слой Player, риг на существующей камере (перенос под игрока, ссылки и материалы Boot сохранены), терминал на «Cargo terminal», зона низкой гравитации с полупрозрачным маркером, definition-ассет.
- `Tests/EditMode/`: 11 тестов — нормализация (4), гравитационный blend (4, поймали и исправили экспоненциальный недолёт: MoveTowards от текущей разницы не достигал цели за 0.3 с), interaction gate (3).
- manifest: +`com.unity.test-framework` 1.6.0; asmdef Runtime: +`Unity.InputSystem`.

## Evidence

- `Docs/Evidence/DEV-002/standalone-spawn.png`, `standalone-walked.png`, `standalone-menu.png`
- `Docs/Evidence/DEV-001/boot-playmode.png` (Editor Play Mode, общий с DEV-001)
- Логи прогонов локальны (`Reports/`, в Git не входят)
