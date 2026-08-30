<?php

use App\Http\Controllers\AffpapaBotController;
use App\Http\Controllers\Affpapa\AdController;
use App\Http\Controllers\Affpapa\AdSubmitController;
use App\Http\Controllers\Affpapa\TgAuthController;
use App\Http\Controllers\Affpapa\ChannelController;
use App\Http\Controllers\Affpapa\CompanyController;
use App\Http\Controllers\Affpapa\ConferenceController;
use App\Http\Controllers\Affpapa\CuratedController;
use App\Http\Controllers\Affpapa\PeopleController;
use App\Http\Controllers\Affpapa\HomeController;
use App\Http\Controllers\Affpapa\MemberController;
use App\Http\Controllers\Affpapa\NeBlaskController;
use App\Http\Controllers\Affpapa\SponsorController;
use App\Http\Controllers\Affpapa\TabController;
use App\Http\Controllers\Affpapa\MetaController;
use App\Http\Controllers\Affpapa\NeCardController;
use App\Http\Controllers\Affpapa\NeAgentController;
use App\Http\Controllers\Affpapa\NeAntikController;
use App\Http\Controllers\Affpapa\NeMailController;
use App\Http\Controllers\Affpapa\NeAhrefsController;
use App\Http\Controllers\Affpapa\NeClipController;
use Illuminate\Support\Facades\Route;

/*
 * Доменный сегмент affpapa.org (вечеринки AffPapa Party + каталог компаний
 * + временная почта + зеркальный каталог вакансий hr.band).
 *
 * ВАЖНО: этот файл регистрируется ДО routes/web.php (см. bootstrap/app.php).
 * Маршруты web.php не ограничены доменом и матчатся на любом хосте, поэтому
 * доменные роуты должны стоять первыми — иначе affpapa.org/jobs перехватил бы
 * каталог hr.band без noindex.
 */
