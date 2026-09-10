# Скриншоты: 50 функций и 20 решений для NeClip

Актуальный ресёрч 10 сентября 2026 года. Сравнены 15 macOS‑решений: Apple
Screenshot/Markup, CleanShot X, Shottr, Snagit, Flameshot, Xnapper, Monosnap,
Capto, iShot, ShotX, macshot, Gyazo, Droplr, ScreenFloat и Shotnix.

## Каталог из 50 функций

1. Area capture; 2. Space для перемещения выделения; 3. Escape‑отмена;
4. захват окна; 5. floating thumbnail; 6. Quick Access Overlay;
7. Copy/Save/Annotate; 8. drag‑and‑drop результата; 9. zoom canvas;
10. быстрый Retina copy; 11. frozen‑screen workflow; 12. preview без editor;
13. contextual properties; 14. сохранение выбранного инструмента;
15. Undo/Redo/Copy/Save hotkeys; 16. repeat previous area;
17. shortcut conflict check; 18. инструменты на capture overlay;
19. буквенный выбор инструмента; 20. pixel‑navigation выделения;
21. скрытие панели; 22. Copy/Save/Undo/Redo/Esc в capture;
23. Space/window branch; 24. прямые стрелки/фигуры/текст;
25. ручная redact‑маска; 26. auto background/shadow;
27. configurable global shortcut; 28. скрытие редких инструментов;
29. library/share sidebar; 30. быстрый crosshair;
31. copy‑and‑close; 32. editor после area capture; 33. cloud storage;
34. arrows/text/blur/highlight; 35. PNG/JPEG export; 36. tags/search;
37. OCR/scroll/translate; 38. базовые annotations; 39. menu‑bar native app;
40. live re‑register hotkeys; 41. no Electron/no polling;
42. boundary snap/aspect presets; 43. window mode через Space;
44. пользовательские shortcut keys; 45. Draw перед отправкой;
46. auto upload/short link; 47. floating reference shots;
48. non‑destructive markup/import; 49. transient hover controls/badge;
50. local/no‑account/native shortcut model.

## Выбранные 20 для NeClip

1. Одна global клавиша для area capture.
2. Space‑перемещение уже выделенного прямоугольника.
3. Escape как единая отмена.
4. Изображение сразу занимает главное место в окне.
5. Одна компактная нижняя панель.
6. Прямые annotations на canvas.
7. `⌘Return` — копировать и закрыть, `⌘S` — сохранить.
8. `⌘Z`/`⌘⇧Z`.
9. `1…5` для инструментов без зависимости от раскладки.
10. Сохранение выбранного инструмента для серии пометок.
11. Непрозрачная redact‑маска.
12. Space как расширяемая ветка window capture.
13. Повтор последней области после отдельного UX‑подтверждения.
14. Transient feedback вместо звука.
15. PNG по умолчанию, JPEG только явным выбором.
16. Drag‑and‑drop результата.
17. Live регистрация горячей клавиши и конфликтов.
18. Idle‑quiet native Swift/AppKit/ScreenCaptureKit.
19. Direct capture API с безопасным fallback.
20. Внутренний signpost latency gate без данных пользователя.

В 2.4.0 реализованы пункты 1–11, 14–15, 17–18 и 20. В 2.5.0 добавлены
отдельный полноэкранный capture и безопасное пропорциональное уменьшение
больших Retina-кадров. Пункты 12–13, 16 и 19
оставлены как следующие безопасные срезы: их реализация требует отдельного
QA для window‑захвата, drag source и availability API, иначе они увеличат
риск и задержку основного потока.

## Что не переносим

Нет аккаунтов, облака, upload/short links, библиотеки скриншотов, поиска,
тегов, pin/floating shots, видео/GIF, scrolling, OCR/перевода, ML‑redact,
фонов/теней/водяных знаков, проектов/layers и десятков отдельных клавиш.
Эти функции увеличивают вес и настройки, но не ускоряют моментальный сценарий.

## Первичные источники

- [Apple Screenshot](https://support.apple.com/en-us/102646) · [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [CleanShot X](https://cleanshot.com/features?xs=1) · [Shottr](https://shottr.cc/kb/startguide) · [Flameshot](https://flameshot.org/docs/guide/key-bindings/)
- [Xnapper](https://xnapper.com/blog/annotate-screenshot) · [Snagit hotkeys](https://www.techsmith.com/learn/tutorials/snagit/snagit-hotkeys/) · [Capto](https://www.globaldelight.com/capto/features)
- [ShotX](https://github.com/aimen08/shotx) · [macshot](https://github.com/sw33tLie/macshot) · [Shotnix](https://github.com/OMARVII/Shotnix)

Оценки ценности/сложности и отбор топ‑20 — инженерная рекомендация для
минималистичной локальной утилиты, а не обещания производителей.
