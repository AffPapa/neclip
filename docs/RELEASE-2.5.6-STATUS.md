# NeClip 2.5.6 / build 35

Исправлен последний дефект захвата области: ScreenCaptureKit теперь получает
явный `sourceRect` и масштабирует весь источник в выходной canvas. Это исключает
пустые поля и захват смещённой части экрана на Retina, масштабированных и
смешанных дисплеях.

Проверки: 271 XCTest (4 ожидаемых skip), 3 Swift Testing; Swift 6 strict,
Developer ID, notarization, stapling, Gatekeeper и DMG validation — успешно.

Артефакт: `NeClip-2.5.6.dmg`, 2,042,819 bytes.
SHA-256: `ac8c49d135c9604d2f5c2578872cdca9b5fb006eb91a7d7e75188a7ea87af5ce`.
Исходный коммит: `71c6716a8e0b624c2f122ac54bb6fbd95991d0e0`.
