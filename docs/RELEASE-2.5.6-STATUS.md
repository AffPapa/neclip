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

- Required CI for final PR head `8729dd44fe61d160cb1943c7e237b4f8ce06b70f`:
  Swift 6 CI twice, full-history secret scan twice, CodeQL Swift/actions/ruby
  and the repository CodeQL gate — all green.
- GitHub Release `v2.5.6` published at `2026-09-11T10:21:35Z`, not draft or
  prerelease, targeting exact artifact source commit
  `61618d03ed266cc764c08fb23bc00de25c3003fb`.
- Release API reports the DMG asset as 2,048,962 bytes with digest
  `sha256:340f6992bf8d2cae108dff66fafe308fbc74be81485d146682ab5f9745d4c3eb`.
- Anonymous re-download independently matched that size and SHA-256; Gatekeeper
  accepted the downloaded DMG as Notarized Developer ID.
- PR #32 merged normally without admin bypass as
  `738789498f150284722f2c0225c1d6dfa72e2723` at `2026-09-11T10:50:24Z`.
- GitHub Pages built that exact merge commit successfully. Cache-busted
  `version.json` reports 2.5.6/build 35, the exact release/checksum URLs,
  2,048,962 bytes and the expected SHA-256. The rendered page exposes the
  2.5.6 download and release-evidence link.
- A second post-deploy anonymous download matched the manifest, checksum file
  and asset digest; Gatekeeper again accepted the downloaded DMG.
- Live repeat audit found and corrected stale public copy that still claimed
  271 tests and omitted the fallback/color fixes. That docs-only correction is
  isolated from the already verified app artifact and must pass its own PR CI.
