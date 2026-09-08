# NeClip 1.12.0 — code and hot-path audit

Дата: 7 сентября 2026. Ветка: `codex/neclip-invisible-version`.

## Итог

Измерения не оправдали массовое переписывание или глобальный `-Osize`:
предыдущий эксперимент с глобальной оптимизацией размера уменьшал бинарник,
но давал нестабильную просадку storage/menu reads. Поэтому оставлен только
target-only `-Osize` для NeClip; GRDB остаётся в обычном `-O`.

Безопасный P1-патч 1.12 касается одного горячего пути меню. До патча каждый
snippet без собственного `folderTitle` линейно искал название папки в
`snapshot.folders`. Теперь `appendSnippetFolders` строит один
`[Int64: String]`-индекс на открытие меню и передаёт его в строки. Сложность
проекции меняется с O(snippets × folders) на O(snippets + folders), при этом
порядок, orphan/unfiled fallback, preview, represented IDs и paste action не
изменяются. Миграции, privacy, hotkeys, history и legacy pin metadata не
трогались.

## Размер и состав

- `Sources/NeClip`: 10 693 строк Swift по текущему дереву; largest files остаются
  `Storage.swift`, `PreferencesWindow.swift`, `StatusBarController.swift` и
  `SnippetsEditor.swift`.
- Release executable после обычной release-сборки: 8 536 264 байта до strip;
  временная stripped-копия candidate: 4 329 816 байт. Это не размер
  поставляемого DMG. Предыдущий release pipeline сохраняет UUID-
  matched dSYM, strip-ит приложение и только затем подписывает артефакт.
- Новая зависимость не добавлялась; GRDB закреплён на 7.11.1.

## Проверки после патча

- `swift test --disable-sandbox`: 260 XCTest, 4 opt-in skip, 0 failures + 4
  Swift Testing checks.
- `swift test --disable-sandbox -c release -Xswiftc -strict-concurrency=complete
  -Xswiftc -warnings-as-errors`: тот же зелёный результат.
- `swift test --disable-sandbox --sanitize=address`: зелёный результат.
- `swift test --disable-sandbox --sanitize=thread`: зелёный результат.
- Opt-in hot-path benchmark: меню `menu-full` median 1.253625 ms / p95
  1.327958 ms; это baseline для нового candidate, а не рекламное обещание
  ускорения GUI.
- `git diff --check`: PASS.

## Что сознательно не удалено

Старые search/keyword SQL-миграции остаются только для безопасного обновления
старых баз; runtime/UI search уже retired. Legacy protected pins остаются
доступными для явного unpin, чтобы не потерять пользовательские данные.
Privacy exclusions, automatic-layout safety boundaries, undo guards, storage
transactions и release scripts не являются «мусором» и не сокращались по
числу строк.

## Следующий gate

Перед публикацией нужен отдельный clean-tree release gate: установить/указать
`gitleaks` и просканировать всю историю, повторить site/JSON checks, подписать,
notarize, staple, проверить Gatekeeper и mounted DMG. До этого 1.12.0 — только
локальный candidate; публичная 1.10.0 и `/Applications/NeClip.app` не менялись.
