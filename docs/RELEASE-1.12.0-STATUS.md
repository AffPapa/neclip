# NeClip 1.12.0 / build 19 — release status

Дата выпуска: 8 сентября 2026. Commit: `f0363c6561a9e59ba51f90490affd35e6a5d386e`.

## Публичный артефакт

- GitHub Release: `v1.12.0`
- DMG: `NeClip-1.12.0.dmg`
- Размер: 1,990,083 байта
- SHA-256: `5b920cfd499446b4ded5a3e38fcc0c8ca5dcfd15544f207dde2249b848c7761e`
- Архитектура: arm64, macOS 14+
- Notary submissions: application `f81a94b3-a06d-4936-b8a6-3965ecd5d3a0`,
  DMG `f1d8bbff-beee-45bd-a515-5b15744f3c79`; оба `Accepted`.

## Что изменилось

- Построение меню сниппетов один раз индексирует названия папок вместо
  повторного линейного поиска для каждой строки.
- Упрощённая menu-bar-first модель сохранена: нет поиска, ключей сниппетов,
  аккаунтов, облака, AI, плагинов и телеметрии.
- Миграции БД, privacy exclusions, hotkeys, manual-first correction и legacy
  data safety не удалялись.

## Release gate

- `swift test --disable-sandbox`: 260 XCTest, 4 opt-in skip, 0 failures;
  4 Swift Testing проверки прошли.
- Strict Swift 6 release build/test: PASS.
- ASan и TSan: PASS.
- gitleaks: publishable tree, 65 HEAD commits и 1 side-ref-only commit —
  `no leaks found`.
- `plutil`, JSON metadata и `git diff --check`: PASS.
- Developer ID signing, notarization, stapling, `codesign`, `spctl`, mounted
  DMG verification и SHA-256: PASS.
- Rollback: предыдущий immutable `1.10.0` сохранён в `dist/releases`; ранее
  установленное `/Applications/NeClip.app` этим выпуском не заменялось.

## Ограничения

Публичный релиз не изменяет пользовательскую базу автоматически. Перед
обновлением рекомендуется сохранить локальную копию базы и экспорт
сниппетов; обновление выполняется пользователем из GitHub DMG.
