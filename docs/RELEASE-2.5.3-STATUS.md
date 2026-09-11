# NeClip 2.5.3 / build 32 — release evidence

Дата: 11 сентября 2026. Исправление посвящено неполному или увеличенному
скриншоту на Retina и внешних дисплеях.

## Исправление

`ScreenshotCoordinator` получает физические размеры выбранного дисплея через
`CGDisplayPixelsWide/High`. Логические размеры `SCContentFilter` используются
только если CoreGraphics не вернул валидные пиксели. Благодаря этому
`SCStreamConfiguration` получает правильный исходный aspect ratio; сохранены
`scalesToFit`, `preservesAspectRatio`, лимит 32 Мп и безопасное сопоставление
координат области.

## Проверки

- Полный Swift suite: 268 XCTest, 4 ожидаемых пропуска, 0 ошибок; 3 Swift
  Testing, 0 ошибок.
- Strict Swift 6 release build с complete concurrency и warnings-as-errors:
  успешно.
- arm64 Developer ID, Apple notarization приложения и DMG, stapling, Gatekeeper
  и mounted-DMG: успешно.
- App notarization ID: `5c5da505-c305-46c0-82bd-369d650ea9e7`.
- DMG notarization ID: `5b5e3813-55c7-4230-bef6-79f1eb0e58e0`.

## Артефакт

- DMG: `NeClip-2.5.3.dmg`
- Размер: 2,042,306 bytes
- SHA-256: `b950b17a35d942a4eb8a34e375642d0ad86a6757a1b405b5d588464c528c5bcd`
- Исходный коммит сборки: `75d7dba06c5d354d4b00be9004b6316873939461`

Публикация GitHub выполняется после обязательных checks; обход CI не используется.
