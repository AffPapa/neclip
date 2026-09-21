#!/usr/bin/env ruby
require 'json'
require 'rexml/document'
require 'uri'
require 'cgi'
require 'set'

root = ARGV.empty? ? File.expand_path('..', __dir__) : File.expand_path(ARGV.fetch(0))
docs = File.join(root, 'docs')
base = 'https://affpapa.github.io/neclip/'
sitemap = REXML::Document.new(File.read(File.join(docs, 'sitemap.xml')))
urls = REXML::XPath.match(sitemap, '//*[local-name()="loc"]').map(&:text)
abort 'sitemap must contain five unique editorial pages' unless urls.length == 5 && urls.uniq.length == 5
pages = {}
titles = Set.new
descriptions = Set.new
headings = Set.new
urls.each do |url|
  abort 'sitemap URL outside canonical project' unless url.start_with?(base)
  relative = url.delete_prefix(base)
  relative = 'index.html' if relative.empty?
  path = File.expand_path(relative, docs)
  abort 'sitemap path escapes docs' unless path.start_with?(docs + '/')
  abort "missing sitemap page #{relative}" unless File.file?(path)
  html = File.read(path)
  abort "wrong language: #{relative}" unless html.include?('<html lang="ru">')
  abort "indexable page is noindex: #{relative}" if html.match?(/<meta[^>]+(?:noindex|nofollow)/i)
  abort "local machine path in public HTML: #{relative}" if html.match?(%r{/(?:Users|private/tmp|var/folders)/})
  title = html.scan(/<title>(.*?)<\/title>/m).flatten
  h1 = html.scan(/<h1[^>]*>(.*?)<\/h1>/m).flatten
  meta = html.scan(/<meta\s+(?:name|property)="([^"]+)"\s+content="([^"]*)"\s*\/?\s*>/).to_h
  canonical = html.scan(/<link\s+rel="canonical"\s+href="([^"]+)"/).flatten
  abort "title/H1/canonical count: #{relative}" unless title.length == 1 && h1.length == 1 && canonical == [url]
  heading = CGI.unescapeHTML(h1.first.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip)
  abort "duplicate title: #{relative}" unless titles.add?(title.first)
  abort "duplicate H1: #{relative}" unless headings.add?(heading)
  description = meta['description']
  abort "missing/duplicate description: #{relative}" unless description && description.length.between?(70, 220) && descriptions.add?(description)
  %w[og:title og:description og:type twitter:card twitter:title twitter:description].each do |key|
    abort "missing #{key}: #{relative}" if meta[key].to_s.empty?
  end
  abort "OG canonical mismatch: #{relative}" unless meta['og:url'] == url
  abort "missing accessible landmarks: #{relative}" unless html.include?('<main') && html.include?('id="main"') && html.include?('class="skip-link"')
  scripts = html.scan(/<script type="application\/ld\+json">(.*?)<\/script>/m).flatten
  abort "missing JSON-LD: #{relative}" if scripts.empty?
  entities = scripts.flat_map { |body| parsed = JSON.parse(body); parsed.fetch('@graph', [parsed]) }
  abort "unsubstantiated rating/review: #{relative}" if entities.any? { |node| %w[Review AggregateRating Offer].include?(node['@type']) || node.key?('aggregateRating') }
  if relative == 'index.html'
    manifest = JSON.parse(File.read(File.join(docs, 'version.json')))
    app = entities.find { |node| node['@type'] == 'SoftwareApplication' }
    abort 'application schema version mismatch' unless app && app['softwareVersion'] == manifest['version'] && app['url'] == url
  else
    crumbs = entities.find { |node| node['@type'] == 'BreadcrumbList' }
    abort "missing visible breadcrumbs: #{relative}" unless html.include?('aria-label="Хлебные крошки"') && crumbs
    abort "breadcrumb URL mismatch: #{relative}" unless crumbs.fetch('itemListElement').last.fetch('item') == url
    entity = entities.find { |node| %w[Article CollectionPage].include?(node['@type']) }
    abort "schema/content mismatch: #{relative}" unless entity && entity['url'] == url && entity['inLanguage'] == 'ru'
    if entity['@type'] == 'Article'
      abort "article headline mismatch: #{relative}" unless entity['headline'] == heading
      # Inspect the known static article, not a sanitized/re-emitted HTML
      # document. Head metadata, scripts and site navigation are not content.
      article = html[/<main\b[^>]*>(.*?)<\/main>/im, 1]
      abort "missing static article: #{relative}" unless article && !article.match?(/<script\b/i)
      text_nodes = article.scan(/>([^<>]+)</m).flatten
      words = CGI.unescapeHTML(text_nodes.join(' ')).split.length
      abort "thin article: #{relative}" unless words >= 300
    end
  end
  pages[url] = html
end

linked = Set.new
pages.each do |url, html|
  html.scan(/(?:href|src)="([^"]+)"/).flatten.each do |href|
    next if href.start_with?('mailto:')
    resolved = URI.join(url, CGI.unescapeHTML(href))
    next unless resolved.host == 'affpapa.github.io'
    abort "link outside project: #{href}" unless resolved.path.start_with?('/neclip/')
    relative = URI::DEFAULT_PARSER.unescape(resolved.path.delete_prefix('/neclip/'))
    relative += 'index.html' if relative.empty? || relative.end_with?('/')
    target = File.expand_path(relative, docs)
    abort "missing internal link: #{href}" unless target.start_with?(docs + '/') && File.file?(target)
    if resolved.fragment && target.end_with?('.html')
      target_html = File.read(target)
      abort "missing fragment: #{href}" unless target_html.include?("id=\"#{resolved.fragment}\"")
    end
    resolved.fragment = nil
    linked.add(resolved.to_s) unless resolved.to_s == url
  end
end
abort 'orphan editorial page' unless (urls - [base]).all? { |url| linked.include?(url) }
products = pages.fetch(base + 'compare.html').scan(/data-product="([^"]+)"/).flatten
abort 'comparison must list exactly twenty unique products' unless products.length == 20 && products.uniq.length == 20
%w[2026-09-21 рейтинг официальн].each do |marker|
  abort "missing comparison methodology: #{marker}" unless pages.fetch(base + 'compare.html').include?(marker)
end
llms = File.read(File.join(docs, 'llms.txt'))
abort 'llms missing editorial URLs' unless urls.all? { |url| llms.include?(url) }
abort 'project sitemap discovery missing' unless File.read(File.join(docs, 'robots.txt')).include?("Sitemap: #{base}sitemap.xml")
puts "PASS: #{urls.length} canonical pages, unique metadata, JSON-LD parity, local links/fragments, 20 sourced alternatives and discovery files"
