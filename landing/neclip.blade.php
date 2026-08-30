@extends('affpapa.layout')

@section('title', 'NeClip — менеджер буфера обмена для Mac | AffPapa')
@section('description', 'NeClip — бесплатный нативный clipboard manager для Apple Silicon Mac. История копирований, глобальный хоткей Cmd+Shift+V, автовставка, поиск. SQLite локально, без телеметрии, 2 зависимости. Open source.')
@section('canonical', 'https://affpapa.org/neclip')

@php
    $version = '1.1.1';
    $dmgUrl = '/downloads/NeClip-' . $version . '.dmg';

    $faqs = [
        ['q' => 'Где хранится история?', 'a' => 'Локально на Mac — в SQLite-базе в Application Support. Облака, сервера и синхронизации нет. Удаление приложения не удаляет эту папку автоматически: очистите данные внутри NeClip или удалите папку Application Support/NeClip вручную.'],
        ['q' => 'Есть ли телеметрия или аналитика?', 'a' => 'Нет. Фоновых сетевых запросов тоже нет. Единственный запрос выполняется только по команде «Проверить обновления» и обращается к affpapa.org.'],
        ['q' => 'Зачем нужно разрешение Accessibility?', 'a' => 'Только для автовставки: когда вы выбираете запись из меню, NeClip симулирует Cmd+V в активное приложение. Без разрешения всё работает, но выбранная запись просто копируется в буфер — вставить нужно самому.'],
        ['q' => 'Попадают ли пароли в историю?', 'a' => 'NeClip игнорирует записи с системными маркерами concealed/transient и копирование из исключённых приложений. Но не каждое приложение корректно помечает секреты, поэтому для чувствительных данных используйте паузу записи или «Не сохранять следующее копирование».'],
        ['q' => 'Как вставить без форматирования?', 'a' => 'Зажмите Option при выборе записи из меню — вставится чистый текст без форматирования. Без Option форматирование (RTF) сохраняется как в оригинале.'],
        ['q' => 'Поддерживается ли Intel Mac?', 'a' => 'Сборка arm64-only — для Apple Silicon (M1–M4). Исходники открыты: собрать под Intel можно самостоятельно одной командой swift build.'],
        ['q' => 'Чем NeClip отличается от других менеджеров?', 'a' => 'Фокусом: одна локальная история, быстрый поиск, клавиатура и сниппеты. Без аккаунта, облачной синхронизации, подписки и встроенных AI-функций.'],
        ['q' => 'Что делать с предупреждением Gatekeeper?', 'a' => 'Не обходите предупреждение. Используйте только DMG, для которого на странице выпуска подтверждены Developer ID, нотарификация и Gatekeeper-проверка точного скачанного файла.'],
        ['q' => 'Будет ли версия в App Store?', 'a' => 'Нет. Sandbox App Store запрещает симуляцию Cmd+V — автовставка невозможна. NeClip распространяется как DMG, обновления — на этой странице.'],
    ];

    $changelog = [
        [
            'ver' => '1.1.1',
            'build' => 3,
            'date' => '27 июля 2026',
            'items' => [
                'Надёжнее автовставка: задержка возврата фокуса увеличена до 300 мс',
                'Пункт «Разрешить автовставку» открывает сразу нужный раздел Системных настроек',
                'Иконка в menu bar: template-режим и фолбэк, если системный символ недоступен',
            ],
        ],
        [
            'ver' => '1.1.0',
            'build' => 2,
            'date' => '27 июля 2026',
            'items' => [
                'Сниппеты с папками: редактор, подменю в истории, отдельный хоткей Cmd+Shift+B',
                'OCR: текст на скопированных картинках распознаётся (Vision, рус+англ) и ищется поиском',
                'RTF: форматирование текста сохраняется и вставляется; Option при выборе — вставка без форматирования',
                'Проверка обновлений: пункт меню, сравнивает версию и открывает страницу загрузки — без автоматических запросов',
            ],
        ],
        [
            'ver' => '1.0.0',
            'build' => 1,
            'date' => '27 июля 2026',
            'items' => [
                'История буфера: текст, изображения, файлы',
                'Глобальный хоткей Cmd+Shift+V — меню у курсора',
                'Автовставка через Accessibility (симуляция Cmd+V)',
                'Быстрый выбор клавишами 1–9 и 0',
                'Живой поиск прямо в меню',
                'Дедупликация: повторное копирование поднимает запись наверх',
                'Фильтр ConcealedType — пароли не попадают в историю',
                'Исключённые приложения (менеджеры паролей — по умолчанию)',
                'Превью изображений в меню, лимит истории до 1000',
                'Запуск при входе в систему (SMAppService)',
                'SQLite + GRDB, arm64-only, Swift 6',
            ],
        ],
    ];

    $compareHeaders = ['', 'NeClip'];
    $compare = [
        ['Цена', 'Бесплатно'],
        ['Лицензия', 'MIT'],
        ['Аккаунт', 'Не нужен'],
        ['Облачная синхронизация', 'Нет'],
        ['Телеметрия', 'Нет'],
        ['Фоновая сеть', 'Нет'],
        ['История и поиск', 'Локально'],
        ['Сниппеты', 'Да'],
        ['OCR картинок', 'Локально'],
        ['Картинки и файлы', 'Да'],
    ];

    $proofItems = [
        ['num' => '2', 'label' => 'зависимости'],
        ['num' => '0', 'label' => 'аккаунтов'],
        ['num' => '0', 'label' => 'фоновых запросов'],
        ['num' => '1', 'label' => 'локальная база'],
    ];

    $demoClips = [
        ['icon' => '⌘1', 'text' => 'https://affpapa.org/neclip'],
        ['icon' => '⌘2', 'text' => 'Договор_аренды_final_v3.pdf'],
        ['icon' => '⌘3', 'text' => 'SELECT id, title FROM clip ORDER BY…'],
        ['icon' => '⌘4', 'text' => 'Скриншот 1440×900'],
        ['icon' => '⌘5', 'text' => '+7 999 123-45-67'],
    ];
