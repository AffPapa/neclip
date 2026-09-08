# NeClip 1.12: глобальное исследование clipboard- и keyboard-layout utilities

Дата: 7 сентября 2026 года

Статус: исследовательский документ для нового локального цикла. Это не
утверждение о выпуске 1.12.0 и не замена release-gate.

## Решение в одном абзаце

NeClip не должен догонять Paste, Raycast, Alfred или CopyQ по числу функций.
Их сильная сторона — архив, поиск, автоматизация и интеграции; это другой
продукт. Для NeClip лучше закрепить короткий сценарий: открыть из menu bar или
горячей клавишей, выбрать один из последних элементов или папку сниппетов,
вставить, закрыть. Самые безопасные улучшения — единый нативный projection меню,
стабильный порядок и номера, прямой доступ к папкам, ясный copy-only fallback,
беззвучная обработка ошибок, ограниченные preview и строгие исключения
чувствительных приложений. Поиск, аккаунты, облако, AI, теги, smart lists,
синхронизация, плагины и сложные действия конкурентов в концепцию NeClip не
входят.

## Метод и границы доказательности

Проверены 21 продукт по первичным источникам: официальные сайты, справка,
репозитории, issue/technical pages и страницы Microsoft/Apple. В выборке 14
clipboard-утилит и 7 keyboard-layout/text-correction utilities для macOS,
Windows и кроссплатформенных сценариев. Снимок источников сделан 7 сентября
2026 года.

Наличие функции в чужом продукте не означает, что она полезна NeClip. Слова
«быстрый», «лёгкий», «нативный» и «private» оставлены как заявления авторов;
между приложениями не проводился одинаковый CPU/RAM/latency benchmark. В
особенности нельзя сравнивать размер ZIP, DMG и установленного приложения.
Отзывы и issue используются как источники сценариев и рисков, а не как
статистика распространённости.

Критерии решения:

1. Уменьшает ли функция время от копирования до повторной вставки?
2. Работает ли она локально и без нового аккаунта, облака или разрешения?
3. Уменьшает ли она ошибки и неожиданности в menu-first интерфейсе?
4. Увеличивает ли она код, фоновые операции, поверхность приватности или
   миграционный риск?
5. Можно ли проверить её отдельным тестом и безопасно откатить?

## Сводная матрица

Обозначения: **+** — подтверждено источником, **—** — не заявлено или не
является основной функцией, **лок.** — работает без обязательного облака,
**риск** — дополнительная поверхность приватности/сложности.

