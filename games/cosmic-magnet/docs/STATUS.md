# Состояние проекта

Обновлено: 2026-10-10. CM-003 принят Codex (F1–F5 закрыты, решение на `b926bc7`, передано Эльдаром). CM-004: подготовка плейтеста сдана GLM (READY_FOR_REVIEW); живые сессии и UX-выводы — за Эльдаром.

| Задача | Состояние | Результат / блокер |
|---|---|---|
| CM-001 | ACCEPTED | PR #3, проверен `67e2a03daadf11505fe1f57b3fafcce8149cb20c`. Решение: `docs/reports/CM-001-review.md`. |
| CM-002 | ACCEPTED | PR #4; проверен `9df3ae9dee64930d119544af2c3db82b8a140f83`. Решение: `docs/reports/CM-002-review.md` (финальная приёмка). |
| CM-003 | ACCEPTED | PR #5; головы `d75af84` → `58e4022` (F1–F4) → `b926bc7` (F5 атомарный .bak). Все замечания закрыты, решение Codex на `b926bc7` (передано Эльдаром). |
| CM-004 | READY_FOR_REVIEW | Ветка `feat/cosmic-magnet/CM-004-playtest` (stacked на CM-003). Готово GLM: export-пресет «Windows Desktop» (embed_pck), CI job `windows-build` (SHA512 Godot+templates, экспорт, smoke билда, артефакт `cosmic-magnet-windows-x64`), плейтест-кит `docs/playtest/` (анкета + процедура с критерием решения). Живые сессии 5–10 человек, ролик и анализ — Эльдар/Codex (NOT_RUN). Отчёт: `docs/reports/CM-004-implementation.md` |
| CM-005 | LOCKED | После решения CONTINUE по CM-004 |
| CM-006 | LOCKED | После приёмки CM-005 |
| CM-007 | LOCKED | После приёмки CM-006 |
| CM-008 | LOCKED | После приёмки CM-007 |

Допустимые состояния: LOCKED, CURRENT, IN_PROGRESS, READY_FOR_REVIEW, CHANGES_REQUESTED, BLOCKED, ACCEPTED. У задачи указывать PR, SHA проверенного кода и ссылку на отчёт. Новые коммиты после проверки требуют повторной проверки затронутой части.

GLM может отметить реализацию готовой, но не принимает свою работу. Решения Codex записываются в `docs/reports/CM-XXX-review.md`. При BLOCKED указывается, что именно нельзя проверить и кто/что нужен для продолжения.
