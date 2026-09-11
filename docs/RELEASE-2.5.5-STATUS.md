# NeClip 2.5.5 / build 34 — release evidence

Дата: 11 сентября 2026. Исправление посвящено пустым полям и неверному crop
после выделения области на Retina и смешанных дисплеях.

## Исправление

Рамка выделения рисуется в координатах `NSScreen.frame`, а ScreenCaptureKit
может вернуть другой `contentRect` в масштабированном или multi-display режиме.
Теперь crop сначала переводит выделение по нормализованным координатам в
фактический `contentRect`, затем выполняет точное пиксельное вырезание. Старый
путь сохранён как совместимый shortcut, когда обе геометрии совпадают.

## Проверки

- Полный Swift suite: 271 XCTest, 4 ожидаемых пропуска, 0 ошибок; 3 Swift
  Testing, 0 ошибок.
- Targeted Screenshot tests: 18/18 успешно, включая разную geometry overlay/source.
- Strict Swift 6 release build, Developer ID, notarization, stapling, Gatekeeper
  и mounted-DMG: успешно.
- App notarization ID: `51a43f3e-56b7-4a68-84b0-6d957eac6898`.
- DMG notarization ID: `611575fa-7156-401c-8f2e-be51ddbc5d7b`.

## Артефакт

- DMG: `NeClip-2.5.5.dmg`
- Размер: 2,042,819 bytes
- SHA-256: `a830c92e4bbdb646f05ab96c001ae6388a686f1f2e43cc563e6ea3d9bc930319`
- Исходный коммит сборки: `1eaaf0d31f046ce44f9ee7852951e0b37b005fd4`