| Продукт | ОС | История / меню | Сниппеты | Поиск / организация | Хоткеи / paste | Локальность | Вывод для NeClip |
|---|---|---|---|---|---|---|---|
| Maccy | macOS | + menu bar, компактная история | — | поиск, pin, исключения | Return, Option-Return, `⌘1…9` | лок. по умолчанию | главный референс короткого пути и copy/paste modifier |
| Clipy | macOS | + menu-bar history | + groups/snippets | поиск и группы | keyboard-first | содержимое локально; аналитика заявлена в privacy | брать прямые snippets, не брать лишнюю телеметрию |
| ClipMenu | macOS | + обычное меню и история | + | menu-first | горячее меню | локальная историческая модель | UX-референс простого меню; код/релиз устарели |
| Jumpcut | macOS | + status item/bezel | — | минимум | циклический вызов, Escape | лок. | полезны Escape и минимум состояний |
| Flycut | macOS | + последние текстовые clips | — | простой список | `⌘⇧V` | лок. | текстовый быстрый путь, но не ограничиваться только кодом |
| Pastebot | macOS | + быстрый список, preview | + | коллекции, paste stack | числовой выбор, sequential paste | зависит от версии/настроек | взять числовую навигацию только если она не удлиняет меню |
| Paste | macOS/iOS | + визуальный архив | + placeholders | поиск, pinboards, sync | rich/plain paste | iCloud/подписка | не переносить архивную модель и облако |
| PasteNow | macOS/iOS | + smart lists, preview | не основной акцент | rules/conditions | custom shortcuts | iCloud | исключения полезны; smart lists избыточны |
| Pasta | macOS | + local-first command menu | + placeholders | поиск и commands | keyboard command mode | local-first, optional iCloud | placeholders имеют пользу; command mode для NeClip слишком широк |
| CopyLess 2 | macOS | + history + preview | + | много настроек | direct paste helper | лок. | подтверждает ценность direct paste и preview |
| Alfred Clipboard | macOS | + clipboard viewer | + expansion | сроки хранения, поиск | custom hotkey | лок. по умолчанию | брать явные сроки retention и `{date}/{clipboard}` модель |
| Raycast Clipboard | macOS/Windows | + history | + snippets | поиск, rename, filters | action panel, plain paste | часть функций/интеграций сетевые | брать понятные действия выбранной записи; не брать launcher/AI |
| CopyQ | macOS/Win/Linux | + tray, tabs | через tabs/commands | фильтры, tags, notes | programmable shortcuts | лок. | подтверждает edit, но tabs/scripts не для минимального продукта |
| Ditto | Windows | + tray/history | templates | search, stats, backup | `Ctrl+`` и Enter | без login/cloud/telemetry по docs | privacy boundary и прямой paste — хорошие ориентиры |
| ClipboardFusion | Windows/macOS | + manager | macros | pin/sync/search | hotkeys/triggers | sync/account optional | macros/triggers слишком велики для NeClip |
| Windows Clipboard | Windows | + `Win+V` | pin | 25 items, no deep archive | system shortcut | sync optional account | короткая история и ясный system entry point |
| PowerToys Advanced Paste | Windows | + advanced paste panel | — | format actions | `Win+Shift+V` | non-AI local; AI optional | plain/Markdown/JSON transform можно рассматривать позже |
| Punto Switcher | macOS/Windows | не clipboard-first | snippets/autocorrect | словари/автоматические правила | auto + conversion | input monitoring | auto-correction риск ложных срабатываний; manual first |
| Caramba Switcher | macOS/Windows | не clipboard-first | — | language rules | auto, selection, Double Shift | input monitoring | selected-text conversion и reversible action полезны |
| Mahou | Windows | не clipboard-first | snippets | language pairs, cycle mode | word/line/selection/CapsLock | лок. | отдельные hotkeys и selection conversion подтверждены |
| RSwitcher | Windows | не clipboard-first | — | learned exceptions | force/undo configurable | local/no cloud/no telemetry | undo + learned exceptions, только bounded in-memory |
| UASwitcher | macOS | menu-bar utility | — | — | tap/two-key trigger, auto optional | local/open source | по-кнопочный режим и clipboard-free conversion |
| Cwitcher | Windows | tray utility | — | — | customizable | лок. | version link and explicit exit/settings discoverability |

## Что конкретно подтверждено по clipboard-продуктам

### 1. Maccy: компактность и клавиатура

Официальный README описывает menu-bar entry, `Shift-Command-C`, Return для
выбора, Option-Return для paste и Option-Shift-Return для plain paste, удаление
и pin. Он также документирует исключение transient/password-manager pasteboard
types и Accessibility как условие автоматической вставки. Это сильный базовый
сценарий: одна точка входа, один список, одна команда выбора.

Источники:

- https://github.com/kymokleo/maccy
- https://maccyapp.com/

Для NeClip: сохранить modifier-логику только там, где она видима в меню и
не меняет смысл обычного Return; не добавлять полноценный fuzzy-search, если
продукт сознательно отказался от поиска.

### 2. Clipy и ClipMenu: папки и menu-first модель

Clipy подтверждает, что отдельные группы сниппетов рядом с clipboard history
остаются понятным сценарием. ClipMenu — исторический ориентир меню со списком
истории и сниппетов. Clipy README одновременно показывает важный риск: privacy
policy и внешние сервисы следует проверять отдельно, даже если содержимое
буфера не уходит на сервер.

Источники:

- https://github.com/clipy/clipy
- https://github.com/Clipy/Clipy/blob/develop/PRIVACY.md
- https://www.clipmenu.com/

Для NeClip: папки сниппетов должны быть видны прямо в menu bar меню; глубина
должна быть максимум один подуровень. Удалять поиск и ключ сниппета
последовательно, включая скрытые фильтры и legacy execution paths.

### 3. Jumpcut и Flycut: минимальные состояния

Jumpcut строит сценарий вокруг истории текста и Escape; Flycut — вокруг
последних скопированных фрагментов и быстрого `⌘⇧V`. Их ценность не в большом
архиве, а в том, что действие легко отменить или повторить.

Источники:

- https://snark.github.io/jumpcut/
- https://github.com/TermiT/Flycut

Для NeClip: сохранить Escape/close как безусловный выход из меню, убрать
малоиспользуемые режимы, которые создают дополнительное состояние (например,
отдельные «действия с верхним элементом»).

### 4. Pastebot, Paste, PasteNow и Pasta: полезные, но дорогие расширения

Эти приложения показывают, что пользователи ценят preview, последовательную
вставку, placeholders и повторное использование snippets. Одновременно они
вводят pinboards, smart lists, импорт/экспорт, долгий архив, iCloud, команды,
filters и AI-интеграции. Эти функции оправданы в архивном productivity suite,
но не в невидимом локальном помощнике.

Источники:

- https://tapbots.com/pastebot/
- https://pasteapp.io/
- https://pastenow.app/
- https://www.pasta-app.com/

Для NeClip: оставить небольшие bounded placeholders (`date`, `time`,
`clipboard`) и preview только для выбранного элемента. Не добавлять iCloud,
smart collections, AI, sync или ежегодный архив.

### 5. Alfred и Raycast: сильные действия, но слишком широкая оболочка

Alfred документирует retention 24 часа/7 дней/1 месяц/3 месяца, viewer,
сохранение записи в snippet через `Cmd-S`, `{clipboard:N}` и expansion.
Raycast документирует plain paste, rename, edit, pin, delete, фильтрацию типов
и action panel. Это хорошие примеры локальных действий над выбранным элементом,
но их launcher/search-first модель расходится с решением NeClip отказаться от
поиска.

Источники:

- https://www.alfredapp.com/help/features/clipboard/
- https://www.alfredapp.com/help/features/snippets/
- https://www.alfredapp.com/help/features/clipboard/accessing-clipboard-history/
- https://manual.raycast.com/clipboard-history
- https://manual.raycast.com/snippets

Для NeClip: retention должен быть одним логичным контролом с заранее понятными
значениями, а inspector выбранного clip — единственным местом редактирования,
просмотра и «сохранить как сниппет». Не размножать action panel.

### 6. CopyQ, Ditto и ClipboardFusion: границы конфигурируемости

CopyQ подтверждает ценность редактирования, tabs, drag-and-drop, notes и
custom shortcuts, но его scripting API и tabs создают отдельный power-user
продукт. Ditto предлагает прямой tray → список → paste путь без login/cloud/
telemetry. ClipboardFusion расширяет менеджер macros, triggers, sync и C#.

Источники:

- https://github.com/hluk/CopyQ
- https://github.com/hluk/CopyQ/blob/master/docs/basic-usage.rst
- https://ditto-cp.sourceforge.io/
- https://www.clipboardfusion.com/Features/

Для NeClip: заимствовать privacy boundary Ditto и понятный edit path CopyQ;
не добавлять tabs, scripts, macros, triggers, sync и stats. Внутренний API
должен оставаться узким и тестируемым.

### 7. Windows Clipboard и PowerToys: полезность ограниченного меню

Microsoft документирует `Win+V`, pin, 25 незакреплённых записей, ограничение
4 MB на элемент и отдельную account-bound sync. PowerToys Advanced Paste
документирует plain text, Markdown, JSON, файлы и local OCR; AI является
опциональным и может быть cloud/local.

Источники:

- https://support.microsoft.com/en-us/windows/apps/using-the-clipboard
- https://learn.microsoft.com/en-us/windows/powertoys/advanced-paste
- https://github.com/microsoft/PowerToys/blob/main/.github/skills/powertoys-verification/references/modules/advanced-paste.md

Для NeClip: короткий bounded history и plain-text fallback достаточно полезны.
Форматные преобразования и OCR должны быть отдельной future-веткой только при
доказанном сценарии, а не скрытой фоновой обработкой.

## Что конкретно подтверждено по авто-переключению раскладки

### Manual-first против auto-every-keystroke

Punto, Caramba и часть Windows-решений читают поток ввода и пытаются угадать
язык слова. Это даёт удобство, но требует Input Monitoring и допускает
ложные срабатывания. Mahou и UASwitcher хорошо показывают более безопасную
модель: пользователь явно исправляет последнее слово/строку/выделение
горячей клавишей. Для NeClip основной путь должен оставаться manual-first,
автоматический режим — отдельный opt-in, off by default, с исключениями и
undo.

### Hotkeys, selection и undo

Mahou прямо документирует отдельные hotkeys для последнего слова, строки,
выделения и переключения CapsLock, а также customisation. Caramba указывает
Double Shift для выделенного текста. RSwitcher документирует force/undo hotkeys,
learned exceptions и bounded adaptive confidence. UASwitcher заявляет
clipboard-free conversion и конфигурируемый single/two-key trigger.

Источники:

- https://github.com/iamkarlson/Mahou
- https://apps.apple.com/ca/app/caramba-switcher-typing-tool/id1565826179?mt=12
- https://caramba-switcher.com/
- https://github.com/andrewchuev/rswitcher
- https://github.com/deimoc/UASwitcher
- https://github.com/Astrent-bear/Cwitcher

Для NeClip: оставить две независимые переназначаемые команды — «исправить
выделение» и «включить/выключить автоисправление» — с записью комбинации,
конфликтом и восстановлением по умолчанию. Не добавлять словари и сложные
adaptive profiles до отдельного измерения false-positive/false-negative.

### Системная таблица раскладки вместо словарей

Техническое описание Punto Switcher и реализация NeClip подтверждают общий
принцип: keyboard map лучше строить из системных раскладок, а не зашивать пары
символов в приложение. Для NeClip это уменьшает payload и поддерживает
нестандартные раскладки; словарная классификация остаётся отдельной дорогой
подсистемой.

Источник:

- https://github.com/rshagiev/punto-switcher/blob/main/docs/TECHNICAL_SPEC.md

## Apple HIG: применимые правила, а не декоративный стиль

Apple прямо рекомендует использовать menu bar для команд macOS-приложения,
поддерживать keyboard shortcuts и не перегружать панели. В разделе Menus Apple
рекомендует сначала показывать часто используемые команды, объединять связанные
команды разделителями и ограничивать глубину submenu. В Settings Apple
рекомендует стабильную toolbar-навигацию, panel-specific title, Command-Comma,
отключённые minimize/maximize для settings window и восстановление последней
панели. В Keyboards Apple рекомендует уважать стандартные комбинации и
поддерживать Full Keyboard Access.

Источники:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/
- https://developer.apple.com/design/human-interface-guidelines/menus
- https://developer.apple.com/design/human-interface-guidelines/settings
- https://developer.apple.com/design/human-interface-guidelines/keyboards
- https://developer.apple.com/design/human-interface-guidelines/context-menus

Практический вывод для NeClip:

- menu bar — основная точка входа; Dock не нужен для `LSUIElement` utility;
- первый экран — история и прямые папки сниппетов, а не «управление» и не поиск;
- один уровень submenu допускается для содержимого папки, но не для самой
  категории «Папки сниппетов»;
- команды должны называться глаголом: «Открыть историю», «Вставить»,
  «Скопировать», «Исправить раскладку», «Настройки», «Выйти»;
- редкие действия — в inspector или Settings, а не в основном меню;
- стандартные `⌘,`, `⌘W`, `⌘Q`, Escape и стрелочная навигация не должны быть
  переопределены без необходимости;
- light/dark appearance должен браться из effective system appearance во всех
  entry points, а не дублироваться отдельными стилями.

## 40 возможных улучшений, отсортированных по смыслу

Это backlog исследования, а не разрешение внедрить всё. **P0** — исправляет
поломанный или опасный основной путь. **P1** — небольшая понятность/скорость.
**P2** — только после измерения. **NO** — сознательно не добавлять.

### P0: качество основного действия

1. Единый builder истории для menu-bar и global hotkey.
2. Единый effective appearance для всех окон и меню.
3. Stable absolute indices при pagination.
4. Сохранение порядка при повторной вставке.
5. Escape закрывает меню без изменения буфера.
6. Return вставляет обычным способом.
7. Отдельный Shift/plain-text путь с видимым описанием.
8. Copy-only fallback без Accessibility и без системного beep.
9. Не очищать временный pasteboard при unreadable representation.
10. Проверять frontmost app и откатывать действие при смене фокуса.
11. Не читать secure/concealed pasteboard types.
12. Регистронезависимые исключения password managers.
13. Отдельный opt-in для auto layout correction.
14. Undo auto correction с memory-only ignore list.
15. Atomic create/convert snippet; ошибка не теряет draft.

### P1: минималистичная понятность

16. Папки сниппетов сразу в корне меню.
17. Убрать неиспользуемый search UI, key field и query paths.
18. Убрать implicit «действия с верхним элементом».
19. Убрать новый pin UI, сохранить legacy protected metadata.
20. Показать «Сохранено» только после транзакции.
21. В пустом списке показывать ровно одну следующую команду.
22. Лимит preview в grapheme-safe single line.
23. Полный текст читать только после выбора/inspector.
24. Удержать bounded menu snapshot и lightweight rows.
25. Один retention control вместо разрозненных чисел.
26. Ясно разделить «Хранить» и «Показывать» только если оба действительно
    нужны пользователю.
27. В Settings сгруппировать General, Shortcuts, Privacy, Layout, Version.
28. Показывать текущую версию и «Проверить обновления» без автоматической сети.
29. Одинаковые подписи хоткеев в меню, onboarding и Settings.
30. Видимый reset-to-default рядом с каждой пользовательской комбинацией.

### P2: только с доказательством

31. Plain/Markdown/JSON conversion как отдельное меню выбранного элемента.
32. OCR по требованию для выбранного изображения.
33. Последовательная вставка с bounded stack.
34. Отдельный history item delete в inspector.
35. Экспорт/импорт snippets с versioned schema.
36. Backup перед несовместимой migration.
37. Автоматический benchmark cold/warm open.
38. Instruments signpost для paste, menu snapshot и storage query.
39. Native UI smoke matrix для Notes, TextEdit, Safari, Terminal, Electron.
40. Differential size report для executable, app bundle, DMG и symbols.

### NO: не добавлять в минималистичный NeClip

- аккаунты и регистрация;
- облачная/междуустройственная синхронизация;
- обязательные AI/API ключи и remote transforms;
- launcher, file search и универсальный командный поиск;
- tags, smart lists, collections, stats и tabs;
- macros, scripts, plugins и user code;
- автоматическое OCR/анализ каждого скопированного изображения;
- автоматический layout switch по каждому key event как default;
- сложные словари, adaptive profiles и remote language models;
- Dock icon и полноценное рабочее окно в дополнение к menu bar;
- скрытые «верхние элементы», implicit actions и дублирующие quick lists;
- обязательная телеметрия, crash analytics и network previews.

## Десять рекомендаций для нового локального цикла

| Приоритет | Рекомендация | Почему | Минимальный gate |
|---|---|---|---|
| 1 | Оставить один shared menu projection | устранит расхождение click/hotkey | structural test + light/dark native smoke |
| 2 | Прямые папки в корне | сокращает один уровень и поиск | menu snapshot shows roots and counts |
| 3 | Сохранить stable order/indices | не ломает мышечную память | repeated paste regression |
| 4 | Убрать все остатки search/key | соответствует концепции «здесь и сейчас» | `rg` + compile + menu tests |
| 5 | Сохранить inspector как единственный edit path | яснее создание/редактирование | create-edit-reopen-paste test |
| 6 | Свести retention/preview к bounded политикам | меньше памяти и раздувания UI | migration + large payload tests |
| 7 | Тихий copy-only fallback | не выдаёт beep за ошибку | Accessibility-off native QA |
| 8 | Manual layout correction first | меньше разрешений и false positives | selection conversion matrix |
| 9 | Version pane with explicit check | понятная installed/current state | no-network launch + bounded response |
| 10 | Измерять before/after, не обещать проценты | защищает от ложной оптимизации | 3 paired runs, p50/p95, RSS/size |

## Что должно войти в release gate, а что не должно

До нового локального кандидата разрешены только безопасные изменения, которые
не требуют удаления миграций и не меняют формат действующей базы без проверки.
Каждое изменение должно иметь: причину, узкий diff, тест, обратимую сборку и
проверку основного пользовательского пути.

Обязательные проверки:

- debug и strict release XCTest/Swift Testing;
- ASan и TSan на той же версии исходников;
- `git diff --check`, plist/JSON/site consistency;
- scan текущего дерева и всей Git history на секреты;
- size report для executable/app/DMG, не только «строк кода»;
- native light/dark/menu-bar/editor/settings smoke;
- Accessibility granted/denied и copy-only behavior;
- Notes, TextEdit, Safari/Chromium, Terminal, Electron;
- protected password-manager exclusions;
- clean-room launch с отдельной базой;
- отдельный gate для подписи, notarization, Gatekeeper и публикации.

Не считать доказательством: изменение числа строк, локальный unit test без
взаимодействия с AppKit, размер одного debug binary, рекламное «fast» у
конкурента или наличие функции в магазине.

## Итоговое решение для 1.12

Исследование не оправдывает новую большую подсистему. Лучший следующий релиз —
срез удаления и укрепления: проверить, что no-search действительно вырезан
из UI, модели и runtime; удалить только доказанно мёртвые обёртки; облегчить
горячий menu snapshot; привести настройки к пяти стабильным панелям; сделать
вставку и layout correction предсказуемыми; обновить документацию и карту
проекта. Полное global `-Osize`, массовый rewrite SwiftUI/AppKit и удаление
миграций без измерений запрещены: в прошлых замерах они создавали риск
регрессии storage snapshot или rollback.

Новая версия может называться 1.12.0 только после того, как release-gate
подтвердит поведение, размер, безопасность, подпись и clean-room установку.
До этого 1.12 — локальный кандидат, а публичная 1.10.0/локальные 1.11.x не
должны смешиваться.