@endphp

@push('head')
<meta property="og:type" content="product">
<script type="application/ld+json">{!! json_encode([
    '@context' => 'https://schema.org',
    '@graph' => [
        [
            '@type' => 'SoftwareApplication',
            '@id' => 'https://affpapa.org/neclip#app',
            'name' => 'NeClip',
            'applicationCategory' => 'UtilityApplication',
            'operatingSystem' => 'macOS 14 or later',
            'softwareVersion' => $version,
            'processorRequirements' => 'Apple Silicon / ARM64',
            'offers' => ['@type' => 'Offer', 'price' => '0', 'priceCurrency' => 'USD'],
            'downloadUrl' => 'https://affpapa.org' . $dmgUrl,
            'description' => 'Бесплатный нативный менеджер буфера обмена для Apple Silicon Mac: история копирований, глобальный хоткей, автовставка, поиск. Локальное хранение, без телеметрии.',
        ],
        [
            '@type' => 'FAQPage',
            '@id' => 'https://affpapa.org/neclip#faq',
            'mainEntity' => array_map(fn ($f) => [
                '@type' => 'Question',
                'name' => $f['q'],
                'acceptedAnswer' => ['@type' => 'Answer', 'text' => $f['a']],
            ], $faqs),
        ],
    ],
], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) !!}</script>
<style>
/* ── Scroll reveal ── */
.nc-reveal { opacity:0; transform:translateY(12px); transition:opacity 400ms cubic-bezier(.23,1,.32,1), transform 400ms cubic-bezier(.23,1,.32,1); }
.nc-reveal.is-visible { opacity:1; transform:translateY(0); }
@media (prefers-reduced-motion:reduce) { .nc-reveal { opacity:1; transform:none; transition:none; } }

/* ── Hero ── */
.nc-hero-grid { display:grid; grid-template-columns:1fr; gap:2rem; align-items:center; }
@media (min-width:740px) { .nc-hero-grid { grid-template-columns:1fr 300px; } }
.nc-platform { display:flex; flex-wrap:wrap; gap:.5rem; margin-top:1rem; }
.nc-platform .chip { font-family:var(--mono); font-size:.72rem; letter-spacing:.02em; }

