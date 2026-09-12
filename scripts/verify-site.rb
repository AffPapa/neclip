#!/usr/bin/env ruby
# Read-only coherence gate: a candidate must never replace a verified download.
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
readme_size = version.fetch('sizeBytes').to_s.reverse.scan(/.{1,3}/).join(',').reverse
readme_date = DateTime.iso8601(version.fetch('publishedAt')).strftime('%-d %B %Y')
abort 'README version mismatch' unless readme.include?("**#{version['version']} (build #{version.fetch('build')})**")
abort 'README release date mismatch' unless readme.include?("released on #{readme_date}.")
abort 'README release evidence mismatch' unless readme.include?("docs/RELEASE-#{version['version']}-STATUS.md")
abort 'README download mismatch' unless readme.include?(expected)
abort 'README size mismatch' unless readme.include?("(#{readme_size} bytes)")
abort 'README checksum mismatch' unless readme.include?(version.fetch('sha256'))
abort 'README source mismatch' unless readme.include?(source_commit)
abort 'site checksum mismatch' unless html.include?(version.fetch('sha256'))
abort 'site source mismatch' unless html.include?(source_commit)
abort 'site size mismatch' unless html.include?("#{readme_size} bytes")
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
abort 'backlog evidence mismatch' unless backlog.fetch('evidence').end_with?("RELEASE-#{version['version']}-STATUS.md")
abort 'missing title/h1' unless html.scan(/<title>/).size == 1 && html.scan(/<h1>/).size == 1
abort 'missing description' unless html.include?('<meta name="description" content="')
abort 'wrong canonical' unless html.include?('<link rel="canonical" href="https://affpapa.github.io/neclip/">')
abort 'wrong OpenGraph URL' unless html.include?('<meta property="og:url" content="https://affpapa.github.io/neclip/">')
abort 'unexpected noindex' if html.match?(/<meta[^>]+noindex/i)
html.scan(/href="([^"#]+)"/).flatten.each do |href|
  next if href.start_with?('https://', 'http://')
  abort "missing local link: #{href}" unless File.file?(File.join(docs, href))
end
Dir.glob(File.join(root, '**', '*.md')).reject { |path| path.include?('/.build') || path.include?('/dist/') }.each do |path|
  File.read(path).scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |href|
    next if href.start_with?('https://', 'http://', '#', 'mailto:')
    target = File.expand_path(href.split('#').first, File.dirname(path))
    abort "missing Markdown link: #{href}" unless File.exist?(target)
  end
end
puts "PASS: public #{version['version']}, source #{project['sourceCandidate']['version']}, JSON, download, metadata and local links"
