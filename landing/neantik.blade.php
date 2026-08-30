@extends('affpapa.layout')

@section('title', 'NeAntik — антидетект-браузер для Apple Silicon Mac | AffPapa')
@section('description', 'NeVision — нативный менеджер браузерных профилей для macOS. Изолированные сессии, прокси, локальное хранение и встроенная проверка fingerprint A→B→A. SwiftUI, без Electron, без облака.')
@section('canonical', 'https://affpapa.org/neantik')

@php
    $faqs = [
        ['q' => 'Это антидетект-браузер?', 'a' => 'NeVision Direct — нативный менеджер изолированных Chromium-профилей с fingerprint-протоколом для совместимого runtime. Он разделяет cookies, storage и proxy в любом поддерживаемом Chromium, но Canvas, WebGL, Audio и device signals изменяются только в совместимом patched runtime.'],
        ['q' => 'Чем профиль NeVision отличается от инкогнито?', 'a' => 'Инкогнито временно отделяет cookies и историю, но не создаёт постоянную сессию и не меняет fingerprint устройства. Профиль NeVision сохраняется между запусками, использует отдельный data directory и может иметь собственный proxy и identity.'],
        ['q' => 'Где хранятся профили?', 'a' => 'Локально на Mac — в Application Support. Proxy-пароли хранятся отдельно в macOS Keychain. Облака и серверов NeVision нет.'],
        ['q' => 'Нужен ли аккаунт?', 'a' => 'Нет. Нет аккаунта, облачной синхронизации, аналитики или телеметрии.'],
        ['q' => 'Поддерживается ли Intel Mac?', 'a' => 'Нет. NeVision создан только для Apple Silicon (M1, M2, M3, M4) и выпускается как ARM64-only.'],
        ['q' => 'Поддерживается ли SOCKS5 с логином и паролем?', 'a' => 'В Direct — нет: Chromium не реализует SOCKS5 authentication. Для credentials используйте HTTP/HTTPS proxy. Store edition использует отдельный proxy stack Apple Network framework.'],
        ['q' => 'Гарантирует ли NeVision анонимность?', 'a' => 'Нет. Ни один браузер не может честно это гарантировать. Proxy, аккаунты, поведение и расширения могут связывать сессии. NeVision уменьшает пересечение профилей и даёт инструмент для измерения fingerprint, но не обещает невозможность корреляции.'],
        ['q' => 'Что показывает Fingerprint Check?', 'a' => 'Он сравнивает два профиля (A → B → A) и проверяет: отличаются ли fingerprint-поверхности между профилями и стабилен ли результат при повторном запуске. Verdict: verified, partial, unchanged или unstable.'],
        ['q' => 'Есть ли версия для App Store?', 'a' => 'Готовится sandboxed WebKit-редакция (NeVision Store). Она разделяет website data и proxy, но не создаёт разные hardware fingerprints. Direct-версия с Chromium распространяется отдельно.'],
    ];

    $changelog = [
        [
            'ver' => '0.3.1',
            'build' => 4,
            'date' => '25 июля 2026',
            'items' => [
                'Защита от PID reuse — не остановит чужой Chrome',
                'Owner-only (0600/0700) для metadata, отчётов и lock-файлов',
                'Rollback при ошибке записи на диск',
                'Строгая валидация DNS, IPv4, IPv6 proxy hosts',
                'Отключение QUIC в proxy-режиме',
                'Одноразовые browser-data directories для fingerprint check',
                'Убрано ложное обещание SOCKS5 authentication',
                'Proxy-пароли не попадают в process arguments',
                'Пройдено 38 Direct и 4 Store теста',
            ],
        ],
        [
            'ver' => '0.3.0',
            'build' => 3,
            'date' => '24 июля 2026',
            'items' => [
                'Встроенный fingerprint check A → B → A',
                'Canvas, WebGL, Audio, ClientRects, GPU, Client Hints, fonts, WebRTC',
                'Verdicts: verified, partial, unchanged, unstable',
                'Runtime manifest: Standard, Fingerprint, Cloak flavors',
                'Preflight: path, executable, Mach-O, signature, version',
                'Разделение на Direct и Store editions',
                'Зафиксированы исходники будущего owned Chromium runtime',
            ],
        ],
        [
            'ver' => '0.2.0',
            'build' => 2,
            'date' => '24 июля 2026',
            'items' => [
                'Постоянный fingerprint seed для каждого профиля',
                'Различение stock Chrome и fingerprint-compatible runtime',
                'Проверка proxy: exit IP, город, страна, timezone, locale',
                'DNS и WebRTC leak controls',
                'Проверка ARM64 — Intel-only runtime не предлагается',
            ],
        ],
        [
            'ver' => '0.1',
            'build' => 1,
            'date' => '24 июля 2026',
            'label' => 'Prototype',
            'items' => [
                'Первый SwiftUI MVP для Apple Silicon',
                'Создание, редактирование, удаление профилей',
                'Отдельный Chromium data directory на профиль',
                'Постоянные cookies, local storage, sessions',
                'HTTP/HTTPS и SOCKS5 proxy, пароли в Keychain',
                'Process locks и browser logs',
            ],
        ],
    ];

    $compareHeaders = ['', 'NeVision', 'Multilogin', 'GoLogin', 'AdsPower', 'Dolphin Anty', 'Octo'];
    $compare = [
        ['Тип',             'Native macOS',  'Кросс-платформа', 'Кросс-платформа', 'Кросс-платформа', 'Кросс-платформа', 'Кросс-платформа'],
        ['Движок',          'SwiftUI',       'Electron/Web',    'Electron',        'Electron',        'Electron',        'Electron/Web'],
        ['Облако',          'Нет',           'Да',              'Да',              'Да',              'Да (старшие)',    'Да'],
        ['Аккаунт',         'Не нужен',      'Нужен',           'Нужен',           'Нужен',           'Нужен',           'Нужен'],
        ['Команды и роли',  '—',             '✓',               '✓',               '✓',               '✓',               '✓'],
        ['API/автоматизация','—',            '✓',               'REST API',        'Local API + RPA', '—',               '✓'],
        ['Fingerprint',     'Seed + A→B→A проверка', 'Генерация', 'Генерация',   'Генерация',       'Генерация',       'Генерация'],
        ['Проверка результата', '✓ встроенная', '—',            '—',               '—',               '—',               '—'],
        ['Телеметрия',      'Нет',           'Есть',            'Есть',            'Есть',            'Есть',            'Есть'],
        ['Для кого',        'Индивид. на Mac', 'Команды',       'Команды',         'Команды',         'Affiliate-команды','Команды'],
    ];

    $surfaces = ['Canvas', 'WebGL pixels', 'WebGL vendor/renderer', 'Audio', 'ClientRects', 'GPU/device', 'Client Hints', 'Fonts', 'Timezone/locale', 'WebRTC'];

    $proofItems = [
        ['num' => '38', 'label' => 'тестов Direct'],
        ['num' => '4', 'label' => 'теста Store'],
        ['num' => '10', 'label' => 'поверхностей A→B→A'],
        ['num' => '~1.4', 'label' => 'MB менеджер'],
    ];