/* ── Menu demo ── */
.nc-demo { display:flex; flex-direction:column; align-items:center; gap:.9rem; }
.nc-demo__kbd { display:flex; gap:.35rem; }
.nc-demo__key { font-family:var(--mono); font-size:.9rem; font-weight:700; padding:.45rem .7rem; border:1px solid var(--line); border-bottom-width:2px; border-radius:var(--radius-sm); background:var(--bg-soft); color:var(--ink); cursor:pointer; transition:transform 120ms var(--ease-out), border-color 150ms var(--ease-out), color 150ms var(--ease-out); user-select:none; }
.nc-demo__kbd:active .nc-demo__key, .nc-demo__key.is-pressed { transform:scale(.95); border-color:var(--accent-dim); color:var(--accent-dim); }
@media (hover:hover) and (pointer:fine) { .nc-demo__kbd:hover .nc-demo__key { border-color:var(--accent-dim); } }
.nc-demo__menu { width:250px; border:1px solid var(--line); border-radius:var(--radius); background:var(--bg); box-shadow:0 12px 32px rgba(0,0,0,.28); overflow:hidden; opacity:0; transform:scale(.95) translateY(-4px); transform-origin:top center; transition:opacity 200ms var(--ease-out), transform 200ms var(--ease-out); pointer-events:none; }
.nc-demo__menu.is-open { opacity:1; transform:scale(1) translateY(0); pointer-events:auto; }
@media (prefers-reduced-motion:reduce) { .nc-demo__menu { transition:none; } }
.nc-demo__row { display:flex; align-items:center; gap:.6rem; padding:.5rem .75rem; font-size:.82rem; color:var(--ink); cursor:pointer; transition:background-color 100ms ease; }
.nc-demo__row:hover { background:var(--accent-soft); }
.nc-demo__row.is-pasted { background:var(--accent-soft); }
.nc-demo__num { font-family:var(--mono); font-size:.72rem; color:var(--accent-dim); font-weight:700; width:.9rem; flex-shrink:0; }
.nc-demo__text { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font-family:var(--mono); font-size:.76rem; }
.nc-demo__hint { font-size:.78rem; color:var(--ink-2); }
.nc-demo__hint strong { font-family:var(--mono); color:var(--money); }

/* ── Problem ── */
.nc-problem { max-width:38rem; }
.nc-problem p { color:var(--ink-2); font-size:.95rem; line-height:1.55; margin-bottom:.75rem; }
.nc-problem p:last-child { margin-bottom:0; }

/* ── Local cards ── */
.nc-local-cards { display:grid; grid-template-columns:1fr; gap:.75rem; }
@media (min-width:600px) { .nc-local-cards { grid-template-columns:repeat(3,1fr); } }
.nc-local-card { padding:1.15rem; }
.nc-local-card h3 { margin:0 0 .3rem; font-size:.95rem; font-weight:700; }
.nc-local-card p { margin:0; color:var(--ink-2); font-size:.88rem; line-height:1.45; }
.nc-local-card__icon { font-family:var(--mono); font-size:.75rem; font-weight:600; color:var(--accent-dim); margin-bottom:.5rem; display:block; }

/* ── Features ── */
.nc-features { display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:1rem; }
.nc-feat { position:relative; padding:1.25rem; }
.nc-feat__icon { width:2.2rem; height:2.2rem; display:flex; align-items:center; justify-content:center; border-radius:var(--radius-sm); background:var(--accent-soft); color:var(--accent-dim); font-family:var(--mono); font-size:1.1rem; font-weight:700; margin-bottom:.75rem; }
.nc-feat h3 { margin:0 0 .35rem; font-size:1rem; font-weight:700; }
.nc-feat p { margin:0; color:var(--ink-2); font-size:.92rem; line-height:1.45; }
.nc-feat kbd { font-family:var(--mono); font-size:.78rem; padding:.1rem .35rem; border:1px solid var(--line); border-bottom-width:2px; border-radius:4px; background:var(--bg-soft); }

