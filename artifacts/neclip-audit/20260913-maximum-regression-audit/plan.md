# Plan

1. Проверить архитектуру событий, hotkey registration, layout conversion,
   Accessibility и clipboard transaction boundaries.
2. Проверить UI state machine, menus, search/history/snippets/screenshot flows
   и ошибки разрешений.
3. Проверить тестовое покрытие, concurrency, performance, release scripts,
   secret boundary и installed runtime.
4. Синтезировать findings, исправить P0/P1, добавить regression tests.
5. Прогнать delivery gates и выполнить rollback-safe release/install.
