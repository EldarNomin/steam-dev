# DEV-001: локальная проверка

Дата / исполнитель: 2026-10-07, локальный GLM (ZCode, сессия steam-dev)
ОС / GPU / версия Editor: Windows 11 Pro (10.0.26200, elevated-сессия) / Citrix Indirect Display Adapter / Unity 6000.3.25f1 (e1dba0a9aba4)
Исходный commit: `eaeb3fc` (ветка `feature/DEV-001-unity-baseline`)
Активный проект / использованный мост (без секретов): `C:\Users\user\steam-dev`; MCP-мост не подключён — доступ через Unity CLI (batchmode + запуски GUI); логи: `Reports/unity-setup.log`, `Reports/unity-build.log`, `Reports/playmode-capture.log`

| Проверка | PASS / FAIL / BLOCKED | Фактический результат / evidence |
|---|---|---|
| Доступ к Editor: Console и hierarchy | BLOCKED (частично) | MCP-моста нет. Через CLI доступен полный editor-лог (= Console): реальные ошибки компиляции получены и исправлены. Живая иерархия открытого Editor не читалась: GUI-редактор, запущенный из этой сессии, блокируется модальным окном «Administrator Privileges Detected» (сессия повышенной привилегии; runas /trustlevel не помог — диалог показывает любой GUI-запуск в этой сессии) |
| Package import и C# compilation | PASS | Первый прогон: 2 ошибки `error CS0266` в `BuildCommands.cs:64-65` (int→uint). После фикса — компиляция 0 ошибок, `packages-lock.json` сгенерирован (URP 17.3.0 разрешён) |
| Setup и сохранение Boot | PASS | Созданы `Assets/_Game/Scenes/Boot.unity`, `Settings/CosmicCatchURP.asset`, `Settings/CosmicCatchRenderer.asset`, `Materials/{Hull,Accent,Creature}.mat`; GraphicsSettings/QualitySettings указывают на CosmicCatchURP |
| Play Mode, материалы, русский текст | PASS по standalone; Editor-кадр BLOCKED | Рендер проверен в standalone (та же сцена и overlay): нет розовых материалов, «КОСМОЛОВ» и русский текст на месте, краб-заглушка видна. Editor Game View в Play Mode не снят — блокер выше; batchmode Game View не рендерит |
| Повторный Setup: GUID сохранены | PASS | GUID Boot/CosmicCatchURP/3 материалов идентичны до и после (`Reports/guids-run{1,2}.txt`, diff пуст); в EditorBuildSettings Boot присутствует ровно один раз и остаётся первой сценой |
| Windows build | PASS | `Reports/windows-build.json`: Succeeded, errors 0, warnings 0, 92 МБ, 48 с, `Builds/Windows/CosmicCatch.exe` |
| Запуск exe и выход | PASS | Окно 1280×720; клик по кнопке «Выйти» → процесс завершился с кодом 0; `Player.log` (`AppData/LocalLow/Cosmic Catch/Cosmic Catch/`) без исключений |

Изменённые файлы и причины:
- `Assets/_Game/Editor/BuildCommands.cs` — фикс CS0266: поля `errors`/`warnings` изменены `uint`→`int` (в 6000.3 `summary.totalErrors/totalWarnings` — int).
- Сгенерировано Editor'ом: `Assets/_Game/Scenes/Boot.unity`, `Assets/_Game/Settings/*` (URP, renderer, материалы) с `.meta`; `Packages/packages-lock.json`; полный набор `ProjectSettings/*`.
- `.gitignore` — добавлен `Reports/` (локальные логи не публикуются).
- Временный editor-скрипт для Play Mode-кадра создан и удалён после попыток; в репозиторий не входит.

Ошибки до исправления / после исправления:
- До: `Assets\_Game\Editor\BuildCommands.cs(64,26): error CS0266: Cannot implicitly convert type 'int' to 'uint'` и то же в `(65,28)`.
- После: `grep -cE "error CS" Reports/unity-setup.log` → 0; build summary errors 0.

Скриншот: [Docs/Evidence/DEV-001/build-standalone.png](../Evidence/DEV-001/build-standalone.png) — окно standalone-сборки (Game View той же сцены): станция, корабль, терминал, оранжевая фигура краба, «КОСМОЛОВ», «Выйти».

Что не проверено и почему:
- Снимок Game View именно в Editor Play Mode — блокер: admin-модальное окно в GUI-редакторе (elevated-сессия), кнопки недоступны UI Automation (IMGUI); альтернативное evidence — standalone-кадр выше.
- TC-028 (30 минут готового MVP), сеть, движение — вне рамок DEV-001.

Commit с кодом/сценой / PR: см. commit `feat(DEV-001): verify baseline in real editor` в ветке `feature/DEV-001-unity-baseline`; PR №1.