/* ── Steps ── */
.nc-steps { counter-reset:step; display:grid; gap:.6rem; }
.nc-step { position:relative; padding:.9rem 1rem .9rem 3.4rem; }
.nc-step::before { counter-increment:step; content:counter(step); position:absolute; left:1rem; top:.9rem; width:1.8rem; height:1.8rem; display:flex; align-items:center; justify-content:center; border-radius:50%; background:var(--accent-soft); color:var(--accent-dim); font-family:var(--mono); font-weight:700; font-size:.85rem; }
.nc-step h3 { margin:0 0 .2rem; font-size:.95rem; font-weight:700; }
.nc-step p { margin:0; color:var(--ink-2); font-size:.88rem; }
.nc-step kbd { font-family:var(--mono); font-size:.78rem; padding:.1rem .35rem; border:1px solid var(--line); border-bottom-width:2px; border-radius:4px; background:var(--bg-soft); }

/* ── Proof ── */
.nc-proof { display:grid; grid-template-columns:repeat(auto-fit,minmax(120px,1fr)); gap:.75rem; margin-top:1rem; }
.nc-proof-stat { padding:.85rem; text-align:center; }
.nc-proof-stat__num { display:block; font-family:var(--mono); font-variant-numeric:tabular-nums; font-size:1.6rem; font-weight:800; color:var(--ink); letter-spacing:-0.03em; }
.nc-proof-stat__label { display:block; font-size:.78rem; color:var(--ink-2); margin-top:.15rem; }

/* ── Compare ── */
.nc-compare-wrap { overflow-x:auto; border:1px solid var(--line); border-radius:var(--radius); }
.nc-compare { width:100%; border-collapse:collapse; font-size:.82rem; min-width:720px; }
.nc-compare th, .nc-compare td { padding:.6rem .7rem; text-align:left; border-bottom:1px solid var(--line); vertical-align:top; }
.nc-compare thead th { font-weight:700; color:var(--ink); background:var(--bg-soft); position:sticky; top:0; z-index:2; }
.nc-compare thead th:nth-child(2) { color:var(--accent-dim); }
.nc-compare tbody th { font-weight:500; color:var(--ink-2); background:var(--bg); position:sticky; left:0; z-index:1; }
.nc-compare tbody td { color:var(--ink); }
.nc-compare tbody td:first-of-type { color:var(--accent-dim); font-weight:600; }
.nc-compare tr:last-child th, .nc-compare tr:last-child td { border-bottom:0; }
@media (hover:hover) and (pointer:fine) {
    .nc-compare tbody tr { transition:background-color 120ms ease; }
    .nc-compare tbody tr:hover { background:var(--bg-soft); }
}

/* ── Changelog ── */
.nc-changelog { display:grid; gap:1.5rem; }
.nc-release { position:relative; padding-left:1.5rem; border-left:2px solid var(--accent-dim); }
.nc-release__head { display:flex; align-items:baseline; gap:.5rem; flex-wrap:wrap; margin-bottom:.4rem; }
.nc-release__ver { font-family:var(--mono); font-variant-numeric:tabular-nums; font-size:1rem; font-weight:800; color:var(--ink); }
.nc-release__date { font-size:.78rem; color:var(--ink-2); }
.nc-release__list { margin:0; padding:0 0 0 1rem; }
.nc-release__list li { font-size:.88rem; color:var(--ink-2); line-height:1.5; margin-bottom:.2rem; }

/* ── Gatekeeper note ── */
.nc-boundary { padding:1.15rem 1.25rem; border-left:3px solid var(--accent); border-radius:0 var(--radius-sm) var(--radius-sm) 0; background:var(--bg-soft); }
.nc-boundary__title { font-size:.9rem; font-weight:700; color:var(--ink); margin:0 0 .5rem; }
.nc-boundary p { margin:.4rem 0 0; font-size:.88rem; color:var(--ink-2); line-height:1.55; }
.nc-boundary p:first-of-type { margin:0; }
.nc-boundary kbd { font-family:var(--mono); font-size:.78rem; padding:.1rem .35rem; border:1px solid var(--line); border-bottom-width:2px; border-radius:4px; background:var(--bg); }

