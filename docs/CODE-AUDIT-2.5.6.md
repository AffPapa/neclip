# NeClip 2.5.6 — code, product and release audit

Дата аудита: 11 сентября 2026 года. Candidate: 2.5.6/build 35. Публичная
версия на момент начала прохода: 2.5.5/build 34. Этот документ не является
доказательством публикации; итоговые подпись, notarization, CI и live-ссылки
фиксируются отдельно в `RELEASE-2.5.6-STATUS.md`.

## Результат по приоритетам

| Приоритет | Доказательство | Причина | Изменение | Проверка |
|---|---|---|---|---|
| P0 | fallback выбирал единственный `SCDisplay`, но post-capture guard сравнивал `NSScreen` со старым ID | восстановление после смены Space/дисплея было внутренне противоречивым | `ScreenshotDisplayPolicy` возвращает фактически выбранный ID; тот же ID используется при capture и финальной проверке | четыре policy-сценария + 22 screenshot tests |
| P0 | area crop на Retina/смешанных дисплеях мог использовать несовпадающие overlay/source coordinates | `NSScreen.frame` и `SCContentFilter.contentRect` не обязаны совпадать | нормализованное отображение выбора в source geometry, независимые X/Y scales и ориентация canvas | geometry, negative-origin, Retina и top-left regression tests |
| P0 | canvas мог отдавать drag окну, а transient WindowServer error завершал сценарий | movable-by-background и одноразовый content query | canvas принимает drag; shareable content имеет один ограниченный fallback; permission message отделён от transient error | native editor contract + full suite + TSan/ASan |
| P1 | текст мог остаться незакоммиченным при потере фокуса, цвет не принадлежал конкретной пометке | text field завершался только по клавише, renderer имел один цвет | idempotent commit/cancel при resign; цвет хранится в `ScreenshotAnnotation` | flattened text export и per-annotation color tests |
| P1 | live editor показывал «Жёлтый» при красном цвете первого штриха | AppKit popup selection расходился с `canvas.annotationColor` после построения toolbar | после layout popup синхронизируется из единственного источника истины canvas | native editor test проверяет selected title; повторный live QA |
| P0 | popup показывал выбранный синий, но новая shape оставалась красной | draft создавался с default color вместо `canvas.annotationColor` | shape получает текущий цвет явно; text фиксирует цвет в момент начала ввода | event-level canvas test для drag и focus-loss commit |
| P1 | локальные docs утверждали 2.5.6, а public GitHub Release/Pages ещё показывали 2.5.5 | ветка release-candidate не была слита/опубликована | публикация остаётся закрыта до exact-commit build, required CI и cache-busted live check | `gh pr checks`, Release API, public `version.json`, checksum |

## Карта владельцев и границ

| Область | Владелец | Данные/побочные эффекты | Actor/поток | Основные тесты | Решение |
|---|---|---|---|---|---|
| запуск и окна | `AppDelegate`, `RuntimeIdentity` | жизненный цикл, QA isolation | main actor | application-mode, onboarding | оставить |
| clipboard capture | `ClipboardMonitor`, `ClipboardAccess`, `SensitiveContentPolicy`, `ClipboardWriteGuard` | pasteboard, privacy gates, capture queue | serial queue + bounded sendable bridge | capture/privacy/interaction | оставить |
| база и миграции | `Storage` | локальная SQLite, history/snippets/folders | GRDB queue; UI не блокируется | storage, real-copy migration, undo | оставить; старые миграции совместимы |
| меню | `StatusBarController`, `MenuPresentation`, `MenuRefreshState` | bounded summaries, selective refresh | main actor + async snapshots | menu contract/work/latency | оставить; один history feed |
| сниппеты | `SnippetsEditor`, `SnippetRenderer` | drafts, folders, import/export | main actor + storage queue | editor/transfer/render | оставить |
| вставка | `PasteService`, `SequentialPasteSequence` | pasteboard generation, Accessibility | main actor + locked sequence | paste/sequence | оставить |
| раскладка | `AutoLayoutController`, `LayoutAccessibility`, `LayoutCorrectionCore`, `ApplicationLayoutMemory` | AX selection, input sources, bounded memory | main actor + event tap | layout/CAS/ignore/exclusion | оставить; default-off auto mode |
| клавиши | `HotKeyCoordinator`, `GlobalHotKey`, `ShortcutDescriptor` | Carbon registrations | main actor + callback bridge | conflict/dispatch/persistence | оставить |
| screenshots | `ScreenshotCoordinator`, `ScreenshotDocument`, `ScreenshotEditorWindow` | ScreenCaptureKit, pixels, final PNG/JPEG | main actor; crop/render detached | 22 screenshot regressions | оставить после P0 fix |
| OCR | `OCRService` | on-device Vision text only | serialized background work | payload projection/privacy | оставить, без raw temp files |
| updates | `UpdateChecker` | explicit-only HTTPS manifest | main actor + ephemeral URLSession | manifest/transport/state | оставить |
| settings | `PreferencesWindow`, `PreferencesUXPolicy`, `Settings` | UserDefaults, login item, bookmarks | main actor | persistence/navigation/UX | оставить |

