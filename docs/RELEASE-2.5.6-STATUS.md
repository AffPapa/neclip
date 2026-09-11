# NeClip 2.5.6 / build 35

Исправлен последний дефект захвата области: ScreenCaptureKit теперь получает
явный `sourceRect` и масштабирует весь источник в выходной canvas. Это исключает
пустые поля и захват смещённой части экрана на Retina, масштабированных и
смешанных дисплеях.

Проверки: 271 XCTest (4 ожидаемых skip), 3 Swift Testing; Swift 6 strict,
Developer ID, notarization, stapling, Gatekeeper и DMG validation — успешно.

Артефакт: `NeClip-2.5.6.dmg`, 2,042,819 bytes.
SHA-256: `157c0e704a662e84ae667d0bab56329d520764c05e981f570bbac1449531b80a`.
Исходный коммит: `f90743213724f3f6278080d65a7ba32228a04ef8`.
