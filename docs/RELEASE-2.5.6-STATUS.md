# NeClip 2.5.6 / build 35

Исправлен последний дефект захвата области: ScreenCaptureKit теперь получает
явный `sourceRect` и масштабирует весь источник в выходной canvas. Это исключает
пустые поля и захват смещённой части экрана на Retina, масштабированных и
смешанных дисплеях.

Проверки: 271 XCTest (4 ожидаемых skip), 3 Swift Testing; Swift 6 strict,
Developer ID, notarization, stapling, Gatekeeper и DMG validation — успешно.

Артефакт: `NeClip-2.5.6.dmg`, 2,042,819 bytes.
SHA-256: `ce3fc035ef63a6f0e7948378b68e613344e6f8063a3e0f0f6e42b529b360c4d7`.
Исходный коммит: `58b6e0f09c8b54d6b0bcf402faff72b877920425`.
