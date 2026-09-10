# NeClip 2.5.2 — полный audit loop

Цель: сделать NeClip незаметным, быстрым и предсказуемым помощником. Сначала
устранить ошибки и регрессии, затем оптимизировать горячие пути, не расширяя
поверхность продукта без доказанной пользы.

## P0 — release blockers

1. Проверить жизненный цикл menu-bar приложения и удержание AppDelegate.
2. Проверить закрытие настроек, редактора и overlay через Esc/Command-W.
3. Проверить все пять глобальных горячих клавиш и конфликты.
4. Проверить area/full-screen capture на Retina, нескольких дисплеях и смене дисплея.
5. Проверить `scalesToFit`, aspect ratio, origin и crop-координаты.
6. Проверить отмену захвата во всех состояниях и отсутствие публикации после Escape.
7. Проверить исключение окна NeClip из захвата и fail-closed разрешения.
8. Проверить PNG/JPEG рендер, redaction и отсутствие частичных файлов.
9. Проверить clipboard generation/race при копировании результата.
10. Проверить приватность паролей, исключений приложений и паузы.
11. Проверить миграции SQLite и атомарное удаление данных.
12. Проверить stale async results для меню, настроек и редактора сниппетов.
13. Проверить ошибки разрешений macOS и понятный retry.
14. Проверить arm64 signing, notarization, stapling, Gatekeeper и mounted DMG.
15. Проверить manifest, exact commit, checksum и rollback установки.

## P1 — скорость и ясность

16–30. Измерить открытие меню, чтение первой страницы, capture latency, peak
memory, editor launch и cold start; убрать только подтверждённые лишние копии,
сортировки, фоновые записи и повторные layout passes.

31–45. Сверить меню, настройки и редакторы с Apple HIG: один термин на действие,
видимый фокус, клавиатурная навигация, единый light/dark стиль, доступность
VoiceOver и отсутствие скрытых режимов.

46–60. Проверить текстовые лимиты, Unicode/grapheme boundaries, длинные URL,
изображения, пустые и повреждённые записи; добавить регрессии только на найденные
дефекты.

61–75. Проверить сборку и размер: dead code, ресурсы, символы, зависимости,
опции оптимизации, launch agents, лишние файлы в app bundle и архиве.

## P2 — безопасное улучшение

76–90. Сопоставить текущую поверхность с 5–10 минималистичными clipboard и
screenshot utilities; принять только функции, которые сокращают действие или
настройку, без поиска, аккаунтов, облака и телеметрии.

91–100. Обновить проектную карту, changelog, сайт, release evidence и smoke
runbook; повторить security scan всей истории и проверить публичные артефакты.

## Gates

- Plan gate: контекст, границы и acceptance criteria зафиксированы до edits.
- Code gate: targeted + full tests, strict Swift 6, warnings-as-errors.
- Security gate: gitleaks current tree и вся Git history, plist/JSON/diff checks.
- Release gate: exact commit → signed arm64 → notarized/stapled → Gatekeeper →
  mounted DMG → checksum.
- Live gate: установленная версия, `⌘⇧2`, `⌘⌥3`, menu-bar, settings close и
  OpenAI Site version check.

Не удалять совместимость миграций и rollback backup. Не обходить required CI
checks и не публиковать промежуточные manifest или неподтверждённые артефакты.
