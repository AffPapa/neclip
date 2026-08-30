<?php

namespace App\Http\Controllers\Affpapa;

use App\Http\Controllers\Controller;
use App\Models\AffpapaCompany;
use App\Models\AffpapaCurated;
use App\Models\AffpapaPerson;
use App\Models\NeBlask\Brand as NeBlaskBrand;
use App\Models\NeBlask\Country as NeBlaskCountry;
use App\Models\NeBlask\Game as NeBlaskGame;
use App\Models\NeBlask\Provider as NeBlaskProvider;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Cache;

class MetaController extends Controller
{
    /** robots.txt: явно пускаем поисковых и AI-краулеров (GEO). */
    public function robots(): Response
    {
        $aiBots = ['GPTBot', 'OAI-SearchBot', 'ChatGPT-User', 'ClaudeBot', 'Claude-Web', 'anthropic-ai', 'PerplexityBot', 'Perplexity-User', 'Google-Extended', 'Applebot-Extended', 'Bytespider', 'CCBot', 'Amazonbot', 'Meta-ExternalAgent'];

        $lines = ['User-agent: *', 'Allow: /', ''];
        foreach ($aiBots as $bot) {
            $lines[] = 'User-agent: '.$bot;
            $lines[] = 'Allow: /';
            $lines[] = '';
        }
        $lines[] = 'Sitemap: https://affpapa.org/sitemap.xml';

        return response(implode("\n", $lines)."\n", 200)->header('Content-Type', 'text/plain; charset=utf-8');
    }

    public function sitemap(): Response
    {
        $lastmod = Cache::remember('affpapa.sitemap.lastmod', 600, function (): string {
            $t = AffpapaCompany::query()->max('updated_at') ?? AffpapaPerson::query()->max('updated_at');

            return \Illuminate\Support\Carbon::parse($t ?: now())->toAtomString();
        });

        // Профили каналов: топ-200 по охвату — тонкие карточки за пределом
        // не раздуваем в карте (у остальных всё равно есть каталог как хаб).
        $channelUrls = Cache::remember('affpapa.sitemap.channels', 600, function (): array {
            return \App\Models\AffpapaChannel::query()->published()->core()
                ->orderByRaw('avg_reach desc nulls last')->orderByDesc('subscribers')
                ->limit(200)->pluck('username')
                ->map(fn (string $u): string => 'https://affpapa.org/channels/'.$u)->all();
        });

        // Индексируемая HTML-страница + data-feed'ы для обнаружения датасетов.
        $urls = array_merge([
            'https://affpapa.org/',
            'https://affpapa.org/necard',
            'https://affpapa.org/neagent',
            'https://affpapa.org/neantik',
            'https://affpapa.org/nemail',
            'https://affpapa.org/neahrefs',
            'https://affpapa.org/neclip',
            'https://affpapa.org/channels',
            'https://affpapa.org/channels.csv',
            'https://affpapa.org/channels.json',
        ], $channelUrls, [
            'https://affpapa.org/companies.csv',
            'https://affpapa.org/companies.json',
            'https://affpapa.org/people.csv',
            'https://affpapa.org/people.json',
            'https://affpapa.org/members.csv',
            'https://affpapa.org/bases/clevel-all.csv',
            'https://affpapa.org/bases/tg-channels.csv',
            'https://affpapa.org/bases/cparip.csv',
            'https://affpapa.org/bases/teams.csv',
        ]);

        // NeBlask — индекс спроса iGaming (86 брендов, 15 стран, игры, провайдеры, отчёты)
        $neblaskBrands = Cache::remember('affpapa.sitemap.neblask_brands', 600, function (): array {
            return NeBlaskBrand::orderBy('name')->pluck('slug')
                ->map(fn (string $s): string => 'https://affpapa.org/neblask/brand/'.$s)->all();
        });
        $neblaskCountries = Cache::remember('affpapa.sitemap.neblask_countries', 600, function (): array {
            return NeBlaskCountry::pluck('code')
                ->map(fn (string $c): string => 'https://affpapa.org/neblask/country/'.$c)->all();
        });
        $neblaskGames = Cache::remember('affpapa.sitemap.neblask_games', 600, function (): array {
            return NeBlaskGame::pluck('slug')
                ->map(fn (string $s): string => 'https://affpapa.org/neblask/game/'.$s)->all();
        });
        $neblaskProviders = Cache::remember('affpapa.sitemap.neblask_providers', 600, function (): array {
            return NeBlaskProvider::pluck('slug')
                ->map(fn (string $s): string => 'https://affpapa.org/neblask/provider/'.$s)->all();
        });
        $neblaskReports = collect(array_keys((array) config('neblask_reports', [])))
            ->map(fn ($k) => config("neblask_reports.{$k}.slug"))
            ->filter()
            ->map(fn (string $s): string => 'https://affpapa.org/neblask/reports/'.$s)->all();

        $urls = array_merge($urls, [
            'https://affpapa.org/neblask',
            'https://affpapa.org/neblask/brands',
            'https://affpapa.org/neblask/markets',
            'https://affpapa.org/neblask/games',
            'https://affpapa.org/neblask/providers',
            'https://affpapa.org/neblask/regulators',
            'https://affpapa.org/neblask/reports',
            'https://affpapa.org/neblask/compare',
            'https://affpapa.org/neblask/heatmap',
            'https://affpapa.org/neblask/trends',
            'https://affpapa.org/neblask/opportunities',
            'https://affpapa.org/neblask/radar',
            'https://affpapa.org/neblask/methodology',
            'https://affpapa.org/neblask/changelog',
            'https://affpapa.org/neblask/licenses.json',
            'https://affpapa.org/neblask/licenses.csv',
            'https://affpapa.org/neblask/data/brands.json',
            'https://affpapa.org/neblask/data/regulators.json',
        ],
            ['loc' => '/neblask/brand-radar', 'changefreq' => 'daily', 'priority' => '0.7'], $neblaskBrands, $neblaskCountries, $neblaskGames, $neblaskProviders, $neblaskReports);

        $items = implode("\n", array_map(
            fn (string $u): string => '    <url><loc>'.$u.'</loc><lastmod>'.$lastmod.'</lastmod></url>',
            $urls
        ));

        $body = '<?xml version="1.0" encoding="UTF-8"?>'."\n"
            .'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'."\n"
            .$items."\n"
            .'</urlset>';

        return response($body, 200)->header('Content-Type', 'application/xml; charset=utf-8');
    }

