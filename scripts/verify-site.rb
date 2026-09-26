#!/usr/bin/env ruby
# Local coherence gate only. Remote assets must be independently fetched and
# byte-checked before publishing a site update.
require 'json'
require 'date'
require 'rexml/document'
root = ARGV.empty? ? File.expand_path('..', __dir__) : File.expand_path(ARGV.fetch(0))
docs = File.join(root, 'docs')
data = %w[version project changelog backlog].to_h do |name|
  [name, JSON.parse(File.read(File.join(docs, "#{name}.json")))]
end
version = data.fetch('version')
project = data.fetch('project')
html = File.read(File.join(docs, 'index.html'))
readme = File.read(File.join(root, 'README.md'))
def size_present?(content, formatted_size)
  russian_size = formatted_size.tr(',', ' ')
  content.include?("#{formatted_size} bytes") ||
    content.include?("#{russian_size} байта") ||
    content.include?("#{russian_size} байт")
end
abort 'invalid public version' unless version.fetch('version').match?(/\A\d+\.\d+\.\d+\z/)
abort 'invalid public build' unless version.fetch('build').is_a?(Integer) && version['build'] > 0
source_commit = version.fetch('sourceCommit')
abort 'invalid source commit' unless source_commit.match?(/\A[0-9a-f]{40}\z/)
abort 'public artifact not released' unless version.fetch('status') == 'released'
abort 'invalid checksum' unless version.fetch('sha256').match?(/\A[0-9a-f]{64}\z/)
abort 'invalid public size' unless version.fetch('sizeBytes').is_a?(Integer) && version['sizeBytes'] > 0
expected = "https://github.com/AffPapa/neclip/releases/download/v#{version['version']}/NeClip-#{version['version']}.dmg"
abort 'checksum URL mismatch' unless version.fetch('checksum') == "#{expected}.sha256"
abort 'release page mismatch' unless version.fetch('releasePage') == "https://github.com/AffPapa/neclip/releases/tag/v#{version['version']}"
abort 'download mismatch' unless version.fetch('release') == expected && html.include?("href=\"#{expected}\"")
archive = version['appArchive']
expected_archive = "https://github.com/AffPapa/neclip/releases/download/v#{version['version']}/NeClip-#{version['version']}.zip"
if archive
  abort 'invalid public archive' unless archive.is_a?(Hash)
  expected_archive_page = "https://github.com/AffPapa/neclip/releases/tag/v#{version['version']}"
  abort 'archive URL mismatch' unless archive.fetch('release') == expected_archive
  abort 'archive page mismatch' unless archive.fetch('releasePage') == expected_archive_page && html.include?(expected_archive_page) && readme.include?(expected_archive_page)
  abort 'archive checksum URL mismatch' unless archive.fetch('checksum') == "#{expected_archive}.sha256"
  abort 'invalid archive checksum' unless archive.fetch('sha256').match?(/\A[0-9a-f]{64}\z/)
  abort 'invalid archive size' unless archive.fetch('sizeBytes').is_a?(Integer) && archive['sizeBytes'].positive?
  DateTime.iso8601(archive.fetch('publishedAt'))
  abort 'archive download mismatch' unless html.include?("href=\"#{expected_archive}\"") && readme.include?(expected_archive)
  archive_size = archive.fetch('sizeBytes').to_s.reverse.scan(/.{1,3}/).join(',').reverse
  abort 'site archive checksum mismatch' unless html.include?(archive.fetch('sha256')) && readme.include?(archive.fetch('sha256'))
  abort 'site archive size mismatch' unless size_present?(html, archive_size) && size_present?(readme, archive_size)
  evidence = File.read(File.join(docs, "RELEASE-#{version['version']}-STATUS.md"))
  abort 'archive evidence mismatch' unless [expected_archive, expected_archive_page, archive.fetch('sha256'), "#{archive_size} bytes"].all? { |value| evidence.include?(value) }
