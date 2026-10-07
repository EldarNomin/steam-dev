# DEV-002: локальная проверка

Дата / исполнитель: 2026-10-07, локальный GLM (ZCode)
ОС / GPU / Editor: Windows 11 Pro (10.0.26200) / NVIDIA GeForce RTX 4070 (standalone) / Unity 6000.3.25f1 (e1dba0a9aba4)
Ветка / base: `feature/DEV-002-player` от `37156ba` (проверенный DEV-001)
Мост: Unity CLI batchmode; standalone-проверки с программным вводом (scancode-инъекции; vk-инъекции Raw Input не видит)

## Что реализовано

- `Runtime/Player/`: `PlayerMovementDefinition` (ScriptableObject; числа из balance.v0.1.json «movement»; создаются editor-сетапом, обновление — только синхронно с балансом), `PlayerInputHub` (Input System actions кодом; владение и Disable/Destroy), `FirstPersonController` (CharacterController; нормализация диагонали, прыжок с земли `sqrt(2·g·h)`, pitch clamp ±89°, blend гравитации, границы площадки, респавн ниже killY), `GravityBlender` (чистый линейный blend за 0.3 с), `MoveNormalizer` (чистый), `LowGravityZone` (триггер+маркер), `PlayerRig` (composition root: курсор, блокировка ввода в меню, применение настроек).
- `Runtime/Interaction/`: `InteractionTarget` (точка расширения), `Interactor` (raycast из камеры, 2 м, слой Player исключён, препятствие перекрывает цель — первый хит не-цель = блок), `InteractionGate` (чистая проверка), `Terminal` («Терминал готов»).
- `Runtime/Presentation/`: `StationHud` (прицел, «КОСМОЛОВ», подсказка `E — Проверить терминал`, ответ терминала; DEV-001 полноэкранный overlay заменён компактным), `PauseMenu` (Esc, Продолжить/Настройки/Выйти; в меню курсор свободен, геймплей заблокирован).
- `Runtime/Settings/GameSettings`: JSON в `persistentDataPath` (без AssetDatabase/Docs-путей), чувствительность/инверсия Y/громкость, применение на старте.
- `Editor/PlayerRigSetup` (`Cosmic Catch/Setup/Add DEV-002 player rig` + batch): слой Player, риг на существующей камере (перенос под игрока, ссылки и материалы Boot сохранены), терминал на «Cargo terminal», зона низкой гравитации с полупрозрачным маркером, definition-ассет.
- `Tests/EditMode/`: 11 тестов — нормализация (4), гравитационный blend (4, поймали и исправили экспоненциальный недолёт: MoveTowards от текущей разницы не достигал цели за 0.3 с), interaction gate (3).
- manifest: +`com.unity.test-framework` 1.6.0; asmdef Runtime: +`Unity.InputSystem`.

## Проверки

| Проверка | Статус | Фактический результат / evidence |
|---|---|---|
| Компиляция после изменений | PASS | 0 ошибок CS после фиксов (asmdef ref, Input System 1.20 API: конструктор `InputActionAsset`, отсутствие `Dispose`) |
| EditMode-тесты | PASS | 11/11 (`Reports/editmode-tests.xml` локально) |
| Диагональ не быстрее прямой | PASS | Тест `DiagonalIsNotFasterThanStraight` (clamp до единичной длины) |
| Гравитация 9.81↔3.0 за 0.3 с | PASS (логика) | Тесты `GravityBlenderTests`; баг найден и исправлен |
| Дальность/препятствие взаимодействия | PASS (логика) | `InteractionGateTests` + raycast-первый-хит |
| Windows build | PASS | Succeeded 0/0 после всех фиксов |
| Standalone: запуск, HUD | PASS | Кадр спавна: прицел, «КОСМОЛОВ», станция от первого лица |
| Standalone: ходьба W | PASS | 1.5 с W → вид сместился (кадр `standalone-walked.png` отличается, игрок у грузовой зоны) |
| Standalone: Esc-меню | PASS | Окно «Меню/Продолжить/Настройки/Выйти» (`standalone-menu.png`) |
| Standalone: кнопка «Выйти» | PASS | Клик → процесс завершён, код 0 |
| Standalone: Player.log | PASS | 0 исключений (после фикса `InputActionAsset` CreateInstance) |
| Terminal E / близко/за стеной/удержание | NOT RUN (авто) | Требует наведения прицела; логика покрыта тестами gate; ручной чек-лист ниже |
| Прыжок, повторный вход в Play Mode, alt-tab, сохранение настроек | NOT RUN (авто) | Ручной чек-лист для Эльдара |
| Editor Play Mode геймплей | NOT RUN (авто) | Editor GUI требует ручного пропуска admin-диалога; движение/меню подтверждены в standalone |

## Ошибки до/после

- До: 21× CS0246/CS0234 (asmdef без `Unity.InputSystem`); CS1729/CS1061 (API Input System 1.20); `InputActionAsset must be instantiated using ScriptableObject.CreateInstance` (крашил rig в standalone — клавиши/меню не работали); GravityBlender недотягивал до цели за окно.
- После: компиляция 0, тесты 11/11, standalone-проход без исключений.

## Evidence

- `Docs/Evidence/DEV-002/standalone-spawn.png` — спавн, HUD, прицел
- `Docs/Evidence/DEV-002/standalone-walked.png` — после 1.5 с W (вид изменился)
- `Docs/Evidence/DEV-002/standalone-menu.png` — Esc-меню

## Ручной чек-лист для Эльдара (Editor + standalone)

1. Прыжок Space: с земли — да, в воздухе — нет; высота ~1.2 м.
2. E: вплотную к терминалу — подсказка и «Терминал готов»; дальше 2 м, за стеной корпуса, взгляд в сторону — подсказки нет; удержание E — одно событие.
3. Синяя зона: вход — прыжок выше/падение медленнее; выход — 0.3 с; повторный вход/выход; «вечного полёта» нет.
4. Настройки: изменить чувствительность/инверсию/громкость → Сохранить → перезапустить exe → применились.
5. Alt-tab и возврат: управление не залипает; повторные Esc/Play Mode — курсор и меню корректны.

Не объявлять TC-004/TC-028 пройденными: скорость с грузом, полный MVP и сеть отсутствуют.

Commit: см. ветку `feature/DEV-002-player` (PR №2).
