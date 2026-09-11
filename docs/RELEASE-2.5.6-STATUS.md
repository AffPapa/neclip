# NeClip 2.5.6 / build 35

Исправлен последний дефект захвата области: ScreenCaptureKit теперь получает
явный `sourceRect` и масштабирует весь источник в выходной canvas. Это исключает
пустые поля и захват смещённой части экрана на Retina, масштабированных и
смешанных дисплеях.

Проверки: 271 XCTest (4 ожидаемых skip), 3 Swift Testing; Swift 6 strict,
Developer ID, notarization, stapling, Gatekeeper и DMG validation — успешно.

Артефакт: `NeClip-2.5.6.dmg`, 2,042,819 bytes.
SHA-256: `9cb82ddbbc398ffc3b0b77957380a79043c87433d9a1c99e9451f14e1424bf7b`.
Исходный коммит: `b90df7e40d9a83dd6940daa528d2e2b21a2920db`.
