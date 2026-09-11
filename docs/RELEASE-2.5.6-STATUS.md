# NeClip 2.5.6 / build 35

Исправлен последний дефект захвата области: ScreenCaptureKit теперь получает
явный `sourceRect` и масштабирует весь источник в выходной canvas. Это исключает
пустые поля и захват смещённой части экрана на Retina, масштабированных и
смешанных дисплеях.

Проверки: 271 XCTest (4 ожидаемых skip), 3 Swift Testing; Swift 6 strict,
Developer ID, notarization, stapling, Gatekeeper и DMG validation — успешно.

Артефакт: `NeClip-2.5.6.dmg`, 2,042,819 bytes.
SHA-256: `e064da458e7087305cabb51ca9cc309246dd8d00c8a0d5a6479a854cd59405eb`.
Исходный коммит: `51e32b878bc06b63f84a34db79c2cb3a0d06db57`.
