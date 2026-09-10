# NeClip 2.5.2 / build 31 — release evidence

Дата: 10 сентября 2026. Релиз собран из исходного коммита
`ec88c2cdcd98852431681dcf2ff7937b5b4dd5f3` (arm64, macOS 14+).

## Что исправлено

- `Storage.appendToLatestUnpinnedText` теперь выбирает только незакреплённую
  запись. Закреплённая история не меняется при операции «следующий текст».
- `Storage.trim` перечитывает фактический размер после удаления по количеству;
  совместное превышение лимитов больше не удаляет дополнительную свежую запись.
- `PreferencesWindow` не запускает проверку обновлений при каждом открытии.
  Сеть используется только после явного действия пользователя.
- `AutoLayoutEventMonitor` удерживает себя до удаления event tap, исключая
  гонку времени жизни между остановкой и callback.
- Контракт полноэкранного Retina-захвата закреплён тестом: `scalesToFit` и
  `preservesAspectRatio` сохраняют весь кадр, а не только верхний левый фрагмент.

## Проверки

- Полный `swift test --disable-sandbox`: 267 XCTest, 4 ожидаемых пропуска,
  0 ошибок; Swift Testing: 3 теста, 0 ошибок.
- Release-сборка Swift 6 с complete concurrency и warnings-as-errors: успешно.
- Бинарь arm64, production-артефакт stripped; размер DMG — 2,042,307 bytes.
- Developer ID подпись, Apple notarization приложения и DMG, stapling,
  `codesign`, `spctl` и проверка приложения из смонтированного DMG: успешно.
- Локальная проверка утечек Gitleaks по рабочему дереву и истории: утечек не
  найдено. `git fsck --full`, `git diff --check`, JSON и site coherence: успешно.

## Артефакт

- DMG: `NeClip-2.5.2.dmg`
- SHA-256: `bff1bc4c44072e8b4e1bd8fdf8ab5c13c69bcdfb6c01dfaf3ace4ae796432751`
- Источник: `ec88c2cdcd98852431681dcf2ff7937b5b4dd5f3`
- Notary IDs: app `fd085bef-5d72-47c3-a15b-3c6a2e25ab9b`, DMG
  `015fdb8e-e578-415b-8349-b5b90b00b910` (оба Accepted).

Публичная публикация и тег выполняются только после прохождения обязательных
GitHub checks на PR; обход проверок не используется.
