<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    {{-- Тема применяется ДО первой отрисовки (без вспышки). Нет выбора — системная. --}}
    <script>(function(){try{var t=localStorage.getItem('affpapa-theme');if(t==='dark'||t==='light')document.documentElement.setAttribute('data-theme',t);}catch(e){}})();</script>
    {{-- Виджет объявлений — тоже без вспышки. Синхронно ставим class на <html>,
         CSS уже знает про has-ads-widget-open (сдвиг контента). --}}
    <script>(function(){try{var s=localStorage.getItem('affpapa-ads-open');var w=window.matchMedia('(min-width:1180px)').matches;if(s==='1'||(s==null&&w))document.documentElement.classList.add('ads-widget-preopen');}catch(e){}})();</script>
    <title>@yield('title', 'AffPapa Party — вечеринки индустрии')</title>
    @hasSection('description')
    <meta name="description" content="@yield('description')">
    @endif
    @hasSection('canonical')
    <link rel="canonical" href="@yield('canonical')">
    @endif
    @hasSection('robots')@yield('robots')@else<meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1">@endif
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="affpapa.org">
    <meta property="og:locale" content="ru_RU">
    <meta property="og:title" content="@yield('title', 'AffPapa Party — вечеринки индустрии')">
    @hasSection('description')
    <meta property="og:description" content="@yield('description')">
    @endif
    <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
    <meta name="theme-color" content="#14100f" media="(prefers-color-scheme: dark)">
    <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='16' fill='%23e63946'/%3E%3Ctext x='32' y='42' font-family='Arial,Helvetica,sans-serif' font-size='30' font-weight='800' text-anchor='middle' fill='%23ffffff'%3Eap%3C/text%3E%3C/svg%3E">
    <link rel="preload" href="/fonts/site/golos-cyrillic.woff2" as="font" type="font/woff2" crossorigin>
    <link rel="preload" href="/fonts/site/golos-latin.woff2" as="font" type="font/woff2" crossorigin>
    <link rel="preload" href="/fonts/site/jbmono-latin.woff2" as="font" type="font/woff2" crossorigin>
    <meta property="og:url" content="@yield('canonical', 'https://affpapa.org/')">
    <meta name="yandex-verification" content="46fd7f3d6a48116e" />
    <meta property="og:image" content="https://affpapa.org/brand/affpapa-og.png">
    <meta property="og:image:secure_url" content="https://affpapa.org/brand/affpapa-og.png">
    <meta property="og:image:type" content="image/png">
    <meta property="og:image:alt" content="AffPapa — базы контактов индустрии, бесплатно">
    <meta property="og:image:width" content="1536">
    <meta property="og:image:height" content="1024">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="@yield('title', 'AffPapa')">
    @hasSection('description')<meta name="twitter:description" content="@yield('description')">@endif
    <meta name="twitter:image" content="https://affpapa.org/brand/affpapa-og.png">
    <meta name="twitter:image:alt" content="AffPapa — базы контактов индустрии, бесплатно">
    <link rel="stylesheet" href="/css/affpapa.min.css?v={{ filemtime(public_path('css/affpapa.min.css')) }}">
    <script defer src="/js/affpapa/alpine.min.js"></script>
    <script defer src="/js/affpapa/site.js?v={{ filemtime(public_path('js/affpapa/site.js')) }}"></script>
    @stack('head')