// Домен без сессии/CSRF: чистые GET-страницы и выгрузки, форм нет (виджет
// почты живёт в routes/tempmail.php с тем же подходом). Это убирает Set-Cookie
// и открывает edge-кэширование HTML на Cloudflare.
Route::domain('affpapa.org')->name('affpapa.')->withoutMiddleware([
    \Illuminate\Cookie\Middleware\EncryptCookies::class,
    \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
    \Illuminate\Session\Middleware\StartSession::class,
    \Illuminate\View\Middleware\ShareErrorsFromSession::class,
    \Illuminate\Foundation\Http\Middleware\PreventRequestForgery::class,
])->group(function () {
    // Webhook @AffPapa_Bot. Домен уже withoutMiddleware (без сессии/CSRF),
    // POST от Telegram не словит 419. Путь держим вне CF Cache-Rule.
    Route::post('/tg/affpapa/webhook', AffpapaBotController::class)->name('tg.webhook');

    // Вход на сайт через @AffPapa_Bot (домен без сессии → своя подписанная кука).
    Route::post('/auth/tg/start', [TgAuthController::class, 'start'])->name('auth.start');
    Route::get('/auth/tg/status', [TgAuthController::class, 'status'])->name('auth.status');
    Route::get('/auth/tg/me', [TgAuthController::class, 'me'])->name('auth.me');
    Route::post('/auth/tg/logout', [TgAuthController::class, 'logout'])->name('auth.logout');

    Route::get('/', HomeController::class)->name('home')
        ->middleware('cache.headers:public;etag;max_age=60;s_maxage=300');

    // Отдельных страниц вакансий/конференций нет — уводим на первоисточники.
    Route::get('/jobs', fn () => redirect('https://hr.band/jobs', 301));
    Route::get('/jobs/{slug}', fn (string $slug) => redirect('https://hr.band/jobs/'.$slug, 301))->where('slug', '[A-Za-z0-9._-]+');
    Route::get('/conferences', fn () => redirect('https://confa.biz', 301));
    Route::get('/conferences/{slug}', fn (string $slug) => redirect('https://confa.biz/events/'.$slug, 301))->where('slug', '[A-Za-z0-9._-]+');
    Route::get('/events', fn () => redirect('https://confa.biz', 301));

    Route::get('/companies.csv', [CompanyController::class, 'csv'])->name('companies.csv')->middleware('cache.headers:public;max_age=300;s_maxage=600');
    Route::get('/companies.json', [CompanyController::class, 'json'])->name('companies.json')->middleware('cache.headers:public;max_age=300;s_maxage=600');
    Route::redirect('/companies', '/#download', 301);

    // База компаний AffPapa (статический CSV/JSON из старого портала).
    Route::get("/affpapa-contacts.csv", function () {
        $path = storage_path("app/companies-contacts.csv");
        abort_unless(is_file($path), 404);
        return response("\xEF\xBB\xBF" . file_get_contents($path), 200, [
            "Content-Type" => "text/csv; charset=utf-8",
            "Content-Disposition" => "attachment; filename=\"affpapa-contacts.csv\"",
        ]);
    })->name("contacts.csv")->middleware("cache.headers:public;max_age=300;s_maxage=600");
    Route::get("/affpapa-contacts.json", function () {
        $path = storage_path("app/companies-contacts.json");
        abort_unless(is_file($path), 404);
        return response(file_get_contents($path), 200, [
            "Content-Type" => "application/json; charset=utf-8",
        ]);
    })->name("contacts.json")->middleware("cache.headers:public;max_age=300;s_maxage=600");

    Route::get('/people.csv', [PeopleController::class, 'csv'])->name('people.csv')->middleware('cache.headers:public;max_age=300;s_maxage=600');
    Route::get('/people.json', [PeopleController::class, 'json'])->name('people.json')->middleware('cache.headers:public;max_age=300;s_maxage=600');
    Route::redirect('/people', '/#download', 301);

    // Каталог Telegram-каналов для рекламы (снимок tg.observer): страница + выгрузки.
    Route::get('/channels', [ChannelController::class, 'index'])->name('channels')->middleware('cache.headers:public;etag;max_age=300;s_maxage=600');
    Route::get('/channels.csv', [ChannelController::class, 'csv'])->name('channels.csv')->middleware('cache.headers:public;max_age=300;s_maxage=600');
    Route::get('/channels.json', [ChannelController::class, 'json'])->name('channels.json')->middleware('cache.headers:public;max_age=300;s_maxage=600');
    // Профиль канала: паспорт с графиками. where не даёт перехватить .csv/.json.
    Route::get('/channels/{username}', [ChannelController::class, 'show'])->name('channels.show')->where('username', '[A-Za-z][A-Za-z0-9_]{3,31}')->middleware('cache.headers:public;etag;max_age=300;s_maxage=1800');


    // Отобранные базы (C-level/организаторы/PR) — скачивание оригинала и CSV.
    Route::get('/bases/{dataset}', [CuratedController::class, 'download'])->name('bases.download')->where('dataset', '[a-z0-9-]+')->middleware('cache.headers:public;max_age=3600;s_maxage=3600');
    Route::get('/bases/{dataset}.csv', [CuratedController::class, 'csv'])->name('bases.csv')->where('dataset', '[a-z0-9-]+')->middleware('cache.headers:public;max_age=300;s_maxage=600');


    // Доменные robots/sitemap. Для affpapa.org статика public/robots.txt
    // не отдаётся: в Caddy стоит rewrite /robots.txt -> index.php.
    Route::get('/members.json', [MemberController::class, 'json'])->name('members.json')->middleware('cache.headers:public;max_age=300;s_maxage=600');
    Route::get('/members.csv', [MemberController::class, 'csv'])->name('members.csv')->middleware('cache.headers:public;max_age=300;s_maxage=600');

    // Ленивая подгрузка строк таба главной (HTML-фрагмент). CF кэширует на эдже.
    Route::get('/bases/tab/{key}', [TabController::class, 'show'])->name('tab')->where('key', '[a-z0-9-]+')->middleware('cache.headers:public;max_age=600;s_maxage=3600');

    // Permalink одного объявления доски (noindex во вьюхе).
    Route::get('/ads/{ad}', [AdController::class, 'show'])->name('ads.show')->where('ad', '[0-9]+');

    // Приём объявления из веб-формы. Домен без сессии/CSRF: защита в контроллере
    // (honeypot + timetrap + IP-hash rate-limit + обязательный Telegram).
    Route::post('/ads', [AdSubmitController::class, 'store'])->name('ads.store');

    // NeBlask — индекс спроса iGaming (пока служебный статус, noindex).
    Route::get('/neblask', [NeBlaskController::class, 'index'])->name('neblask')->middleware('cache.headers:public;max_age=600;s_maxage=3600');
    // Beacon от sponsors-партиала: view/click/copy. Без сессии/CSRF, защита Origin+IP-hash-RL в контроллере.
    Route::post('/neblask/sponsor-hit', [SponsorController::class, 'hit'])->name('neblask.sponsor.hit');
    // Закрытый дашборд статистики (basic-auth через NEBLASK_STATS_USER/PASS в .env; иначе 404).
    Route::get('/neblask/sponsor-stats', [SponsorController::class, 'stats'])->name('neblask.sponsor.stats');
    Route::get('/neblask/sponsor-stats.csv', [SponsorController::class, 'statsCsv'])->name('neblask.sponsor.stats.csv');
    Route::get('/neblask.json', [NeBlaskController::class, 'status'])->name('neblask.json')->middleware('cache.headers:public;max_age=120;s_maxage=300');
    Route::get('/neblask/methodology', [NeBlaskController::class, 'methodology'])->name('neblask.methodology')->middleware('cache.headers:public;max_age=3600;s_maxage=3600');
    Route::get('/neblask/llms.txt', [NeBlaskController::class, 'llms'])->name('neblask.llms')->middleware('cache.headers:public;max_age=3600;s_maxage=3600');
    Route::get('/neblask/brand/{slug}', [NeBlaskController::class, 'brand'])->where('slug', '[a-z0-9-]+')->name('neblask.brand')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/country/{country}', [NeBlaskController::class, 'country'])->where('country', '[a-z]{2}')->name('neblask.country')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/brands', [NeBlaskController::class, 'brands'])->name('neblask.brands')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/markets', [NeBlaskController::class, 'markets'])->name('neblask.markets')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/games', [NeBlaskController::class, 'games'])->name('neblask.games')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/game/{slug}', [NeBlaskController::class, 'game'])->where('slug', '[a-z0-9-]+')->name('neblask.game')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/regulators', [NeBlaskController::class, 'regulators'])->name('neblask.regulators')->middleware('cache.headers:public;max_age=3600;s_maxage=3600');
    Route::get('/neblask/licenses.json', [NeBlaskController::class, 'licensesJson'])->name('neblask.licenses.json')->middleware('cache.headers:public;max_age=900;s_maxage=3600');
    Route::get('/neblask/licenses.csv', [NeBlaskController::class, 'licensesCsv'])->name('neblask.licenses.csv')->middleware('cache.headers:public;max_age=900;s_maxage=3600');
    Route::get('/neblask/data/brands.json', [NeBlaskController::class, 'seedBrands'])->name('neblask.seed.brands')->middleware('cache.headers:public;max_age=3600;s_maxage=86400');
    Route::get('/neblask/data/regulators.json', [NeBlaskController::class, 'seedRegulators'])->name('neblask.seed.regulators')->middleware('cache.headers:public;max_age=3600;s_maxage=86400');
    Route::get('/neblask/providers', [NeBlaskController::class, 'providers'])->name('neblask.providers')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/provider/{slug}', [NeBlaskController::class, 'provider'])->where('slug', '[a-z0-9-]+')->name('neblask.provider')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/reports', [NeBlaskController::class, 'reports'])->name('neblask.reports')->middleware('cache.headers:public;max_age=3600;s_maxage=3600');
    Route::get('/neblask/reports/{slug}', [NeBlaskController::class, 'report'])->where('slug', '[a-z0-9-]+')->name('neblask.report')->middleware('cache.headers:public;max_age=3600;s_maxage=3600');
    Route::get('/neblask/compare', [NeBlaskController::class, 'compare'])->name('neblask.compare')->middleware('cache.headers:public;max_age=300;s_maxage=1800');
    Route::get('/neblask/changelog', [NeBlaskController::class, 'changelog'])->name('neblask.changelog')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/changelog.json', [NeBlaskController::class, 'changelogJson'])->name('neblask.changelog.json')->middleware('cache.headers:public;max_age=1800;s_maxage=3600');
    Route::get('/neblask/heatmap', [NeBlaskController::class, 'heatmap'])->name('neblask.heatmap')->middleware('cache.headers:public;max_age=900;s_maxage=1800');
    Route::get('/neblask/trends', [NeBlaskController::class, 'trends'])->name('neblask.trends')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/radar', [NeBlaskController::class, 'radar'])->name('neblask.radar')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/brand-radar', [NeBlaskController::class, 'brandRadar'])->name('neblask.brand-radar')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/opportunities', [NeBlaskController::class, 'opportunities'])->name('neblask.opportunities')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/widget/{country}', [NeBlaskController::class, 'widget'])->where('country', '[a-z]{2}')->name('neblask.widget')->middleware('cache.headers:public;max_age=1800;s_maxage=3600');
    Route::get('/neblask/{country}.json', [NeBlaskController::class, 'feedJson'])->where('country', '[a-z]{2}')->name('neblask.feed.json')->middleware('cache.headers:public;max_age=600;s_maxage=1800');
    Route::get('/neblask/{country}.csv', [NeBlaskController::class, 'feedCsv'])->where('country', '[a-z]{2}')->name('neblask.feed.csv')->middleware('cache.headers:public;max_age=600;s_maxage=1800');

    // NeCard — виртуальные карты для арбитража (лендинг + приём заявок).
    Route::get('/necard', [NeCardController::class, 'show'])->name('necard')
        ->middleware('cache.headers:public;etag;max_age=300;s_maxage=1800');
    Route::post('/necard/apply', [NeCardController::class, 'apply'])->name('necard.apply');
    Route::post('/necard/qualify', [NeCardController::class, 'qualify'])->name('necard.qualify');

    // NeAgent — агентские рекламные кабинеты (лендинг + приём заявок).
    Route::get("/neagent", [NeAgentController::class, "show"])->name("neagent")
        ->middleware("cache.headers:public;etag;max_age=300;s_maxage=1800");
    Route::post("/neagent/apply", [NeAgentController::class, "apply"])->name("neagent.apply");

    // NeAntik — антидетект-браузер NeVision (информационная страница).
    Route::get("/neantik", [NeAntikController::class, "show"])->name("neantik")
        ->middleware("cache.headers:public;max_age=600;s_maxage=3600");

    // NeClip — менеджер буфера обмена для Mac (лендинг + раздача DMG).
    Route::get('/neclip', [NeClipController::class, 'show'])->name('neclip')
        ->middleware('cache.headers:public;max_age=600;s_maxage=3600');

    // NeMail — одноразовая почта на 11 доменах affpapa.*.
    Route::get('/nemail', [NeMailController::class, 'show'])->name('nemail')
        ->middleware('cache.headers:public;etag;max_age=300;s_maxage=1800');

    Route::redirect("/NeAhrefs", "/neahrefs", 301);
    // NeAhrefs — SEO-мониторинг на базе CrawlSEO
    Route::get('/neahrefs', [NeAhrefsController::class, 'show'])->name('neahrefs')
        ->middleware('cache.headers:public;max_age=600;s_maxage=3600');

    Route::get('/robots.txt', [MetaController::class, 'robots'])->name('robots')->middleware('cache.headers:public;max_age=3600;s_maxage=3600');
    Route::get('/sitemap.xml', [MetaController::class, 'sitemap'])->name('sitemap')->middleware('cache.headers:public;max_age=3600;s_maxage=3600');
    Route::get('/llms.txt', [MetaController::class, 'llms'])->name('llms')->middleware('cache.headers:public;max_age=900;s_maxage=900');

    // Legal pages
    Route::get('/privacy', fn() => view('affpapa.privacy'))->name('privacy')
        ->middleware('cache.headers:public;max_age=3600;s_maxage=86400');
    Route::get('/terms', fn() => view('affpapa.terms'))->name('terms')
        ->middleware('cache.headers:public;max_age=3600;s_maxage=86400');
});