end
readme_size = version.fetch('sizeBytes').to_s.reverse.scan(/.{1,3}/).join(',').reverse
published_at = DateTime.iso8601(version.fetch('publishedAt'))
readme_date = published_at.strftime('%-d %B %Y')
russian_months = %w[января февраля марта апреля мая июня июля августа сентября октября ноября декабря]
russian_readme_date = "#{published_at.day} #{russian_months.fetch(published_at.month - 1)} #{published_at.year} года"
version_en = "**#{version['version']} (build #{version.fetch('build')})**"
version_ru = "**NeClip #{version['version']} (сборка #{version.fetch('build')})**"
abort 'README version mismatch' unless readme.include?(version_en) || readme.include?(version_ru)
date_en = "released on #{readme_date}."
date_ru = "Дата выпуска — #{russian_readme_date}."
abort 'README release date mismatch' unless readme.include?(date_en) || readme.include?(date_ru)
abort 'README release evidence mismatch' unless readme.include?("docs/RELEASE-#{version['version']}-STATUS.md")
abort 'README download mismatch' unless readme.include?(expected)
abort 'README size mismatch' unless size_present?(readme, readme_size)
abort 'README checksum mismatch' unless readme.include?(version.fetch('sha256'))
if archive
  expected_archive_urls = [expected_archive, "#{expected_archive}.sha256"].sort
  html_archive_urls = html.scan(%r{href="(https://github\.com/AffPapa/neclip/releases/download/[^"]+\.zip(?:\.sha256)?)"}).flatten.uniq.sort
  readme_archive_urls = readme.scan(%r{https://github\.com/AffPapa/neclip/releases/download/[^\s)]+\.zip(?:\.sha256)?}).uniq.sort
  abort 'unexpected archive URL' unless html_archive_urls == expected_archive_urls
  abort 'README archive URL mismatch' unless readme_archive_urls == expected_archive_urls
else
  abort 'public manifest advertises unavailable ZIP' if html.match?(%r{href="https://github\.com/AffPapa/neclip/releases/download/[^"]+\.zip(?:\.sha256)?})
  abort 'README advertises unavailable ZIP' if readme.match?(%r{https://github\.com/AffPapa/neclip/releases/download/[^\s)]+\.zip(?:\.sha256)?})
end
abort 'README source mismatch' unless readme.include?(source_commit)
abort 'site checksum mismatch' unless html.include?(version.fetch('sha256'))
abort 'site source mismatch' unless html.include?(source_commit)
abort 'site size mismatch' unless size_present?(html, readme_size)
plist = REXML::Document.new(File.read(File.join(root, 'Resources', 'Info.plist')))
info = plist.elements['plist/dict'].elements.to_a.each_slice(2).to_h { |key, value| [key.text, value.text] }
candidate = project.fetch('sourceCandidate')
abort 'bundle/candidate mismatch' unless info['CFBundleShortVersionString'] == candidate.fetch('version') && info['CFBundleVersion'] == candidate.fetch('build').to_s
if candidate.fetch('status') == 'released'
  abort 'released candidate mismatch' unless candidate.fetch('version') == version['version'] && candidate.fetch('build') == version['build']
  abort 'candidate source mismatch' unless candidate.fetch('sourceCommit') == source_commit
end
abort 'public/candidate mismatch' unless project.fetch('sourceCandidate').fetch('publicVersion') == version['version']
changelog = data.fetch('changelog').fetch('versions')
abort 'missing candidate record' unless changelog.any? { |v| v['version'] == project['sourceCandidate']['version'] }
abort 'stale changelog head' unless changelog.first.fetch('version') == version['version']
abort 'changelog build mismatch' unless changelog.first.fetch('build') == version['build']
abort 'obsolete public changelog entry' unless changelog.count { |entry| entry['status'] == 'released' } == 1
evidence = File.read(File.join(docs, "RELEASE-#{version['version']}-STATUS.md"))
abort 'release evidence mismatch' unless [source_commit, version['sha256'], "#{readme_size} bytes"].all? { |value| evidence.include?(value) }
backlog = data.fetch('backlog').fetch('currentRelease')
abort 'backlog version mismatch' unless backlog.fetch('version') == version['version']
abort 'backlog build mismatch' unless backlog.fetch('build') == version['build']
abort 'backlog download mismatch' unless backlog.fetch('release') == expected
if archive
  abort 'backlog archive mismatch' unless backlog.fetch('appArchive') == expected_archive
else
  abort 'backlog advertises unavailable archive' if backlog.key?('appArchive')
end
abort 'backlog evidence mismatch' unless backlog.fetch('evidence').end_with?("RELEASE-#{version['version']}-STATUS.md")
roadmap = File.read(File.join(root, 'BACKLOG.md'))
abort 'roadmap version mismatch' unless roadmap.include?("Current public release — #{version['version']} / build #{version['build']}")
abort 'roadmap download mismatch' unless roadmap.include?(expected)
abort 'roadmap archive mismatch' if archive && !roadmap.include?(expected_archive)
abort 'roadmap evidence mismatch' unless roadmap.include?("docs/RELEASE-#{version['version']}-STATUS.md")
abort 'missing title/h1' unless html.scan(/<title>/).size == 1 && html.scan(/<h1>/).size == 1
abort 'missing description' unless html.include?('<meta name="description" content="')
abort 'wrong canonical' unless html.include?('<link rel="canonical" href="https://affpapa.github.io/neclip/">')
abort 'wrong OpenGraph URL' unless html.include?('<meta property="og:url" content="https://affpapa.github.io/neclip/">')
abort 'unexpected noindex' if html.match?(/<meta[^>]+noindex/i)
html.scan(/href="([^"#]+)"/).flatten.each do |href|
  next if href.start_with?('https://', 'http://')
  target = File.join(docs, href.split('#').first)
  target = File.join(target, 'index.html') if File.directory?(target)
  abort "missing local link: #{href}" unless File.file?(target)
end
Dir.glob(File.join(root, '**', '*.md')).reject { |path| path.include?('/.build') || path.include?('/dist/') }.each do |path|
  File.read(path).scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |href|
    next if href.start_with?('https://', 'http://', '#', 'mailto:')
    target = File.expand_path(href.split('#').first, File.dirname(path))
    abort "missing Markdown link: #{href}" unless File.exist?(target)
  end
end
puts "PASS: release #{version['version']} manifest, source #{project['sourceCandidate']['version']}, metadata and local links (remote asset availability not tested)"
