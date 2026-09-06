#!/usr/bin/env ruby
# Read-only coherence gate: a candidate must never replace a verified download.
require 'json'
root = File.expand_path('..', __dir__)
docs = File.join(root, 'docs')
data = %w[version project changelog backlog].to_h do |name|
  [name, JSON.parse(File.read(File.join(docs, "#{name}.json")))]
end
version = data.fetch('version')
project = data.fetch('project')
html = File.read(File.join(docs, 'index.html'))
abort 'invalid public version' unless version.fetch('version').match?(/\A\d+\.\d+\.\d+\z/)
abort 'public artifact not released' unless version.fetch('status') == 'released'
abort 'invalid checksum' unless version.fetch('sha256').match?(/\A[0-9a-f]{64}\z/)
abort 'invalid public size' unless version.fetch('sizeBytes').is_a?(Integer) && version['sizeBytes'] > 0
expected = "https://github.com/AffPapa/neclip/releases/download/v#{version['version']}/NeClip-#{version['version']}.dmg"
abort 'download mismatch' unless version.fetch('release') == expected && html.include?("href=\"#{expected}\"")
abort 'public/candidate mismatch' unless project.fetch('sourceCandidate').fetch('publicVersion') == version['version']
abort 'missing candidate record' unless data['changelog']['versions'].any? { |v| v['version'] == project['sourceCandidate']['version'] }
abort 'missing title/h1' unless html.scan(/<title>/).size == 1 && html.scan(/<h1>/).size == 1
abort 'missing description' unless html.include?('<meta name="description" content="')
abort 'wrong canonical' unless html.include?('<link rel="canonical" href="https://affpapa.github.io/neclip/">')
abort 'unexpected noindex' if html.match?(/<meta[^>]+noindex/i)
html.scan(/href="([^"#]+)"/).flatten.each do |href|
  next if href.start_with?('https://', 'http://')
  abort "missing local link: #{href}" unless File.file?(File.join(docs, href))
end
puts "PASS: public #{version['version']}, source #{project['sourceCandidate']['version']}, JSON, download, metadata and local links"
