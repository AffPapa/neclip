# NeClip 1.6.0 zero-rethink loop

## Goal

С нуля перепроверить 20 clipboard managers и 20 layout tools, сопоставить их с
текущим NeClip, сформировать 100 кандидатов и реализовать минимальный связный
privacy-first срез без аккаунта, облака, AI, телеметрии, Dock-иконки и новых
обязательных разрешений.

## Gates

1. Три независимых read-only слоя: clipboard, layout, current code.
2. Исследование содержит ровно 100 нумерованных кандидатов и топ-20.
3. Каждое выбранное изменение имеет тест и понятный UI.
4. Полный test/build/sanitizer/security/visual gate зелёный.
5. Публичная 1.4.0 и установленное приложение не меняются в этом цикле.

## Stop rule

Остановиться после локального проверенного commit. Push, GitHub Release,
notarization и замена `/Applications/NeClip.app` требуют отдельного разрешения.