/* ── FAQ ── */
.nc-faq-item { border:1px solid var(--line); border-radius:var(--radius-sm); margin-bottom:.6rem; background:var(--bg); overflow:hidden; }
.nc-faq-item__q { width:100%; border:none; background:none; padding:.85rem 2.5rem .85rem 1rem; font:inherit; font-weight:600; font-size:1rem; color:var(--ink); text-align:left; cursor:pointer; position:relative; }
.nc-faq-item__q::after { content:'+'; position:absolute; right:1rem; top:.85rem; font-family:var(--mono); color:var(--accent-dim); font-size:1.1rem; transition:transform 200ms var(--ease-out); }
.nc-faq-item.is-open .nc-faq-item__q::after { transform:rotate(45deg); }
@media (hover:hover) and (pointer:fine) { .nc-faq-item__q:hover { color:var(--accent-dim); } }
.nc-faq-item__a { display:grid; grid-template-rows:0fr; transition:grid-template-rows 250ms var(--ease-out); }
.nc-faq-item.is-open .nc-faq-item__a { grid-template-rows:1fr; }
.nc-faq-item__a-inner { overflow:hidden; }
.nc-faq-item__a-inner p { padding:0 1rem .85rem; margin:0; color:var(--ink-2); font-size:.92rem; line-height:1.5; }
@media (prefers-reduced-motion:reduce) { .nc-faq-item__a { transition:none; } }

/* ── Buttons ── */
.btn:active { transform:scale(.97); }
.nc-dl-meta { font-family:var(--mono); font-size:.72rem; color:var(--ink-2); margin-top:.5rem; }
</style>
@endpush

