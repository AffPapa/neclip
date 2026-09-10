# NeClip 2.4.0 / build 28 — release evidence

Дата: 10 сентября 2026. Артефакт собран из exact source commit
`100de028d734403e8d55b856308bf0af7f9a8d8e` (arm64, macOS 14+).

## Изменения

- Сравнены 15 macOS screenshot‑решений и 50 функций; 20 решений отобраны для
  минималистичного локального сценария. Полная матрица: `RESEARCH-SCREENSHOTS-2026-09-10.md`.
- В overlay Space перемещает выделенную область, рядом показываются размеры.
- Текст вводится прямо на canvas, без `NSAlert`; `1…5` выбирают инструмент.
- ScreenCaptureKit fail‑closed, если pending overlay нельзя исключить; crop
  рисуется сразу в целевой буфер, уменьшая пик памяти.
- Latency marks записывают только названия этапов — без пикселей, буфера,
  путей и имён приложений.

## Release gate

- 259 XCTest, 4 ожидаемых skip, 0 failures; 3 Swift Testing.
- Strict Swift 6 release, complete concurrency, warnings-as-errors — PASS.
- Developer ID и notarization приложения — Accepted:
  `af76ca4a-8422-43ea-b9f7-bae537a408d5`.
- Notarization DMG — Accepted:
  `52122dab-c126-4168-bf12-2527037fa95e`.
- Stapling, Gatekeeper и проверка приложения внутри смонтированного DMG — PASS.
- DMG: 2,039,235 bytes; SHA-256:
  `b56abc1823f190c078f4fc935fe38dc607a7e58ff7597c26bf5a9373c2599d07`.

GitHub Release v2.4.0 публикуется immutable после обязательных checks PR #26.
Установку локальной копии выполняет release-скрипт с rollback; пользовательские
данные и предыдущая версия не удаляются.
