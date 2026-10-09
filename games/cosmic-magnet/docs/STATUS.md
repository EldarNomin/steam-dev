# Состояние проекта

Обновлено: 2026-10-09. CM-002 реализован и сдан (READY_FOR_REVIEW); ждём решения Codex.

| Задача | Состояние | Результат / блокер |
|---|---|---|
| CM-001 | ACCEPTED | PR #3, проверен `67e2a03daadf11505fe1f57b3fafcce8149cb20c`. Решение: `docs/reports/CM-001-review.md`. |
| CM-002 | READY_FOR_REVIEW | Ветка `feat/cosmic-magnet/CM-002-economy` (stacked на CM-001), код `c39c4ff340fc776f433124989c439a1b6774f4c4`. DOCK/SALVAGE, заряд, груз, идемпотентная разгрузка, три улучшения, единый `data/balance.json`. Тесты 37+52 PASS (локально Windows, CI — в PR); видео 210 с с реальными кликами. Отчёт: `docs/reports/CM-002-implementation.md`. CM-003 не начат |
| CM-003 | LOCKED | После приёмки CM-002 |
| CM-004 | LOCKED | После приёмки CM-003; нужны игровые пробы |
| CM-005 | LOCKED | После решения CONTINUE по CM-004 |
| CM-006 | LOCKED | После приёмки CM-005 |
| CM-007 | LOCKED | После приёмки CM-006 |
| CM-008 | LOCKED | После приёмки CM-007 |

Допустимые состояния: LOCKED, CURRENT, IN_PROGRESS, READY_FOR_REVIEW, CHANGES_REQUESTED, BLOCKED, ACCEPTED. У задачи указывать PR, SHA проверенного кода и ссылку на отчёт. Новые коммиты после проверки требуют повторной проверки затронутой части.

GLM может отметить реализацию готовой, но не принимает свою работу. Решения Codex записываются в `docs/reports/CM-XXX-review.md`. При BLOCKED указывается, что именно нельзя проверить и кто/что нужен для продолжения.
