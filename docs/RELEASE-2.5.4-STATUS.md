# NeClip 2.5.4 / build 33 — release evidence

Дата: 11 сентября 2026. Исправление посвящено мягкому, увеличенному и
обрезанному Retina-просмотру, а также устаревшей версии в настройках.

## Исправления

- Размер кадра ScreenCaptureKit берётся из фактического `contentRect ×
  pointPixelScale`; размеры панели через `CGDisplayPixelsWide/High` не
  подменяют геометрию источника в масштабированных режимах.
- `scalesToFit` выключен для нативного кадра, поэтому ScreenCaptureKit не
  выполняет лишний upscale. Пропорциональный downscale сохраняется только при
  превышении лимита 32 Мп.
- Режим «По размеру» в редакторе учитывает `backingScaleFactor` окна. Retina-
  холст больше не отображается вдвое крупнее и не обрезается снизу/справа.
- Ключ кэша обновлений переведён на новую схему; старый кэш 2.4.0 не может
  маскироваться под актуальную версию.

## Проверки

- Полный Swift suite: 270 XCTest, 4 ожидаемых пропуска, 0 ошибок; 3 Swift
  Testing, 0 ошибок.
- Целевые Screenshot/UpdateState tests: 23/23 успешно.
- Strict Swift 6 release build с complete concurrency и warnings-as-errors:
  успешно.
- arm64 Developer ID, Apple notarization приложения и DMG, stapling, Gatekeeper
  и mounted-DMG: успешно.
- App notarization ID: `bfd408b4-f2e3-4bbb-9c72-8035d0cb0d05`.
- DMG notarization ID: `f5f868cc-61f0-4b36-924a-dd86d1cdd44d`.

## Артефакт

- DMG: `NeClip-2.5.4.dmg`
- Размер: 2,042,306 bytes
- SHA-256: `203a7ab0647599953488bdcfcf8bbbeaaae44fbdfa67ead19123956c3842712d`
- Исходный коммит сборки: `792c985c25849ff943fc59ff4b02479e6ead7de3`

Публикация GitHub выполняется после обязательных checks; обход CI не используется.