@section('content')
    {{-- ═══ HERO ═══ --}}
    <section class="hero" id="top">
        <div class="nc-hero-grid">
            <div>
                <p class="badge"><span class="badge-dot" aria-hidden="true"></span>Native · Apple Silicon · Бесплатно</p>
                <h1 class="hero-title">Буфер обмена<br>с памятью</h1>
                <p class="hero-lead">Cmd+C затирает предыдущее. NeClip помнит всё скопированное — текст, картинки, файлы — и&nbsp;вставляет любую запись двумя нажатиями. Нативное меню, глобальный хоткей, ноль телеметрии.</p>

                <div class="nc-platform">
                    <span class="chip">macOS 14+</span>
                    <span class="chip">Apple Silicon</span>
                    <span class="chip">Swift 6</span>
                    <span class="chip">SQLite</span>
                    <span class="chip">v{{ $version }}</span>
                </div>

                <div class="hero-actions" style="margin-top:1.25rem;">
                    <a class="btn btn-primary" href="{{ $dmgUrl }}" download>Скачать для Apple Silicon</a>
                    <a class="btn btn-ghost" href="#neclip-changelog">Changelog {{ $version }}</a>
                </div>
                <p class="nc-dl-meta">NeClip-{{ $version }}.dmg · ~2 MB · MIT</p>
            </div>
            <div class="nc-demo" aria-hidden="true" x-data="ncDemo()">
                <div class="nc-demo__kbd" @click="toggle()" role="button" tabindex="0" @keydown.enter="toggle()">
                    <span class="nc-demo__key" :class="{'is-pressed': open}">⌘</span>
                    <span class="nc-demo__key" :class="{'is-pressed': open}">⇧</span>
                    <span class="nc-demo__key" :class="{'is-pressed': open}">V</span>
                </div>
                <div class="nc-demo__menu" :class="{'is-open': open}">
                    @foreach ($demoClips as $i => $clip)
                        <div class="nc-demo__row" :class="{'is-pasted': pasted === {{ $i }}}" @click="paste({{ $i }})">
                            <span class="nc-demo__num">{{ $clip['icon'] }}</span>
                            <span class="nc-demo__text">{{ $clip['text'] }}</span>
                        </div>
                    @endforeach
                </div>
                <p class="nc-demo__hint" x-show="pasted !== null" x-cloak>вставлено <strong>✓</strong></p>
                <p class="nc-demo__hint" x-show="pasted === null">нажмите ⌘⇧V — попробуйте</p>
            </div>
        </div>
    </section>

    {{-- ═══ PROBLEM ═══ --}}
    <section class="section nc-reveal" id="neclip-problem">
        <div class="section-head"><h2>Скопировал → отвлёкся → потерял</h2></div>
        <div class="nc-problem">
            <p>Буфер обмена macOS помнит ровно одну вещь. Скопировали номер договора, потом ссылку — номер исчез. Знакомый цикл: переключиться обратно, найти, снова скопировать.</p>
            <p>Многие менеджеры добавляют аккаунты, синхронизацию, подписку и целые рабочие пространства. Для быстрого возврата к недавнему копированию это часто лишнее.</p>
            <p>NeClip оставляет только суть: локальная история, поиск, клавиатура, автовставка и сниппеты. Две зависимости, без аккаунта, облака и телеметрии.</p>
        </div>
    </section>

    {{-- ═══ LOCAL-FIRST ═══ --}}
    <section class="section nc-reveal" id="neclip-local">
        <div class="section-head"><h2>Всё остаётся на вашем Mac</h2></div>
        <div class="nc-local-cards">
            <div class="card nc-local-card nc-reveal" style="transition-delay:0ms">
                <span class="nc-local-card__icon" aria-hidden="true">SQLITE</span>
                <h3>Локальная база</h3>
                <p>История — в SQLite в Application Support. Без облака, аккаунта и синхронизации.</p>
            </div>
            <div class="card nc-local-card nc-reveal" style="transition-delay:60ms">
                <span class="nc-local-card__icon" aria-hidden="true">OFFLINE</span>
                <h3>Без фоновой сети</h3>
                <p>NeClip не отправляет телеметрию и не обращается к сети в фоне. Запрос к affpapa.org выполняется только при ручной проверке обновлений.</p>
            </div>
            <div class="card nc-local-card nc-reveal" style="transition-delay:120ms">
                <span class="nc-local-card__icon" aria-hidden="true">CONCEALED</span>
                <h3>Защита чувствительных копий</h3>
                <p>NeClip учитывает системные маркеры concealed/transient и исключённые приложения. Для немаркированных секретов есть пауза и пропуск следующего копирования.</p>
            </div>
        </div>
    </section>

    {{-- ═══ FEATURES ═══ --}}
    <section class="section nc-reveal" id="neclip-features">
        <div class="section-head"><h2>Что умеет</h2></div>
        <div class="nc-features">
            <div class="card nc-feat nc-reveal" style="transition-delay:0ms">
                <div class="nc-feat__icon" aria-hidden="true">⧉</div>
                <h3>История всего</h3>
                <p>Текст, изображения (с превью в меню), файлы. Повторное копирование поднимает запись наверх, а не плодит дубли.</p>
            </div>
            <div class="card nc-feat nc-reveal" style="transition-delay:60ms">
                <div class="nc-feat__icon" aria-hidden="true">⌘</div>
                <h3>Меню у курсора</h3>
                <p><kbd>⌘⇧V</kbd> открывает нативное меню там, где вы работаете. <kbd>⌘1</kbd>–<kbd>⌘9</kbd> выбирают видимый результат, обычные цифры остаются поиском.</p>
            </div>
            <div class="card nc-feat nc-reveal" style="transition-delay:120ms">
                <div class="nc-feat__icon" aria-hidden="true">↩</div>
                <h3>Автовставка</h3>
                <p>Выбрали запись — NeClip сам вставит её в активное приложение. Не нужно жать Cmd+V после выбора.</p>
            </div>
            <div class="card nc-feat nc-reveal" style="transition-delay:180ms">
                <div class="nc-feat__icon" aria-hidden="true">⌕</div>
                <h3>Живой поиск</h3>
                <p>Поле поиска прямо в меню — фильтрует историю по мере ввода, ищет и по содержимому.</p>
            </div>
            <div class="card nc-feat nc-reveal" style="transition-delay:240ms">
                <div class="nc-feat__icon" aria-hidden="true">⊘</div>
                <h3>Исключения</h3>
                <p>Список приложений, из которых ничего не записывается. Менеджеры паролей — в списке из коробки.</p>
            </div>
            <div class="card nc-feat nc-reveal" style="transition-delay:300ms">
                <div class="nc-feat__icon" aria-hidden="true">✂</div>
                <h3>Сниппеты с папками</h3>
                <p>Заготовки текста — шаблоны ответов, реквизиты, промокоды. <kbd>⌘⇧B</kbd> открывает их отдельным меню.</p>
            </div>
            <div class="card nc-feat nc-reveal" style="transition-delay:360ms">
                <div class="nc-feat__icon" aria-hidden="true">👁</div>
                <h3>OCR на картинках</h3>
                <p>Текст на скопированных скриншотах распознаётся локально (Vision, рус+англ) — и находится поиском.</p>
            </div>
            <div class="card nc-feat nc-reveal" style="transition-delay:420ms">
                <div class="nc-feat__icon" aria-hidden="true">⚙</div>
                <h3>Настройки без лишнего</h3>
                <p>Лимит истории 10–1000, длина заголовков, превью, автозапуск при входе. Всё.</p>
            </div>
        </div>
    </section>

    {{-- ═══ STEPS ═══ --}}
    <section class="section nc-reveal" id="neclip-how">
        <div class="section-head"><h2>Три шага</h2></div>
        <div class="nc-steps">
            <div class="card nc-step nc-reveal" style="transition-delay:0ms">
                <h3>Скачайте и откройте</h3>
                <p>DMG → перетащите NeClip в Applications и запустите. Если macOS показывает предупреждение Gatekeeper, не обходите его.</p>
            </div>
            <div class="card nc-step nc-reveal" style="transition-delay:80ms">
                <h3>Разрешите автовставку</h3>
                <p>Один переключатель в System Settings → Privacy → Accessibility. Можно пропустить — тогда записи просто копируются.</p>
            </div>
            <div class="card nc-step nc-reveal" style="transition-delay:160ms">
                <h3>Копируйте как обычно</h3>
                <p>NeClip тихо запоминает. Когда что-то понадобится — <kbd>⌘⇧V</kbd>, поиск или <kbd>⌘1</kbd>–<kbd>⌘9</kbd>.</p>
            </div>
        </div>
    </section>

    {{-- ═══ PROOF ═══ --}}
    <section class="section nc-reveal" id="neclip-proof">
        <div class="section-head"><h2>Насколько он маленький</h2></div>
        <div class="nc-proof">
            @foreach ($proofItems as $pi)
                <div class="card nc-proof-stat nc-reveal">
                    <span class="nc-proof-stat__num">{{ $pi['num'] }}</span>
                    <span class="nc-proof-stat__label">{{ $pi['label'] }}</span>
                </div>
            @endforeach
        </div>
        <p class="muted" style="margin-top:1rem; font-size:.82rem; max-width:38rem;">Зависимости: GRDB (SQLite) и HotKey (глобальные хоткеи, ~200 строк). Всё остальное — стандартные фреймворки Apple: AppKit, SwiftUI, ServiceManagement.</p>
    </section>

    {{-- ═══ COMPARISON ═══ --}}
    <section class="section nc-reveal" id="neclip-compare">
        <div class="section-head"><h2>Осознанные ограничения</h2></div>
        <div class="nc-compare-wrap">
            <table class="nc-compare">
                <thead>
                    <tr>
                        @foreach ($compareHeaders as $h)
                            <th>{{ $h }}</th>
                        @endforeach
                    </tr>
                </thead>
                <tbody>
                    @foreach ($compare as $row)
                        <tr>
                            <th scope="row">{{ $row[0] }}</th>
                            @for ($i = 1; $i < count($row); $i++)
                                <td>{{ $row[$i] }}</td>
                            @endfor
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
        <p class="muted" style="margin-top:.8rem; font-size:.78rem;">NeClip сознательно не добавляет аккаунты, облачную синхронизацию, подписку, доски и AI. Цель — быстро найти и вставить локальный фрагмент.</p>
    </section>

    {{-- ═══ GATEKEEPER ═══ --}}
    <section class="section nc-reveal" id="neclip-boundary">
        <div class="nc-boundary">
            <p class="nc-boundary__title">Проверяйте точный файл выпуска</p>
            <p>Публикуемый DMG должен пройти Developer ID, нотарификацию Apple, stapling и Gatekeeper-проверку. Если macOS показывает предупреждение, не обходите его и скачайте последнюю проверенную сборку.</p>
            <p>Исходники при этом открыты — можно прочитать каждую строку и собрать самому: <span style="font-family:var(--mono); font-size:.82rem;">swift build -c release</span>.</p>
        </div>
    </section>

    {{-- ═══ CHANGELOG ═══ --}}
    <section class="section nc-reveal" id="neclip-changelog">
        <div class="section-head"><h2>Changelog</h2></div>
        <div class="nc-changelog">
            @foreach ($changelog as $rel)
                <div class="nc-release">
                    <div class="nc-release__head">
                        <span class="nc-release__ver">{{ $rel['ver'] }}</span>
                        <span class="nc-release__date">build {{ $rel['build'] }} · {{ $rel['date'] }}</span>
                    </div>
                    <ul class="nc-release__list">
                        @foreach ($rel['items'] as $item)
                            <li>{{ $item }}</li>
                        @endforeach
                    </ul>
                </div>
            @endforeach
        </div>
    </section>

    {{-- ═══ FAQ ═══ --}}
    <section class="section nc-reveal" id="neclip-faq">
        <div class="section-head"><h2>Вопросы и ответы</h2></div>
        @foreach ($faqs as $f)
            <div class="nc-faq-item" x-data="{open:false}" :class="{'is-open':open}">
                <button class="nc-faq-item__q" type="button" @click="open=!open" :aria-expanded="open">{{ $f['q'] }}</button>
                <div class="nc-faq-item__a" role="region">
                    <div class="nc-faq-item__a-inner">
                        <p>{{ $f['a'] }}</p>
                    </div>
                </div>
            </div>
        @endforeach
    </section>

    {{-- ═══ FINAL CTA ═══ --}}
    <section class="section nc-reveal" style="text-align:center; padding:2.5rem 0;">
        <h2 style="font-size:1.3rem; margin:0 0 .5rem;">Перестаньте терять скопированное</h2>
        <p class="muted" style="margin:0 0 1.25rem; max-width:480px; margin-left:auto; margin-right:auto;">Бесплатно, open source, без телеметрии. Скачали — работает.</p>
        <div class="hero-actions" style="justify-content:center;">
            <a class="btn btn-primary" href="{{ $dmgUrl }}" download>Скачать NeClip {{ $version }}</a>
            <a class="btn btn-ghost" href="#neclip-faq">FAQ</a>
        </div>
    </section>

    <script>
    (function () {
        if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
            var obs = new IntersectionObserver(function (entries) {
                entries.forEach(function (e) {
                    if (e.isIntersecting) { e.target.classList.add('is-visible'); obs.unobserve(e.target); }
                });
            }, { threshold: 0.08, rootMargin: '0px 0px -40px 0px' });
            document.querySelectorAll('.nc-reveal').forEach(function (el) { obs.observe(el); });
        } else {
            document.querySelectorAll('.nc-reveal').forEach(function (el) { el.classList.add('is-visible'); });
        }
    })();

    document.addEventListener('alpine:init', function () {
        Alpine.data('ncDemo', function () {
            return {
                open: false,
                pasted: null,
                toggle: function () {
                    this.open = !this.open;
                    if (!this.open) this.pasted = null;
                },
                paste: function (i) {
                    this.pasted = i;
                    var self = this;
                    setTimeout(function () { self.open = false; }, 450);
                }
            };
        });
    });
    </script>
@endsection