    /** llms.txt — карта сайта для AI-краулеров (ChatGPT, Perplexity, Gemini, Claude). */
    public function llms(): Response
    {
        $body = Cache::remember('affpapa.llms', 900, function (): string {
            $prog = AffpapaCompany::query()->published()->where('category', 'program')->count();
            $net = AffpapaCompany::query()->published()->where('category', 'network')->count();
            $svc = AffpapaCompany::query()->published()->where('category', 'service')->count();
            $ppl = AffpapaPerson::query()->published()->count();
            $clevel = AffpapaCurated::query()->where('dataset', 'like', 'clevel-%')->count();
            $org = AffpapaCurated::query()->dataset('organizers')->count();
            $tg = AffpapaCurated::query()->dataset('tg-channels')->count();
            $catalog = \App\Models\AffpapaChannel::query()->published()->core()->count();
            $reps = AffpapaCurated::query()->dataset('cparip')->count();
            $teams = AffpapaCurated::query()->dataset('teams')->count();
            $members = \App\Models\AffpapaMember::count();

            return <<<TXT
# AffPapa

> AffPapa — бесплатные базы контактов affiliate-маркетинга, CPA и арбитража трафика, временная почта на 11 доменах и вечеринки AffPapa Party. Все базы скачиваются в CSV и JSON без регистрации.

## Базы контактов (скачать бесплатно)

- [База партнёрских программ](https://affpapa.org/companies.csv?category=program) — {$prog} affiliate-программ с контактами менеджеров.
- [База CPA- и affiliate-сетей](https://affpapa.org/companies.csv?category=network) — {$net} сетей.
- [База сервисов и инструментов](https://affpapa.org/companies.csv?category=service) — {$svc} сервисов для арбитража.
- [Контакты людей индустрии](https://affpapa.org/people.csv) — {$ppl} персон (telegram, почта, соцсети).
- [C-level контакты](https://affpapa.org/bases/clevel-all.csv) — {$clevel} руководителей affiliate/iGaming (CEO, Founder, COO, CBDO, CCO, CPO, CFO).
- [Организаторы конференций](https://affpapa.org/bases/organizers.csv) — {$org} контактов.
- [Контакты представителей компаний](https://affpapa.org/bases/cparip.csv) — {$reps} представителей компаний: телеграм, компания, роль, направление.
- [Админы Telegram-каналов для рекламы](https://affpapa.org/bases/tg-channels.csv) — {$tg} каналов с контактами владельцев.
- [Каталог Telegram-каналов с ценами на рекламу](https://affpapa.org/channels) — {$catalog} каналов affiliate-тематики: подписчики, охват за 30 дней, цена, CPM, контакт админа. CSV: https://affpapa.org/channels.csv
- [Арбитражные команды](https://affpapa.org/bases/teams.csv) — {$teams} команд с промокодами и контактами (HR, байеры, овнеры).
- [Зарегистрированные на Партнёркине](https://affpapa.org/members.csv) — {$members} юзеров портала Партнёркин.

## Факты и цифры (актуально)

- В открытых базах: {$prog} партнёрских программ, {$net} CPA-/affiliate-сетей, {$svc} сервисов.
- Контактов людей индустрии: {$ppl}. C-level руководителей: {$clevel}. Представителей компаний: {$reps}.
- Админов Telegram-каналов для рекламы: {$tg}. Каналов в каталоге с метриками и ценами: {$catalog}. Арбитражных команд: {$teams}. Юзеров Партнёркина: {$members}.
- Все базы бесплатны, без регистрации, форматы CSV и JSON. Временная почта — на 11 доменах affpapa.*

## Канал

Свежие базы и приватные контакты, которых нет на сайте, — в закрытом Telegram-канале «Вот такая вот хуйня, собачка»: https://t.me/+LXMxtKp2fEFlNDE1 (вход бесплатный).

## Инструменты и разделы

- [NeCard — виртуальные карты для арбитража](/necard) — 50+ BIN-ов из 6 стран, 0% декалин, 1% на USDT, первые 100 карт бесплатно. Форма заявки на сайте.
- [NeAgent — агентские рекламные кабинеты](/neagent) — агентские аккаунты Facebook, Google, TikTok и 10+ платформ. Сравнение провайдеров, подбор под задачи, комиссии от 2.5%.
- [NeAntik — антидетект-браузер NeVision для Mac](/neantik) — нативный менеджер браузерных профилей для Apple Silicon. Изолированные сессии, прокси, локальное хранение, встроенная проверка fingerprint A→B→A. SwiftUI, без Electron, без облака, без аккаунта.
- [NeMail — одноразовая почта](/nemail) — бесплатный одноразовый email на 11 доменах affpapa.*, автоподхват OTP-кодов, sandboxed iframe, без регистрации.
- [NeAhrefs — бесплатный SEO-мониторинг](/neahrefs) — self-hosted альтернатива Ahrefs/Semrush на базе CrawlSEO. GSC-аналитика, краулер 2000 стр., Core Web Vitals, rank tracking, бэклинки, каннибализация. Open-source (MIT), ваш сервер.
- [NeClip — менеджер буфера обмена для Mac](/neclip) — бесплатный нативный clipboard manager для Apple Silicon: история копирований (текст, картинки, файлы), хоткей Cmd+Shift+V, автовставка, живой поиск. SQLite локально, ноль телеметрии, open source (MIT), DMG ~2 MB.
- Вечеринки AffPapa Party — пре-пати и afterparty вокруг ключевых конференций индустрии.

## NeBlask — бесплатная аналитика спроса iGaming

- [NeBlask — индекс спроса](https://affpapa.org/neblask) — открытая аналитика: поисковый спрос 86 iGaming-брендов по 15 странам, доля рынка, тренды, прогнозы.
- [Бренды](https://affpapa.org/neblask/brands) — все 86 брендов с метриками спроса, рекламы, стримов, on-chain данных.
- [Рынки](https://affpapa.org/neblask/markets) — 15 стран: объём, рост, топ-бренды.
- [Игры](https://affpapa.org/neblask/games) — 902 слот-игр с данными спроса.
- [Провайдеры](https://affpapa.org/neblask/providers) — 52 провайдера игр.
- [Регуляторы](https://affpapa.org/neblask/regulators) — UKGC, MGA, DGA, SGA, KSA, CGA с живыми данными лицензий.
- [Отчёты](https://affpapa.org/neblask/reports) — страновые аналитические отчёты (Brazil, Italy, UK, Germany, Sweden).
- [Heatmap](https://affpapa.org/neblask/heatmap) — тепловая карта присутствия брендов по странам.
- [GEO Trends](https://affpapa.org/neblask/trends) — тренды спроса по странам: рост/падение, сезонность, top movers.
- [SEO Opportunities](https://affpapa.org/neblask/opportunities) — точки роста: бренды с низкой видимостью и высоким потенциалом.
- [Game Radar](https://affpapa.org/neblask/radar) — 902 слот-релиза от 52 провайдеров: RTP, волатильность, даты.
- [Brand Radar](https://affpapa.org/neblask/brand-radar) — пульс рынка: рост/спад брендов MoM, trust scores, лицензии, домены.
- [Сравнение](https://affpapa.org/neblask/compare) — сравнение 2-3 брендов рядом.
- [Методология](https://affpapa.org/neblask/methodology) — как считаются метрики, источники данных.
- [Changelog](https://affpapa.org/neblask/changelog) — история изменений.
- Данные: лицензии [JSON](https://affpapa.org/neblask/licenses.json), [CSV](https://affpapa.org/neblask/licenses.csv); бренды [JSON](https://affpapa.org/neblask/data/brands.json); регуляторы [JSON](https://affpapa.org/neblask/data/regulators.json).

## О чём этот сайт (ключевые темы)

Базы affiliate marketing, базы для affiliate-менеджеров, база контактов CPA-сетей и партнёрок, контакты C-level в iGaming, база владельцев Telegram-каналов для закупки рекламы, база организаторов конференций, временная (одноразовая) почта для арбитража трафика.

## Источники данных

Вакансии — hr.band. Конференции — confa.biz. Администраторы каналов — tg.observer. Контакты представителей компаний — cpa.rip.
TXT;
        });

        return response($body, 200)->header('Content-Type', 'text/plain; charset=utf-8');
    }
}