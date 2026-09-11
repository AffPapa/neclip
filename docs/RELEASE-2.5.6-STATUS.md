# NeClip 2.5.6 / build 35 — release candidate

Исправлен последний дефект захвата области: ScreenCaptureKit теперь получает
явный `sourceRect` и масштабирует весь источник в выходной canvas. Это исключает
пустые поля и захват смещённой части экрана на Retina, масштабированных и
смешанных дисплеях.

Проверки: 271 XCTest (4 ожидаемых skip), 3 Swift Testing; Swift 6 strict,
Developer ID, notarization, stapling, Gatekeeper и DMG validation — успешно.

Артефакт: `NeClip-2.5.6.dmg`, 2,042,819 bytes.
SHA-256: `ac8c49d135c9604d2f5c2578872cdca9b5fb006eb91a7d7e75188a7ea87af5ce`.
Последующий audit добавил корректное annotation-drag поведение, idempotent
commit текста, per-annotation palette и один retry transient WindowServer
ошибки. Найден и исправлен P0-дефект fallback: после выбора единственного
доступного `SCDisplay` финальная проверка больше не использует устаревший ID.

Старый артефакт из commit `71c6716a8e0b624c2f122ac54bb6fbd95991d0e0`
не является финальным артефактом этого candidate. Новый exact-commit DMG,
checksum, notarization IDs, установка и public live evidence должны быть
добавлены только после повторного release-gate.