</head>
<body>
    <header class="site-header">
        <div class="container header-inner">
            <a class="wordmark" href="{{ route('affpapa.home') }}">affpapa<span class="wordmark-dot">.</span></a>
            <button class="nav-burger" type="button" aria-label="Меню" aria-expanded="false" aria-controls="header-menu">
                <span></span><span></span><span></span>
            </button>
            <div class="header-menu" id="header-menu">
                <nav class="site-nav" aria-label="Разделы">
                    <a class="nav-flagship" href="{{ route('affpapa.neblask') }}"@if(request()->routeIs('affpapa.neblask*')) aria-current="page"@endif><span class="nav-flagship__dot"></span>NeBlask</a>
                    <a class="nav-tg" href="{{ route('affpapa.channels') }}" title="Каталог TG-каналов affiliate-индустрии"@if(request()->routeIs('affpapa.channels*')) aria-current="page"@endif><span class="nav-tg__dot" aria-hidden="true"></span>NeTGStat</a>
                    <a class="nav-flagship" href="{{ route('affpapa.nemail') }}" title="NeMail — одноразовая почта"@if(request()->routeIs('affpapa.nemail')) aria-current="page"@endif><span class="nav-flagship__dot"></span>NeMail</a>
                    <span class="nav-sep" aria-hidden="true"></span>
                    <details class="nav-more" data-nav-more open>
                        <summary>Ещё</summary>
                        <div class="nav-more__list">
                            <a class="nav-more__sec" href="{{ route('affpapa.home') }}#bases">Базы</a>
                            <a class="nav-more__sec" href="{{ route('affpapa.home') }}#lists" data-open-tab="conf">Конференции</a>
                            <a class="nav-more__sec" href="{{ route('affpapa.home') }}#lists" data-open-tab="vac">Вакансии</a>
                            <hr class="nav-more__hr" aria-hidden="true">
                            <a class="nav-more__sec nav-more__dev" href="{{ route('affpapa.necard') }}">NeCard <span class="nav-more__badge">dev</span></a>
                            <a class="nav-more__sec nav-more__dev" href="{{ route('affpapa.neagent') }}">NeAgent <span class="nav-more__badge">dev</span></a>
                            <a class="nav-more__sec nav-more__dev" href="{{ route('affpapa.neantik') }}">NeAntik <span class="nav-more__badge">dev</span></a>
                            <a class="nav-more__sec nav-more__dev" href="{{ route('affpapa.neahrefs') }}">NeAhrefs <span class="nav-more__badge">dev</span></a>
                            <a class="nav-more__sec nav-more__dev" href="{{ route('affpapa.neclip') }}">NeClip <span class="nav-more__badge">new</span></a>
                        </div>
                    </details>
                </nav>
                {{-- Одна универсальная кнопка справа: клик → dropdown с
                     переключением темы, входом/выходом. Заменяет 3 кнопки
                     (Канал/Тема/Выход) — весь функционал внутри меню. --}}
                <button class="theme-toggle" type="button" data-theme-toggle aria-label="Переключить тему" title="Тема">
                    <svg class="theme-toggle__sun" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4.5"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4"/></svg>
                    <svg class="theme-toggle__moon" width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M20 14.5A8 8 0 019.5 4a7 7 0 108.99 10.98 0.4 0.4 0 01.51-.48z"/></svg>
                </button>
                <div class="user-menu" data-user-menu>
                    <button class="user-menu__btn" type="button" data-user-menu-btn aria-haspopup="true" aria-expanded="false" aria-label="Меню пользователя">
                        <span data-user-menu-face></span>
                    </button>
                    <div class="user-menu__panel" data-user-menu-panel hidden role="menu"></div>
                </div>
            </div>
        </div>
    </header>

    <main class="container">
        @yield('content')
    </main>

    {{-- Боковой виджет объявлений — только там, где есть $ads (главная). --}}
    @yield('side_widgets')

    <footer class="site-footer">
        <div class="container footer-inner">
            <div class="footer-top">
                <div class="footer-brand">
                    <span class="wordmark wordmark-sm">affpapa<span class="wordmark-dot">.</span></span>
                    <p class="muted">Инструменты affiliate-индустрии: аналитика, каталоги, базы, одноразовая почта.</p>
                </div>
                <div class="footer-cols footer-cols--2">
                    <div class="footer-col">
                        <h4>Разделы</h4>
                        <a class="footer-flagship" href="{{ route('affpapa.neblask') }}"><span class="footer-flagship__dot"></span>NeBlask — индекс спроса</a>
                        <a class="footer-flagship" href="{{ route('affpapa.channels') }}"><span class="footer-flagship__dot"></span>NeTGStat — каталог каналов</a>
                        <a class="footer-flagship" href="{{ route('affpapa.nemail') }}"><span class="footer-flagship__dot"></span>NeMail — одноразовая почта</a>
                        <a href="{{ route('affpapa.neclip') }}">NeClip — буфер обмена для Mac</a>
                        <a href="{{ route('affpapa.home') }}#bases">Отобранные базы</a>
                        <a href="{{ route('affpapa.home') }}#lists" data-open-tab="conf">Конференции</a>
                        <a href="{{ route('affpapa.home') }}#lists" data-open-tab="vac">Вакансии</a>
                    </div>
                    <div class="footer-col">
                        <h4>Экспорт данных</h4>
                        <a href="{{ route('affpapa.companies.csv') }}">Компании — <span class="mono">CSV</span></a>
                        <a href="{{ route('affpapa.people.csv') }}">Контакты — <span class="mono">CSV</span></a>
                        <a href="{{ route('affpapa.channels.csv') }}">Каталог каналов — <span class="mono">CSV</span></a>
                        <a href="{{ route('affpapa.companies.json') }}">Компании — <span class="mono">JSON</span></a>
                    </div>
                </div>
            </div>
            <div class="footer-bottom">
                <p class="footer-note mono">vacancies by <a href="https://hr.band" target="_blank" rel="noopener">hr.band</a> · conferences by <a href="https://confa.biz" target="_blank" rel="noopener">confa.biz</a> · channels &amp; admins by <a href="https://tg.observer" target="_blank" rel="noopener">tg.observer</a> · company reps by <a href="https://cpa.rip/contact-directory/" target="_blank" rel="noopener">cpa.rip</a></p>
                <p class="footer-credit">Дизайн и разработка — <a href="https://claude.com/claude-code" target="_blank" rel="noopener">Claude</a></p>
            </div>
        </div>
    </footer>

    {{-- Липкий бар подписки на канал (мобайл): всплывает после ухода hero, прячется у крупных CTA. --}}
    <div class="channel-sticky" data-channel-sticky>
        <span class="channel-sticky__text mono">свежие базы — в канале</span>
        <a class="btn btn-tg-sm channel-sticky__cta" href="https://t.me/+LXMxtKp2fEFlNDE1" target="_blank" rel="noopener">Подписаться на канал</a>
        <button class="channel-sticky__close" type="button" data-channel-close aria-label="Скрыть">&times;</button>
    </div>

    {{-- Auth-flow слит внутрь user-menu контроллера выше — отдельный скрипт больше не нужен. --}}
    @stack('scripts')
    <!-- GA4 + Yandex.Metrika: сеть не блокирует рендер (async и раньше),
         инициализацию откладываем до простоя главного потока или первого
         взаимодействия — не конкурируем с первым экраном за CPU. -->
    <script>
    (function () {
        'use strict';
        var started = false;
        function loadAnalytics() {
            if (started) return;
            started = true;

            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            window.gtag = gtag;
            gtag('js', new Date());
            gtag('config', 'G-TK3NFL2ZDF');
            var ga = document.createElement('script');
            ga.async = true;
            ga.src = 'https://www.googletagmanager.com/gtag/js?id=G-TK3NFL2ZDF';
            document.head.appendChild(ga);

            (function(m,e,t,r,i,k,a){
                m[i]=m[i]||function(){(m[i].a=m[i].a||[]).push(arguments)};
                m[i].l=1*new Date();
                for (var j = 0; j < document.scripts.length; j++) {if (document.scripts[j].src === r) { return; }}
                k=e.createElement(t),a=e.getElementsByTagName(t)[0],k.async=1,k.src=r,a.parentNode.insertBefore(k,a)
            })(window, document,'script','https://mc.yandex.ru/metrika/tag.js?id=110935639', 'ym');
            window.ym(110935639, 'init', {ssr:true, clickmap:true, ecommerce:"dataLayer", referrer: document.referrer, url: location.href, accurateTrackBounce:true, trackLinks:true});
        }

        ['pointerdown', 'keydown', 'scroll', 'touchstart'].forEach(function (ev) {
            window.addEventListener(ev, loadAnalytics, { once: true, passive: true });
        });
        if ('requestIdleCallback' in window) {
            requestIdleCallback(loadAnalytics, { timeout: 2000 });
        } else {
            setTimeout(loadAnalytics, 2000);
        }
    })();
    </script>
    <noscript><div><img src="https://mc.yandex.ru/watch/110935639" style="position:absolute; left:-9999px;" alt="" /></div></noscript>
    <!-- /Yandex.Metrika counter -->
</body>
</html>
