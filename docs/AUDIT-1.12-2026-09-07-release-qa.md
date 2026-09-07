# NeClip 1.12.0 — release, QA and security audit

Дата: 7 сентября 2026. Проверен локальный worktree
`codex/neclip-invisible-version`, HEAD `c17f354fb2b94d7151802cf1632ee47a0d539e60`.

## Итог

**Статус: RELEASE BLOCKED.** Кандидат в исходниках — `1.12.0` / build `19`;
публичная версия остаётся `1.10.0` / build `17`, установленная копия —
`1.9.1` / build `16`. Исходники, публичная копия и установленная программа
этим аудитом не изменялись.

Полная тестовая матрица доступного toolchain проходит, но release-gate нельзя
закрыть: в системе нет исполняемого `gitleaks`, поэтому проверка дерева и
полной истории не может быть засчитана; установленный `/Applications/NeClip.app`
также имеет недействительную подпись. Нотаризация, подпись кандидата,
установка и публикация не запускались.

## Проверенный baseline

| Область | Команда/результат |
|---|---|
| Debug | `swift test --disable-sandbox`: 260 XCTest, 4 opt-in skip, 0 failures; 4 Swift Testing проверки прошли после оптимизации menu projection |
| Strict release | `swift test --disable-sandbox -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`: 260 XCTest, 4 skip, 0 failures; 4 Swift Testing проверки прошли |
| Address Sanitizer | `swift test --disable-sandbox --sanitize=address`: 260 XCTest, 4 skip, 0 failures; 4 Swift Testing проверки прошли |
| Thread Sanitizer | `swift test --disable-sandbox --sanitize=thread`: 260 XCTest, 4 skip, 0 failures; 4 Swift Testing проверки прошли |
| Strict build | `swift build --disable-sandbox -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`: PASS |
| Architecture | release executable: arm64; `Resources/Info.plist`: `1.11.0`, build `18` |
| Website coherence | `ruby scripts/verify-site.rb`: PASS, public/source JSON and download согласованы на `1.10.0` |
| Metadata | `plutil -lint Resources/Info.plist` and JSON parse of version/project/changelog/backlog: PASS |
| Formatting | `git diff --check`: PASS |

Unstripped SwiftPM release executable в `.build` имеет 9,614,680 bytes. Это
не размер поставляемого приложения: `build-app.sh` отдельно создаёт dSYM,
strip-ит бинарник и только затем подписывает и нотарифицирует артефакты.

## Публичная и установленная копии

- `dist/NeClip.app` и `dist/NeClip-1.10.0.dmg` — публичный локальный релиз
  `1.10.0` / build `17`; SHA-256 DMG:
  `d1f52a358b716a14d1fe60d28870af9a486a7defe6094f6396000c742cee9d1c`.
- В `dist/releases/` сохранены исторические `1.9.1` и `1.10.0`; кандидат
  `1.11.0` туда не добавлялся.
- `/Applications/NeClip.app` сообщает `1.9.1` / build `16`.
- `codesign --verify --deep --strict --verbose=2 /Applications/NeClip.app`
  завершился ошибкой: `invalid signature (code or signature have been
  modified)`; `spctl --assess --type execute` также не смог подтвердить
  приложение. Это существующее локальное состояние, не изменение аудита.

## Секреты и Git

Команда `bash scripts/secret-scan.sh` завершилась с кодом 1 до сканирования:

```
Gitleaks is required. Set GITLEAKS_BIN or install gitleaks.
```

Поэтому утверждение «секретов нет» этим проходом делать нельзя. Ручная
проверка имён tracked-файлов не нашла `.env`, `.p8`, `.pem`, private-key или
credential-файлов; `git grep` не нашёл токенов/ключей в текущем дереве.
Это полезный smoke-check, но не заменяет gitleaks.

Git содержит 63 коммита на HEAD и 1 commit только в side-ref. `git fsck
--full --no-reflogs --unreachable` показывает локальные unreachable commits,
trees и blobs. Это не доказательство утечки, но до публикации должен быть
выполнен предусмотренный `scripts/secret-scan.sh` по HEAD и всем refs после
установки gitleaks; удалять unreachable-объекты в рамках этого read-only
аудита нельзя.

## Release gate

Перед выпуском `1.12.0` необходимо:

1. Установить/указать проверенный `gitleaks` и повторить
   `bash scripts/secret-scan.sh`; сохранить redacted log.
2. Получить чистый reviewed commit: сейчас worktree содержит независимые
   новые audit/plan документы от параллельного цикла, поэтому `build-app.sh`
   корректно отказался бы на clean-tree gate.
3. Повторить strict build/test и `ruby scripts/verify-site.rb` на exact commit.
4. Проверить Developer ID identity, `xcrun notarytool history
   --keychain-profile neclip`, затем подписать, notarize, staple, Gatekeeper
   и mounted-DMG exact-artifact.
5. Только после отдельного подтверждения release-gate обновлять публичный
   `version.json`/GitHub Release; installed `/Applications/NeClip.app` и
   пользовательскую базу в этом аудите не заменялись.

## Ограничения

Нативный UI, paste в сторонние приложения и реальная установка кандидата в
этом аудите не проверялись. Тесты и sanitizer покрывают контрактные и
storage/interaction paths, но не являются доказательством notarization,
Gatekeeper или public deployment.

После исходного read-only среза candidate обновлён до 1.12.0/build 19: menu
projection теперь строит индекс названий папок один раз на открытие меню.
Debug, strict release, ASan и TSan повторены после этого патча; все 260 XCTest,
4 Swift Testing проверки и предусмотренные opt-in skips совпали с baseline.