@endphp

@push('head')
<meta property="og:type" content="product">
<script type="application/ld+json">{!! json_encode([
    '@context' => 'https://schema.org',
    '@graph' => [
        [
            '@type' => 'SoftwareApplication',
            '@id' => 'https://affpapa.org/neantik#app',
            'name' => 'NeVision',
            'applicationCategory' => 'UtilityApplication',
            'operatingSystem' => 'macOS 14 or later',
            'softwareVersion' => '0.3.1',
            'processorRequirements' => 'Apple Silicon / ARM64',
            'description' => 'Нативный менеджер изолированных браузерных профилей для Apple Silicon Mac с локальной fingerprint-проверкой A→B→A.',
        ],
        [
            '@type' => 'FAQPage',
            '@id' => 'https://affpapa.org/neantik#faq',
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
.nk-reveal { opacity:0; transform:translateY(12px); transition:opacity 400ms cubic-bezier(.23,1,.32,1), transform 400ms cubic-bezier(.23,1,.32,1); }
.nk-reveal.is-visible { opacity:1; transform:translateY(0); }
@media (prefers-reduced-motion:reduce) { .nk-reveal { opacity:1; transform:none; transition:none; } }

/* ── Hero two-col ── */
.nk-hero-grid { display:grid; grid-template-columns:1fr; gap:2rem; align-items:center; }
@media (min-width:740px) { .nk-hero-grid { grid-template-columns:1fr 280px; } }
.nk-hero-visual { display:flex; align-items:center; justify-content:center; }
.nk-hero-icon { width:180px; height:180px; border-radius:32px; background:var(--accent-soft); border:1px solid var(--line); display:flex; align-items:center; justify-content:center; overflow:hidden; }
.nk-hero-icon svg { width:100px; height:100px; }
@media (max-width:739px) { .nk-hero-visual { display:none; } }

/* ── Platform line ── */
.nk-platform { display:flex; flex-wrap:wrap; gap:.5rem; margin-top:1rem; }
.nk-platform .chip { font-family:var(--mono); font-size:.72rem; letter-spacing:.02em; }

/* ── A→B→A interactive ── */
.nk-aba-demo { margin:1.5rem 0; }
.nk-aba { display:flex; align-items:center; gap:.5rem; flex-wrap:wrap; margin:0 0 .75rem; }
.nk-aba__node { position:relative; display:flex; flex-direction:column; align-items:center; gap:.2rem; padding:.7rem 1.1rem; border:1px solid var(--line); border-radius:var(--radius-sm); background:var(--bg-soft); min-width:90px; transition:border-color 250ms var(--ease-out), background 250ms var(--ease-out); }
.nk-aba__node--active { border-color:var(--accent-dim); background:var(--accent-soft); }
.nk-aba__node--done { border-color:var(--money, var(--accent-dim)); }
.nk-aba__node-label { font-family:var(--mono); font-size:.85rem; font-weight:700; color:var(--ink); }
.nk-aba__node-sub { font-size:.72rem; color:var(--ink-2); transition:color 200ms var(--ease-out); }
.nk-aba__node--active .nk-aba__node-sub { color:var(--accent-dim); }
.nk-aba__arrow { color:var(--ink-2); font-size:1.1rem; opacity:.4; transition:opacity 200ms var(--ease-out); }
.nk-aba__arrow--active { opacity:1; color:var(--accent-dim); }
.nk-aba__verdict { font-family:var(--mono); font-size:.82rem; font-weight:700; padding:.3rem .7rem; border-radius:var(--radius-sm); opacity:0; transform:scale(.95); transition:opacity 250ms var(--ease-out), transform 250ms var(--ease-out); }
.nk-aba__verdict.is-visible { opacity:1; transform:scale(1); }
.nk-aba__verdict--verified { color:var(--money); background:rgba(91,228,155,.08); border:1px solid rgba(91,228,155,.2); }
.nk-aba__btn { font-family:var(--mono); font-size:.78rem; padding:.45rem .9rem; border-radius:var(--radius-sm); border:1px solid var(--line); background:var(--bg-soft); color:var(--ink-2); cursor:pointer; transition:border-color 150ms var(--ease-out), color 150ms var(--ease-out), transform 120ms var(--ease-out); }
.nk-aba__btn:active { transform:scale(.97); }
@media (hover:hover) and (pointer:fine) { .nk-aba__btn:hover { border-color:var(--accent-dim); color:var(--accent-dim); } }

/* ── Surfaces chips ── */
.nk-surfaces { display:flex; flex-wrap:wrap; gap:.35rem; margin-top:.75rem; }
.nk-surfaces .chip { font-size:.75rem; }

/* ── Problem section ── */
.nk-problem { max-width:38rem; }
.nk-problem p { color:var(--ink-2); font-size:.95rem; line-height:1.55; margin-bottom:.75rem; }
.nk-problem p:last-child { margin-bottom:0; }

/* ── Local-first cards ── */
.nk-local-cards { display:grid; grid-template-columns:1fr; gap:.75rem; }
@media (min-width:600px) { .nk-local-cards { grid-template-columns:repeat(3,1fr); } }
.nk-local-card { padding:1.15rem; }
.nk-local-card h3 { margin:0 0 .3rem; font-size:.95rem; font-weight:700; }
.nk-local-card p { margin:0; color:var(--ink-2); font-size:.88rem; line-height:1.45; }
.nk-local-card__icon { font-family:var(--mono); font-size:.75rem; font-weight:600; color:var(--accent-dim); margin-bottom:.5rem; display:block; }

/* ── Feature cards ── */
.nk-features { display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:1rem; }
.nk-feat { position:relative; padding:1.25rem; }
.nk-feat__icon { width:2.2rem; height:2.2rem; display:flex; align-items:center; justify-content:center; border-radius:var(--radius-sm); background:var(--accent-soft); color:var(--accent-dim); font-family:var(--mono); font-size:1.1rem; font-weight:700; margin-bottom:.75rem; }
.nk-feat h3 { margin:0 0 .35rem; font-size:1rem; font-weight:700; }
.nk-feat p { margin:0; color:var(--ink-2); font-size:.92rem; line-height:1.45; }

/* ── Steps ── */
.nk-steps { counter-reset:step; display:grid; gap:.6rem; }
.nk-step { position:relative; padding:.9rem 1rem .9rem 3.4rem; }
.nk-step::before { counter-increment:step; content:counter(step); position:absolute; left:1rem; top:.9rem; width:1.8rem; height:1.8rem; display:flex; align-items:center; justify-content:center; border-radius:50%; background:var(--accent-soft); color:var(--accent-dim); font-family:var(--mono); font-weight:700; font-size:.85rem; }
.nk-step h3 { margin:0 0 .2rem; font-size:.95rem; font-weight:700; }
.nk-step p { margin:0; color:var(--ink-2); font-size:.88rem; }

/* ── Proof stats ── */
.nk-proof { display:grid; grid-template-columns:repeat(auto-fit,minmax(120px,1fr)); gap:.75rem; margin-top:1rem; }
.nk-proof-stat { padding:.85rem; text-align:center; }
.nk-proof-stat__num { display:block; font-family:var(--mono); font-variant-numeric:tabular-nums; font-size:1.6rem; font-weight:800; color:var(--ink); letter-spacing:-0.03em; }
.nk-proof-stat__label { display:block; font-size:.78rem; color:var(--ink-2); margin-top:.15rem; }

/* ── Comparison table ── */
.nk-compare-wrap { overflow-x:auto; border:1px solid var(--line); border-radius:var(--radius); }
.nk-compare { width:100%; border-collapse:collapse; font-size:.82rem; min-width:780px; }
.nk-compare th, .nk-compare td { padding:.6rem .7rem; text-align:left; border-bottom:1px solid var(--line); vertical-align:top; }
.nk-compare thead th { font-weight:700; color:var(--ink); background:var(--bg-soft); position:sticky; top:0; z-index:2; }
.nk-compare thead th:nth-child(2) { color:var(--accent-dim); }
.nk-compare tbody th { font-weight:500; color:var(--ink-2); background:var(--bg); position:sticky; left:0; z-index:1; }
.nk-compare tbody td { color:var(--ink); }
.nk-compare tbody td:first-of-type { color:var(--accent-dim); font-weight:600; }
.nk-compare tr:last-child th, .nk-compare tr:last-child td { border-bottom:0; }
@media (hover:hover) and (pointer:fine) {
    .nk-compare tbody tr { transition:background-color 120ms ease; }
    .nk-compare tbody tr:hover { background:var(--bg-soft); }
}

/* ── Changelog ── */
.nk-changelog { display:grid; gap:1.5rem; }
.nk-release { position:relative; padding-left:1.5rem; border-left:2px solid var(--line); }
.nk-release__head { display:flex; align-items:baseline; gap:.5rem; flex-wrap:wrap; margin-bottom:.4rem; }
.nk-release__ver { font-family:var(--mono); font-variant-numeric:tabular-nums; font-size:1rem; font-weight:800; color:var(--ink); }
.nk-release__label { font-size:.75rem; color:var(--accent-dim); font-weight:600; }
.nk-release__date { font-size:.78rem; color:var(--ink-2); }
.nk-release__list { margin:0; padding:0 0 0 1rem; }
.nk-release__list li { font-size:.88rem; color:var(--ink-2); line-height:1.5; margin-bottom:.2rem; }
.nk-release:first-child { border-left-color:var(--accent-dim); }

/* ── Honest boundary ── */
.nk-boundary { padding:1.15rem 1.25rem; border-left:3px solid var(--accent); border-radius:0 var(--radius-sm) var(--radius-sm) 0; background:var(--bg-soft); }
.nk-boundary__title { font-size:.9rem; font-weight:700; color:var(--ink); margin:0 0 .5rem; }
.nk-boundary p { margin:.4rem 0 0; font-size:.88rem; color:var(--ink-2); line-height:1.55; }
.nk-boundary p:first-of-type { margin:0; }

/* ── Editions ── */
.nk-editions { display:grid; grid-template-columns:1fr; gap:1rem; }
@media (min-width:600px) { .nk-editions { grid-template-columns:1fr 1fr; } }
.nk-edition { padding:1.25rem; }
.nk-edition h3 { margin:0 0 .35rem; font-size:1rem; font-weight:700; }
.nk-edition p { margin:0; color:var(--ink-2); font-size:.88rem; line-height:1.45; }
.nk-edition__badge { display:inline-block; font-family:var(--mono); font-size:.7rem; font-weight:600; padding:.15rem .45rem; border-radius:999px; margin-bottom:.5rem; }
.nk-edition__badge--direct { background:var(--accent-soft); color:var(--accent-dim); }
.nk-edition__badge--store { background:var(--bg-soft); color:var(--ink-2); border:1px solid var(--line); }

/* ── FAQ smooth ── */
.nk-faq-item { border:1px solid var(--line); border-radius:var(--radius-sm); margin-bottom:.6rem; background:var(--bg); overflow:hidden; }
.nk-faq-item__q { width:100%; border:none; background:none; padding:.85rem 2.5rem .85rem 1rem; font:inherit; font-weight:600; font-size:1rem; color:var(--ink); text-align:left; cursor:pointer; position:relative; }
.nk-faq-item__q::after { content:'+'; position:absolute; right:1rem; top:.85rem; font-family:var(--mono); color:var(--accent-dim); font-size:1.1rem; transition:transform 200ms var(--ease-out); }
.nk-faq-item.is-open .nk-faq-item__q::after { transform:rotate(45deg); }
@media (hover:hover) and (pointer:fine) { .nk-faq-item__q:hover { color:var(--accent-dim); } }
.nk-faq-item__a { display:grid; grid-template-rows:0fr; transition:grid-template-rows 250ms var(--ease-out); }
.nk-faq-item.is-open .nk-faq-item__a { grid-template-rows:1fr; }
.nk-faq-item__a-inner { overflow:hidden; }
.nk-faq-item__a-inner p { padding:0 1rem .85rem; margin:0; color:var(--ink-2); font-size:.92rem; line-height:1.5; }
@media (prefers-reduced-motion:reduce) { .nk-faq-item__a { transition:none; } }

/* ── Buttons ── */
.btn:active { transform:scale(.97); }
.btn--disabled { opacity:.5; pointer-events:none; }
</style>
@endpush

@section('content')
    {{-- ═══ HERO ═══ --}}
    <section class="hero" id="top">
        <div class="nk-hero-grid">
            <div>
                <p class="badge"><span class="badge-dot" aria-hidden="true"></span>Native · Apple Silicon · Local-first</p>
                <h1 class="hero-title">Браузерные профили<br>для Mac без облака</h1>
                <p class="hero-lead">NeVision разделяет cookies, сессии, storage и&nbsp;proxy между профилями. Нативное SwiftUI-приложение — без Electron, без аккаунта, без телеметрии. Fingerprint не&nbsp;просто настраивается — результат можно измерить.</p>

                <div class="nk-platform">
                    <span class="chip">macOS 14+</span>
                    <span class="chip">Apple Silicon</span>
                    <span class="chip">ARM64 only</span>
                    <span class="chip">SwiftUI</span>
                    <span class="chip">v0.3.1</span>
                </div>

                <div class="hero-actions" style="margin-top:1.25rem;">
                    <a class="btn btn-primary btn--disabled" href="#" aria-disabled="true" title="Скоро">Скачать для Apple Silicon</a>
                    <a class="btn btn-ghost" href="#neantik-changelog">Changelog 0.3.1</a>
                </div>
            </div>
            <div class="nk-hero-visual">
                <div class="nk-hero-icon" aria-hidden="true">
                    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <rect x="18" y="22" width="64" height="48" rx="6" stroke="var(--accent-dim)" stroke-width="2.5" fill="none"/>
                        <rect x="28" y="32" width="18" height="28" rx="3" stroke="var(--ink-2)" stroke-width="1.5" fill="var(--accent-soft)" opacity=".6"/>
                        <rect x="54" y="32" width="18" height="28" rx="3" stroke="var(--ink-2)" stroke-width="1.5" fill="var(--bg-soft)" opacity=".6"/>
                        <line x1="50" y1="36" x2="50" y2="56" stroke="var(--accent-dim)" stroke-width="1" stroke-dasharray="3 2"/>
                        <path d="M40 76 50 82 60 76" stroke="var(--accent-dim)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
                    </svg>
                </div>
            </div>
        </div>
    </section>

    {{-- ═══ PROBLEM ═══ --}}
    <section class="section nk-reveal" id="neantik-problem">
        <div class="section-head"><h2>Профили должны разделять контексты, а&nbsp;не&nbsp;усложнять работу</h2></div>
        <div class="nk-problem">
            <p>Режим инкогнито не&nbsp;создаёт новое устройство для сайта. Cookies можно очистить, но&nbsp;Canvas, WebGL, Audio, GPU, timezone и&nbsp;другие сигналы остаются связанными с&nbsp;тем&nbsp;же браузером и&nbsp;Mac.</p>
            <p>Большие антидетект-платформы решают эту задачу вместе с&nbsp;облаком, командами, API, RPA и&nbsp;десятками настроек. Это полезно для масштабных операций, но&nbsp;лишнее, если нужны несколько постоянных локальных контекстов на&nbsp;одном Mac.</p>
            <p>NeVision оставляет только основу: профиль, proxy, отдельные данные, стабильная identity и&nbsp;проверка результата.</p>
        </div>
    </section>

    {{-- ═══ KILLER FEATURE: A→B→A ═══ --}}
    <section class="section nk-reveal" id="neantik-check">
        <div class="section-head"><h2>Настроить недостаточно — нужно измерить</h2></div>
        <p class="muted" style="max-width:640px; margin-bottom:1rem;">Совместимый Chromium получает identity профиля. Затем NeVision запускает локальную проверку A → B → A: сравнивает два профиля и повторно проверяет первый.</p>

        <div class="nk-aba-demo" x-data="nkAba()">
            <div class="nk-aba">
                <div class="nk-aba__node" :class="{'nk-aba__node--active': step===1, 'nk-aba__node--done': step>1}">
                    <span class="nk-aba__node-label">Profile A</span>
                    <span class="nk-aba__node-sub" x-text="step===1 ? 'measuring…' : step>1 ? 'stable' : 'idle'" x-show="!done"></span>
                    <span class="nk-aba__node-sub" x-show="done" style="color:var(--money)">stable</span>
                </div>
                <span class="nk-aba__arrow" :class="{'nk-aba__arrow--active': step>=2}" aria-hidden="true">→</span>
                <div class="nk-aba__node" :class="{'nk-aba__node--active': step===2, 'nk-aba__node--done': step>2}">
                    <span class="nk-aba__node-label">Profile B</span>
                    <span class="nk-aba__node-sub" x-text="step===2 ? 'measuring…' : step>2 ? 'distinct' : 'idle'" x-show="!done"></span>
                    <span class="nk-aba__node-sub" x-show="done" style="color:var(--accent-dim)">distinct</span>
                </div>
                <span class="nk-aba__arrow" :class="{'nk-aba__arrow--active': step>=3}" aria-hidden="true">→</span>
                <div class="nk-aba__node" :class="{'nk-aba__node--active': step===3, 'nk-aba__node--done': done}">
                    <span class="nk-aba__node-label">Profile A</span>
                    <span class="nk-aba__node-sub" x-text="step===3 ? 're-checking…' : done ? 'stable' : 'idle'" x-show="!done"></span>
                    <span class="nk-aba__node-sub" x-show="done" style="color:var(--money)">stable</span>
                </div>
                <span class="nk-aba__verdict" :class="{'is-visible': done, 'nk-aba__verdict--verified': done}">verified</span>
            </div>
            <button class="nk-aba__btn" @click="run()" :disabled="running" x-text="done ? '↻ Повторить' : running ? 'Проверяю…' : '▶ Запустить проверку'"></button>
        </div>

        <p style="font-size:.88rem; color:var(--ink-2); margin:.5rem 0;">Если A и B отличаются, но A нестабилен между запусками — fingerprint ненадёжен. Только различающийся <em>и</em> повторяемый результат получает verdict <strong style="font-family:var(--mono);">verified</strong>.</p>

        <div class="nk-surfaces">
            @foreach ($surfaces as $s)
                <span class="chip">{{ $s }}</span>
            @endforeach
        </div>
    </section>

    {{-- ═══ LOCAL-FIRST ═══ --}}
    <section class="section nk-reveal" id="neantik-local">
        <div class="section-head"><h2>Ваши профили остаются на&nbsp;вашем Mac</h2></div>
        <div class="nk-local-cards">
            <div class="card nk-local-card nk-reveal" style="transition-delay:0ms">
                <span class="nk-local-card__icon" aria-hidden="true">SESSION</span>
                <h3>Отдельные сессии</h3>
                <p>Cookies, local storage, cache и авторизация одного профиля не используются другим.</p>
            </div>
            <div class="card nk-local-card nk-reveal" style="transition-delay:60ms">
                <span class="nk-local-card__icon" aria-hidden="true">NETWORK</span>
                <h3>Отдельная сеть</h3>
                <p>HTTP/HTTPS или SOCKS5 proxy назначается профилю. Проверка exit IP и согласование timezone.</p>
            </div>
            <div class="card nk-local-card nk-reveal" style="transition-delay:120ms">
                <span class="nk-local-card__icon" aria-hidden="true">KEYCHAIN</span>
                <h3>macOS security</h3>
                <p>Пароли в Keychain, owner-only файлы, proxy credentials не попадают в command line.</p>
            </div>
        </div>
    </section>

    {{-- ═══ WHY NEVISION ═══ --}}
    <section class="section nk-reveal" id="neantik-why">
        <div class="section-head"><h2>Почему NeVision</h2></div>
        <div class="nk-features">
            <div class="card nk-feat nk-reveal" style="transition-delay:0ms">
                <div class="nk-feat__icon" aria-hidden="true">◆</div>
                <h3>Нативный для Mac</h3>
                <p>SwiftUI, ARM64-only. Без Electron, Tauri, Node.js. Менеджер весит ~1,4 MB — запускается мгновенно.</p>
            </div>
            <div class="card nk-feat nk-reveal" style="transition-delay:60ms">
                <div class="nk-feat__icon" aria-hidden="true">⊘</div>
                <h3>Без облака и аккаунта</h3>
                <p>Профили хранятся на Mac. Нет синхронизации, нет телеметрии, нет сервера NeVision.</p>
            </div>
            <div class="card nk-feat nk-reveal" style="transition-delay:120ms">
                <div class="nk-feat__icon" aria-hidden="true">⊞</div>
                <h3>Минимум настроек</h3>
                <p>Имя, стартовая страница, цвет, proxy. Без десятков fingerprint-переключателей.</p>
            </div>
            <div class="card nk-feat nk-reveal" style="transition-delay:180ms">
                <div class="nk-feat__icon" aria-hidden="true">↻</div>
                <h3>Proxy + leak control</h3>
                <p>HTTP/HTTPS, SOCKS5. Проверка exit IP, блокировка DNS fallback, отключение QUIC и non-proxied WebRTC.</p>
            </div>
        </div>
    </section>

    {{-- ═══ HOW IT WORKS ═══ --}}
    <section class="section nk-reveal" id="neantik-how">
        <div class="section-head"><h2>Три шага</h2></div>
        <div class="nk-steps">
            <div class="card nk-step nk-reveal" style="transition-delay:0ms">
                <h3>Создайте профиль</h3>
                <p>Имя, цвет, стартовая страница. NeVision создаст отдельное локальное хранилище.</p>
            </div>
            <div class="card nk-step nk-reveal" style="transition-delay:80ms">
                <h3>Подключите proxy</h3>
                <p>HTTP/HTTPS или SOCKS5. Проверьте exit IP, страну и timezone одной кнопкой.</p>
            </div>
            <div class="card nk-step nk-reveal" style="transition-delay:160ms">
                <h3>Запустите и проверьте</h3>
                <p>Откройте браузер, сохраните сессию. Запустите A → B → A для совместимого runtime.</p>
            </div>
        </div>
    </section>

    {{-- ═══ PROOF ═══ --}}
    <section class="section nk-reveal" id="neantik-proof">
        <div class="section-head"><h2>Что уже проверено</h2></div>
        <div class="nk-proof">
            @foreach ($proofItems as $pi)
                <div class="card nk-proof-stat nk-reveal">
                    <span class="nk-proof-stat__num">{{ $pi['num'] }}</span>
                    <span class="nk-proof-stat__label">{{ $pi['label'] }}</span>
                </div>
            @endforeach
        </div>
        <p class="muted" style="margin-top:1rem; font-size:.82rem; max-width:38rem;">Swift strict-concurrency, ARM64-only release, code-sign verification, owner-only metadata, PID reuse protection, proxy injection tests, sandbox + entitlements Store, pinned runtime source provenance.</p>
    </section>

    {{-- ═══ COMPARISON ═══ --}}
    <section class="section nk-reveal" id="neantik-compare">
        <div class="section-head"><h2>NeVision vs антидетект-платформы</h2></div>
        <div class="nk-compare-wrap">
            <table class="nk-compare">
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
        <p class="muted" style="margin-top:.8rem; font-size:.78rem;">NeVision не заменяет командные функции больших платформ. Он для другого: быстрые локальные профили на Apple Silicon без инфраструктуры вокруг.</p>
    </section>

    {{-- ═══ EDITIONS ═══ --}}
    <section class="section nk-reveal" id="neantik-editions">
        <div class="section-head"><h2>Две редакции</h2></div>
        <div class="nk-editions">
            <div class="card nk-edition">
                <span class="nk-edition__badge nk-edition__badge--direct">Direct</span>
                <h3>NeVision Direct</h3>
                <p>Полная версия. Запускает Chromium, использует отдельные data directories и применяет fingerprint identity через совместимый runtime. Developer ID distribution.</p>
            </div>
            <div class="card nk-edition">
                <span class="nk-edition__badge nk-edition__badge--store">Store</span>
                <h3>NeVision Store</h3>
                <p>Sandboxed WebKit-редакция для Mac App Store. Разделяет cookies, storage и proxy, но сохраняет общий hardware fingerprint устройства.</p>
            </div>
        </div>
    </section>

    {{-- ═══ HONEST BOUNDARY ═══ --}}
    <section class="section nk-reveal" id="neantik-boundary">
        <div class="nk-boundary">
            <p class="nk-boundary__title">Что означает «compatible Chromium»</p>
            <p>Обычный Google Chrome создаёт отдельные cookies и browser data, но не применяет NeVision fingerprint protocol. Для различающихся Canvas, WebGL, Audio и device signals нужен совместимый patched Chromium.</p>
            <p>Исходники будущего owned runtime зафиксированы и проверены. Полный production build для Apple Silicon — отдельный инженерный этап, который ещё не завершён. До его прохождения NeVision не заявляет, что собственный runtime готов.</p>
        </div>
    </section>

    {{-- ═══ CHANGELOG ═══ --}}
    <section class="section nk-reveal" id="neantik-changelog">
        <div class="section-head"><h2>Changelog</h2></div>
        <div class="nk-changelog">
            @foreach ($changelog as $rel)
                <div class="nk-release">
                    <div class="nk-release__head">
                        <span class="nk-release__ver">{{ $rel['ver'] }}</span>
                        @if (!empty($rel['label']))
                            <span class="nk-release__label">{{ $rel['label'] }}</span>
                        @endif
                        <span class="nk-release__date">build {{ $rel['build'] }} · {{ $rel['date'] }}</span>
                    </div>
                    <ul class="nk-release__list">
                        @foreach ($rel['items'] as $item)
                            <li>{{ $item }}</li>
                        @endforeach
                    </ul>
                </div>
            @endforeach
        </div>
    </section>

    {{-- ═══ FAQ ═══ --}}
    <section class="section nk-reveal" id="neantik-faq">
        <div class="section-head"><h2>Вопросы и ответы</h2></div>
        @foreach ($faqs as $f)
            <div class="nk-faq-item" x-data="{open:false}" :class="{'is-open':open}">
                <button class="nk-faq-item__q" type="button" @click="open=!open" :aria-expanded="open">{{ $f['q'] }}</button>
                <div class="nk-faq-item__a" role="region">
                    <div class="nk-faq-item__a-inner">
                        <p>{{ $f['a'] }}</p>
                    </div>
                </div>
            </div>
        @endforeach
    </section>

    {{-- ═══ FINAL CTA ═══ --}}
    <section class="section nk-reveal" style="text-align:center; padding:2.5rem 0;">
        <h2 style="font-size:1.3rem; margin:0 0 .5rem;">Начните с чистого профиля</h2>
        <p class="muted" style="margin:0 0 1.25rem; max-width:480px; margin-left:auto; margin-right:auto;">Отдельный браузерный контекст за несколько секунд — без аккаунта, облака и лишних настроек.</p>
        <div class="hero-actions" style="justify-content:center;">
            <a class="btn btn-primary btn--disabled" href="#" aria-disabled="true" title="Скоро">Скачать для Apple Silicon</a>
            <a class="btn btn-ghost" href="#neantik-changelog">Changelog</a>
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
            document.querySelectorAll('.nk-reveal').forEach(function (el) { obs.observe(el); });
        } else {
            document.querySelectorAll('.nk-reveal').forEach(function (el) { el.classList.add('is-visible'); });
        }
    })();

    document.addEventListener('alpine:init', function () {
        Alpine.data('nkAba', function () {
            return {
                step: 0,
                running: false,
                done: false,
                run: function () {
                    if (this.running) return;
                    this.step = 0;
                    this.done = false;
                    this.running = true;
                    var self = this;
                    setTimeout(function () { self.step = 1; }, 200);
                    setTimeout(function () { self.step = 2; }, 900);
                    setTimeout(function () { self.step = 3; }, 1600);
                    setTimeout(function () { self.done = true; self.running = false; }, 2300);
                }
            };
        });
    });
    </script>
@endsection