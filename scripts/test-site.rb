#!/usr/bin/env ruby
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'

class SiteCoherenceTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def setup
    @fixture = Dir.mktmpdir('neclip-site-test-')
    %w[docs Resources README.md CHANGELOG.md BACKLOG.md SECURITY.md LICENSE THIRD_PARTY_NOTICES.md].each do |name|
      FileUtils.cp_r(File.join(ROOT, name), @fixture)
    end
  end

  def teardown
    FileUtils.remove_entry(@fixture)
  end

  def verify
    Open3.capture3(RbConfig.ruby, File.join(ROOT, 'scripts/verify-site.rb'), @fixture)
  end

  def mutate(name)
    path = File.join(@fixture, 'docs', "#{name}.json")
    data = JSON.parse(File.read(path))
    yield data
    File.write(path, JSON.generate(data))
  end

  def test_current_release_passes
    out, err, status = verify
    assert status.success?, "#{out}\n#{err}"
  end

  def test_rejects_mismatched_build
    mutate('project') { |data| data['sourceCandidate']['build'] += 1 }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'bundle/candidate mismatch'
  end

  def test_rejects_redirected_checksum_link
    mutate('version') { |data| data['checksum'] = 'https://example.invalid/checksum' }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'checksum URL mismatch'
  end

  def test_current_release_archive_metadata_matches_public_pages
    version = JSON.parse(File.read(File.join(@fixture, 'docs/version.json')))
    archive = version.fetch('appArchive')
    assert_equal 'https://github.com/AffPapa/neclip/releases/download/v2.8.5-zip/NeClip-2.8.5.zip', archive.fetch('release')
    assert_equal 'https://github.com/AffPapa/neclip/releases/tag/v2.8.5-zip', archive.fetch('releasePage')
    assert_equal 'https://github.com/AffPapa/neclip/releases/download/v2.8.5-zip/NeClip-2.8.5.zip.sha256', archive.fetch('checksum')
    assert_equal 'ad697fe16c2165f1af0881e215da0ebbc6f379c179b920f01b1a09a9a041890a', archive.fetch('sha256')
    assert_equal 2_108_558, archive.fetch('sizeBytes')
    html = File.read(File.join(@fixture, 'docs/index.html'))
    readme = File.read(File.join(@fixture, 'README.md'))
    assert_includes html, 'releases/download/v2.8.5-zip/NeClip-2.8.5.zip'
    assert_includes readme, 'releases/download/v2.8.5-zip/NeClip-2.8.5.zip'
  end

  def test_rejects_wrong_archive_url
    mutate('version') { |data| data['appArchive']['release'] = 'https://example.invalid/NeClip.zip' }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'archive URL mismatch'
  end

  def test_rejects_redirected_archive_checksum
    mutate('version') { |data| data['appArchive']['checksum'] = 'https://example.invalid/NeClip.zip.sha256' }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'archive checksum URL mismatch'
  end

  def test_rejects_wrong_archive_digest
    mutate('version') { |data| data['appArchive']['sha256'] = '0' * 64 }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'site archive checksum mismatch'
  end

  def test_rejects_stale_archive_size
    mutate('version') { |data| data['appArchive']['sizeBytes'] += 1 }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'site archive size mismatch'
  end

  def test_rejects_missing_archive_checksum_in_evidence
    evidence = File.join(@fixture, 'docs', 'RELEASE-2.8.5-STATUS.md')
    File.write(evidence, File.read(evidence).sub('ad697fe16c2165f1af0881e215da0ebbc6f379c179b920f01b1a09a9a041890a', ''))
    _, err, status = verify
    refute status.success?
    assert_includes err, 'archive evidence mismatch'
  end

  def test_rejects_disagreeing_source_commit
    mutate('version') { |data| data['sourceCommit'] = '0' * 40 }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'README source mismatch'
  end

  def test_rejects_deleted_evidence_link
    File.open(File.join(@fixture, 'README.md'), 'a') { |file| file.puts '\n[Evidence](docs/deleted-evidence.md)' }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'missing Markdown link'
  end

  def test_rejects_stale_changelog_build
    mutate('changelog') { |data| data['versions'].first['build'] -= 1 }
    _, err, status = verify
    refute status.success?
    assert_includes err, 'changelog build mismatch'
  end

  def test_rejects_stale_public_roadmap
    path = File.join(@fixture, 'BACKLOG.md')
    File.write(path, File.read(path).sub('Current public release —', 'Historical release —'))
    _, err, status = verify
    refute status.success?
    assert_includes err, 'roadmap version mismatch'
  end

  def test_unreleased_candidate_keeps_verified_public_download
    public_before = File.read(File.join(@fixture, 'docs/version.json'))
    candidate = JSON.parse(File.read(File.join(@fixture, 'docs/project.json'))).fetch('sourceCandidate')
    parts = candidate.fetch('version').split('.').map(&:to_i)
    parts[-1] += 1
    next_version = parts.join('.')
    next_build = candidate.fetch('build') + 1
    mutate('project') do |data|
      data['sourceCandidate'].merge!('version' => next_version, 'build' => next_build, 'status' => 'candidate')
      data['sourceCandidate'].delete('sourceCommit')
    end
    mutate('changelog') do |data|
      data['versions'] << { 'version' => next_version, 'build' => next_build, 'status' => 'candidate' }
    end
    path = File.join(@fixture, 'Resources/Info.plist')
    plist = File.read(path).sub("<string>#{candidate.fetch('version')}</string>", "<string>#{next_version}</string>")
      .sub("<string>#{candidate.fetch('build')}</string>", "<string>#{next_build}</string>")
    File.write(path, plist)
    out, err, status = verify
    assert status.success?, "#{out}\n#{err}"
    assert_equal public_before, File.read(File.join(@fixture, 'docs/version.json'))
  end
end