Полный список типов и runtime flow поддерживается в `PROJECT-MAP.md`. Поиск
обращений не нашёл оснований удалять production-типы в этом срезе. Единственный
`fatalError` остаётся fail-closed инициализацией обязательной SQLite; его нельзя
заменять молчаливым in-memory fallback, иначе пользователь увидит пустую историю.
Три `Task.detached` относятся к тяжёлому crop/render/storage-adjacent work и
имеют cancellation/actor handoff; глобального переноса логики с main actor не
требуется.

## 50 кандидатов и выбранные 20

Проверяемый каталог ровно из 50 screenshot/UX-возможностей и первичные ссылки
на 15 macOS-продуктов находится в `RESEARCH-SCREENSHOTS-2026-09-10.md`.
Отобранные там 20 решений проверены повторно против границы «невидимый
помощник»:

- приняты и реализованы: area shortcut, Space-move, Escape, image-first canvas,
  compact toolbar, direct annotations, Copy/Save/Undo/Redo keys, tools 1–5,
  sticky tool, opaque redact, transient feedback, explicit PNG/JPEG, live
  shortcut conflicts, native idle-quiet implementation, privacy-safe latency marks;
- приняты в 2.5.x: full-screen shortcut, bounded Retina downscale, один безопасный
  ScreenCaptureKit fallback;
- отложены: window capture, repeat-area и drag-out — они требуют отдельной
  multi-display/accessibility QA и не должны усложнять основной путь;
- отклонены: cloud, accounts, upload links, gallery, tags/search, AI/OCR для
  screenshots, video, scrolling capture, floating collections and themes.

Таким образом, требование 50 потенциальных улучшений и отбора 20 выполнено без
повторного раздувания backlog. В текущий release входят только доказанные P0 и
минимальный P1.

## Проверки этого прохода

- Final debug, strict Swift 6 release, AddressSanitizer and ThreadSanitizer:
  каждый прогон — 276 XCTest, 4 ожидаемых opt-in skip, 3 Swift Testing, 0 ошибок.
- Targeted screenshot suite после P0/color fixes: 23/23.
- Первый параллельный четырёхпроцессный запуск дал два debug и один TSan test
  failure без sanitizer report из-за совместного использования глобальных
  AppKit/pasteboard ресурсов. Это не было скрыто: debug и TSan повторены
  последовательно на тех же binaries и полностью прошли; release gate всегда
  использует последовательный запуск.
- Реальная SQLite: миграционный тест прошёл на disposable online backup; оригинал
  не изменялся, копия удалена сразу после теста.
- Hot paths: menu full median 1.740 ms / p95 2.220 ms; clips 0.681/0.842 ms;
  snippets 0.991/1.389 ms. Эти synthetic numbers не являются launch/capture SLA.
- Secret scan: рабочее дерево, полная история и side refs clean; detector
  self-tests green. `git fsck` показал недостижимые объекты, но не corruption.
- Synthetic native editor render просмотрен в Aqua и Dark Aqua; compact controls
  и accessibility labels присутствуют.

## Ограничения доказательства

- Live Screen Recording capture and multi-display pointer routing require the
  final installed signed candidate and remain release smoke. Isolated live QA
  подтвердил стартовый красный выбор и синюю рамку после смены palette; focus
  commit дополнительно подтверждён event-level native test.
- Cold launch and real capture latency cannot be honestly inferred from unit
  benchmarks; latency stages are content-free and проверяются на installed app.
- Public 2.5.6 is not proven until PR, required CodeQL Swift job, GitHub Release,
  Pages manifest and independently downloaded checksum all agree.
