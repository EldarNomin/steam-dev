# Состояние проекта

Обновлено: 2026-10-10 (поздно). CM-004: правки F1–F3 сданы повторно (READY_FOR_REVIEW); живые сессии и решение о продолжении — после приёмки подготовки.

| Задача | Состояние | Результат / блокер |
|---|---|---|
| CM-001 | ACCEPTED | PR #3, проверен `67e2a03daadf11505fe1f57b3fafcce8149cb20c`. Решение: `docs/reports/CM-001-review.md`. |
| CM-002 | ACCEPTED | PR #4; проверен `9df3ae9dee64930d119544af2c3db82b8a140f83`. Решение: `docs/reports/CM-002-review.md` (финальная приёмка). |
| CM-003 | ACCEPTED | PR #5; головы `d75af84` → `58e4022` (F1–F4) → `b926bc7` (F5 атомарный .bak). Все замечания закрыты, решение Codex на `b926bc7` (передано Эльдаром). |
| CM-004 | READY_FOR_REVIEW | PR #6, повторная сдача на `987ae7456e9bbc167c0011e87136171fa8179874`: F1 (шаблоны ставятся независимо от кеша, проверка существования), F2 (wrapper mode 2 → в ZIP оба exe), F3 (отчёт: SHA, команды, run/artifact ID этой ревизии). Закрытие F1: два Windows-run — 38073114861 (cache miss) и 38073498841 (**cache hit**, экспорт/smoke success); артефакт 11677846540 = CosmicMagnet.exe + .console.exe, локальный запуск main exe без Godot — окно живо. Отчёт: `docs/reports/CM-004-implementation.md` |
| CM-005 | LOCKED | После решения CONTINUE по CM-004 |
| CM-006 | LOCKED | После приёмки CM-005 |
| CM-007 | LOCKED | После приёмки CM-006 |
| CM-008 | LOCKED | После приёмки CM-007 |

Допустимые состояния: LOCKED, CURRENT, IN_PROGRESS, READY_FOR_REVIEW, CHANGES_REQUESTED, BLOCKED, ACCEPTED. У задачи указывать PR, SHA проверенного кода и ссылку на отчёт. Новые коммиты после проверки требуют повторной проверки затронутой части.

GLM может отметить реализацию готовой, но не принимает свою работу. Решения Codex записываются в `docs/reports/CM-XXX-review.md`. При BLOCKED указывается, что именно нельзя проверить и кто/что нужен для продолжения.
