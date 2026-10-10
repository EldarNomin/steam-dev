# Состояние проекта

Обновлено: 2026-10-10. CM-004: подготовка принята, плейтест предстоит. PR #8: CHANGES_REQUESTED по анимациям.

| Задача | Состояние | Результат / блокер |
|---|---|---|
| CM-001 | ACCEPTED | PR #3, проверен `67e2a03daadf11505fe1f57b3fafcce8149cb20c`. Решение: `docs/reports/CM-001-review.md`. |
| CM-002 | ACCEPTED | PR #4; проверен `9df3ae9dee64930d119544af2c3db82b8a140f83`. Решение: `docs/reports/CM-002-review.md` (финальная приёмка). |
| CM-003 | ACCEPTED | PR #5; головы `d75af84` → `58e4022` (F1–F4) → `b926bc7` (F5 атомарный .bak). Все замечания закрыты, решение Codex на `b926bc7` (передано Эльдаром). |
| CM-004 | IN_PROGRESS | PR #6: подготовка плейтеста ACCEPTED на коде `987ae7456e9bbc167c0011e87136171fa8179874` / docs `a11bb5a`; F1–F3 закрыты Codex (логи cache hit, ZIP с двумя exe). Решение: `docs/reports/CM-004-review.md`. Живые сессии 5–10 человек, публичный ролик и CONTINUE/ITERATE/STOP пока NOT_RUN. |
| CM-005 | IN_PROGRESS | По прямому поручению Эльдара 2026-10-10 начат отдельный визуальный срез в `feat/cosmic-magnet/visual-refresh`: новые спрайты, интерфейс и эффекты; локально import/smoke и 158 проверок PASS. Арт готов к просмотру: `docs/reports/visual-refresh-implementation.md`. Полиш PR #8 на `8f3db771edd7c3c69f5191d5310b6d526336755b` — CHANGES_REQUESTED: координаты хвоста, redraw корабля, сброс вспышки/следа между вылетами. Следующая задача GLM: F1–F3 из `docs/reports/visual-polish-review.md`. Звук/уменьшение эффектов и полная приёмка этапа остаются; решение CONTINUE по CM-004 не заявляется. |
| CM-006 | LOCKED | После приёмки CM-005 |
| CM-007 | LOCKED | После приёмки CM-006 |
| CM-008 | LOCKED | После приёмки CM-007 |

Допустимые состояния: LOCKED, CURRENT, IN_PROGRESS, READY_FOR_REVIEW, CHANGES_REQUESTED, BLOCKED, ACCEPTED. У задачи указывать PR, SHA проверенного кода и ссылку на отчёт. Новые коммиты после проверки требуют повторной проверки затронутой части.

GLM может отметить реализацию готовой, но не принимает свою работу. Решения Codex записываются в `docs/reports/CM-XXX-review.md`. При BLOCKED указывается, что именно нельзя проверить и кто/что нужен для продолжения.
