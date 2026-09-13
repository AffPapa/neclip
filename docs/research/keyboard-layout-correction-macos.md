# Надёжное исправление ошибочной раскладки на macOS

## Вывод

Надёжный переключатель раскладки должен разделять четыре задачи: определить границу слова, получить фактически набранный текст, выбрать направление преобразования и безопасно заменить текст с проверкой результата. Простого «перевести строку и отправить Cmd+V» недостаточно: фокус, Accessibility-элемент, системная раскладка и clipboard могут измениться между чтением и вставкой.

Для NeClip приоритетом становится ручное исправление по одиночному Option/Alt и существующий автоматический режим. Ручная команда должна быть детерминированной: если пользователь явно попросил конвертацию, словарь не должен блокировать её. Автоматический режим остаётся консервативным и использует словарь только для решения, когда исправление безопасно.

## Что показывают аналоги

| Продукт / источник | Наблюдаемая модель | Практический вывод для NeClip |
| --- | --- | --- |
| Punto Switcher | Анализирует последовательности символов, при подозрении удаляет ошибочный текст, меняет раскладку и вводит результат заново. Современная macOS-спецификация описывает `WordTracker`, raw keycodes, clipboard fallback, AX retry и защиту от гонок. | Нужен bounded-трекер и отдельная стратегия для нестандартных редакторов; нельзя полагаться на один мгновенный AX/clipboard вызов. |
| Caramba Switcher | Автоисправление только при высокой уверенности; Double Shift исправляет последнее слово или выделение; есть исключения для программирования, игр и паролей. | Автоматический режим должен быть precision-first, а ручная команда — доступна для имён, терминов и сленга. |
| UASwitcher | Option или другой одиночный/двойной триггер; поддерживает последнее слово и выделение, старается работать без clipboard, переключает активную раскладку после исправления. | Option должен быть отдельным pass-through-триггером, а активную раскладку нужно менять и проверять после ручного исправления. |
| Traple | Использует `CGEventTap`, хранит raw `(keycode, shift)` и переводит их под актуальной раскладкой на границе слова; отдельно отмечает рассинхронизацию при смене раскладки посреди слова. | Нельзя считать только `event.keyboardGetUnicodeString` источником истины; контекст надо инвалидировать при смене приложения/раскладки и уметь восстановиться. |
| MySwitcher | Разделяет исправление текущего слова, уже завершённого слова и выделения; повтор команды сразу отменяет последнее исправление; явно описывает ограничения AX/фокуса. | Нужны короткое окно undo, повторный вызов, понятное состояние «текст исправлен, раскладка не переключилась» и fail-closed для защищённых полей. |
| Apple macOS | Сама система умеет выбирать input source для документа и исправлять орфографию, но это не исправляет ошибочную раскладку. `NSEvent` global monitor только наблюдает события, а `CGEventTap` предназначен для низкоуровневого наблюдения/фильтрации системного ввода. | Для modifier-only жеста использовать `CGEventTap`; события не подавлять и не изменять, а действие выполнять после безопасного release. |

## Почему текущая реализация иногда пропускает

1. Одиночный Option слушается через `NSEvent.addGlobalMonitorForEvents`. Этот API наблюдает события других приложений, но не является низкоуровневым event tap и не даёт такой же контроль над порядком событий.
2. `TISSelectInputSource` проверяется практически мгновенно. Уведомление и обновление текущего input source могут прийти после проверки, поэтому текст уже исправлен, а NeClip считает переключение неуспешным или откатывает автоматическую замену.
3. Ручная замена использует только clipboard + Cmd+V. У Electron/VS Code, браузеров, удалённых окон и нестандартных текстовых поверхностей AX и Cmd+V ведут себя неодинаково.
4. Текущий автоматический трекер формирует границу только на Space. Запятые, точки, Tab и Enter должны завершать слово с сохранением самого разделителя.
5. После ручного исправления выделения активная раскладка не переключается, хотя аналоги обычно активируют раскладку результата.
6. Успех замены и успех переключения раскладки смешаны в одном пользовательском результате; это затрудняет диагностику и создаёт ощущение, что команда «не сработала».

## Решение для 2.7

### P0

- Перевести Option-only listener на отдельный passive `CGEventTap` с повторной активацией после `tapDisabledByTimeout`/`tapDisabledByUserInput`.
- Оставить события полностью pass-through: Option+символ, Option+клик и Option с другими модификаторами не изменяются.
- Добавить debounce только от дублированных release-событий, не ломая быстрый повтор для undo.
- Сделать выбор input source retry-able и подтверждать результат несколькими короткими проверками.
- Для ручного исправления сначала пробовать прямую AX-замену выделения, а затем использовать сохранённый clipboard fallback; восстановление clipboard — только при неизменившемся `changeCount`.
- Переключать активную раскладку после ручного исправления и отдельно показывать предупреждение, если текст заменён, но input source не подтвердился.
- Расширить границы автоматического слова: Space, Tab, Return/Enter и безопасная конечная пунктуация; разделитель не удалять.
- Инвалидировать контекст при paste/cut/undo, смене приложения, смене input source, мыши и secure input.

### P1

- Добавить bounded last-word tracker для ручного Option fallback, не сохраняя историю фраз и паролей.
- Добавить диагностический статус без текста пользователя: причина пропуска, bundle ID, тип AX-поверхности, длительность операции и результат переключения.
- Добавить пользовательские Always convert / Never convert только для автоматического режима.

### Не включать сейчас

- OCR, облачную обработку, AI-классификацию, сетевые словари, макро-язык и перехват/подавление пользовательских клавиш.

## Acceptance gates

- Unit: state machine Option, debounce, punctuation boundaries, retry policy, conversion with case/punctuation, secure/excluded fields.
- Integration: TextEdit, Safari, заметки/мессенджер, Electron/VS Code, rich text, selected text, last word after Space/Enter/punctuation, immediate undo.
- Security: secure fields and Secure Event Input never read or mutate; clipboard snapshot is complete; no text payloads in logs; secret scan clean.
- Release: strict Swift 6 build, full XCTest/Swift Testing, Developer ID, notarization, stapling, Gatekeeper, mounted DMG, public checksum and installed-app smoke.

## Sources

1. Apple, [NSEvent documentation](https://developer.apple.com/documentation/appkit/nsevent) — global monitor observes events but does not modify them.
2. Apple, [Cocoa Event Handling Guide: Monitoring Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html) — global monitor limitations and Accessibility requirement.
3. Apple, [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services) — event taps for system-wide input observation and filtering.
4. Apple Support, [Change Input Sources settings on Mac](https://support.apple.com/en-euro/guide/mac-help/-mchl84525d76/mac) — document input-source behavior and system switching options.
5. Caramba Switcher, [Mac App Store listing](https://apps.apple.com/us/app/caramba-switcher-autocorrect/id1565826179?mt=12) — automatic confidence, Double Shift, exclusions and password behavior.
6. UASwitcher, [technical README](https://github.com/deimoc/UASwitcher) — Option trigger, selected/last-word correction, clipboard-free path and input-source pairs.
7. Traple, [architecture README](https://github.com/spendolas/traple) — raw keycode tracking, `CGEventTap`, layout changes during a word and punctuation boundaries.
8. Punto, [technical specification](https://github.com/rshagiev/punto-switcher/blob/main/docs/TECHNICAL_SPEC.md) — WordTracker, AX/clipboard fallback, retries, race prevention and protected fields.
9. MySwitcher, [manual correction behavior](https://myswitcher.net/en/help/manual-correction.html) — separation of last-word/selection correction, undo and AX limitations.
