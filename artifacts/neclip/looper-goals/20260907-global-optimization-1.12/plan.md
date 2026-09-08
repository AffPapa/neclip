# NeClip 1.12 — глобальный цикл оптимизации

## Цель

Сделать NeClip незаметным, быстрым и понятным локальным помощником: убрать подтверждённую сложность, ускорить частые пути и подготовить новую локальную сборку без потери истории, миграций, приватности, хоткеев и надёжной вставки.

## Профессиональные треки

1. Product research: 15–20 clipboard/keyboard utilities, только первичные источники; выход — матрица keep/simplify/remove/defer и top-10 рекомендаций.
2. Swift/macOS architecture: call graph, dead code, dependencies, binary/startup/menu paths, измеренный P0/P1-план без исходных изменений на этапе аудита.
3. Release/QA/security: тесты, санитайзеры, plist/signing/archive, размеры, секреты и раздельная проверка public/installed/candidate.

## Scope

- P0: видимые поломки, некорректные состояния, ошибки вставки/сохранения, нарушение privacy или release safety.
- P1: доказанные локальные ускорения и сокращения, улучшающие частые пути и не меняющие контракт данных.
- P2: идеи интерфейса/исследований без измеренного выигрыша; только зафиксировать в backlog.

## Защищено

Не удалять и не переписывать без отдельного доказательства: миграции БД, исключения приватных приложений, обработку хоткеев, историю/сниппеты, rollback-материалы, секреты, публичную 1.10.0 и `/Applications/NeClip.app`.

## Ворота

1. Три независимых read-only аудита завершены и сохранены в `docs/`.
2. Для каждого патча есть причина → изменение → тест → измерение до/после.
3. Debug/strict release Swift 6, доступные ASan/TSan, plist/json/diff checks и secret scan зелёные либо blocker явно записан.
4. Candidate собирается отдельно; public/installed не меняются до отдельного release-gate.
5. Обновлены `docs/PROJECT-MAP.md`, changelog и аудит 1.12; размер/скорость не заявляются без повторяемого измерения.

## Stop guards

- Не добиваться процента уменьшения ценой удаления safeguards/tests.
- Не публиковать, не устанавливать и не заменять приложение в этом цикле без отдельного явного release-gate.
- При повреждённом toolchain фиксировать blocker и не маскировать его «успешной» сборкой.

## Current result

- Research audit: complete — 21 products and 40 candidate improvements in
  `docs/RESEARCH-GLOBAL-1.12-2026-09-07-research.md`.
- Release/QA audit: complete — tests and sanitizers green; publication blocked
  until `gitleaks`, signing and notarization gates are available.
- Implemented P1: one folder-title index per menu projection in
  `StatusBarController.swift`; no data or UI contract changes.
- Candidate is now `1.12.0` / build `19`; public `1.10.0` and installed app are
  unchanged.
