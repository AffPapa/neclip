# NeClip 2.5.6 / build 35 — release evidence

Исправлен последний дефект захвата области: ScreenCaptureKit теперь получает
явный `sourceRect` и масштабирует весь источник в выходной canvas. Это исключает
пустые поля и захват смещённой части экрана на Retina, масштабированных и
смешанных дисплеях.

Проверки: 276 XCTest (4 ожидаемых opt-in skip) и 3 Swift Testing в каждом
последовательном debug, strict Swift 6 release, AddressSanitizer и
ThreadSanitizer прогоне; Developer ID, notarization, stapling, Gatekeeper и
mounted-DMG validation — успешно.

Финальный source commit:
`61618d03ed266cc764c08fb23bc00de25c3003fb`.

Артефакт: `NeClip-2.5.6.dmg`, 2,048,962 bytes.
SHA-256: `340f6992bf8d2cae108dff66fafe308fbc74be81485d146682ab5f9745d4c3eb`.
App notarization: `0c918ef8-2b6d-4609-9a08-ec13df50e5cf`.
DMG notarization: `0b13e563-6e6d-4277-adb3-9917985d4308`.
Последующий audit добавил корректное annotation-drag поведение, idempotent
commit текста, per-annotation palette и один retry transient WindowServer
ошибки. Найден и исправлен P0-дефект fallback: после выбора единственного
доступного `SCDisplay` финальная проверка больше не использует устаревший ID.

Старый артефакт из commit `71c6716a8e0b624c2f122ac54bb6fbd95991d0e0`
и промежуточный notarized build из `fae266d` не являются финальными и не
публиковались. Exact-commit app установлен в `/Applications/NeClip.app` после
резервной копии в `~/Library/Application Support/NeClip/Backups/20260911T1640-fae266d`;
codesign strict и Gatekeeper дают accepted / Notarized Developer ID. SQLite
production-базы прошла `integrity_check` и `foreign_key_check`.

Изолированный live QA подтвердил корректный начальный красный цвет и реально
синюю рамку после выбора `Синий`. Production hotkey smoke через UI automation
не показал наблюдаемый overlay, поэтому реальный production capture не считается
полностью подтверждённым этим проходом. Публикация считается доказанной только
после green required checks, GitHub Release, cache-busted Pages manifest и
независимого скачивания с совпавшим checksum; итог этих шагов фиксируется ниже.

## Public verification

- Required CI: pending final branch push.
- GitHub Release `v2.5.6`: pending required CI.
- Pages manifest and anonymous checksum: pending release and merge.
