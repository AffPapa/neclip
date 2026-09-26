#!/usr/bin/env ruby
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'

class SEOReleaseTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  def setup
    @fixture = Dir.mktmpdir('neclip-seo-test-')
    FileUtils.cp_r(File.join(ROOT, 'docs'), @fixture)
  end
  def teardown
    FileUtils.remove_entry(@fixture)
  end
  def change(path)
    target = File.join(@fixture, 'docs', path)
    File.write(target, yield(File.read(target)))
  end
  def verify
    Open3.capture3(RbConfig.ruby, File.join(ROOT, 'scripts/verify-seo.rb'), @fixture)
  end
  def rejection(message)
    out, err, status = verify
    refute status.success?, out
    assert_includes err, message
  end
  def test_current_editorial_site_passes
    out, err, status = verify
    assert status.success?, "#{out}\n#{err}"
  end
  def test_every_editorial_footer_requires_project_credit
    change('guides/clipboard-history.html') do |s|
      s.sub('<a href="https://affpapa.org/">Проект Иванова</a>', '')
    end
    rejection('missing Ivanov project credit in footer')
  end
  def test_article_rejects_inline_script
    change('guides/clipboard-history.html') { |s| s.sub('</main>', '<script>"not article content"</script></main>') }
    rejection('missing static article')
  end
  def test_article_rejects_uppercase_script
    change('guides/clipboard-history.html') { |s| s.sub('</main>', '<SCRIPT>"not article content"</SCRIPT></main>') }
    rejection('missing static article')
  end
  def test_footer_cannot_pad_a_thin_article
    change('guides/clipboard-history.html') do |s|
      heading = s[/<h1>.*?<\/h1>/m]
      replacement = '<main id="main">' + heading + '<nav aria-label="Хлебные крошки">NeClip</nav><p>Коротко.</p></main>'
      s.sub(/<main\b[^>]*>.*?<\/main>/m, replacement).sub('</footer>', '<p>' + ('footer ' * 500) + '</p></footer>')
    end
    rejection('thin article')
  end
  def test_duplicate_competitor_is_rejected
    change('compare.html') { |s| s.sub('data-product="maccy"', 'data-product="paste"') }
    rejection('twenty unique products')
  end
  def test_noindex_sitemap_page_is_rejected
    change('compare.html') { |s| s.sub('<head>', '<head><meta name="robots" content="noindex">') }
    rejection('noindex')
  end
  def test_wrong_canonical_is_rejected
    change('guides/keyboard-layout.html') { |s| s.sub('rel="canonical" href="https://affpapa.github.io/neclip/', 'rel="canonical" href="https://example.invalid/') }
    rejection('canonical count')
  end
  def test_broken_fragment_is_rejected
    change('index.html') { |s| s.sub('href="#features"', 'href="#missing-feature"') }
    rejection('missing fragment')
  end
  def test_fake_rating_is_rejected
    change('compare.html') { |s| s.sub('"@type":"CollectionPage"', '"@type":"CollectionPage","aggregateRating":{}') }
    rejection('unsubstantiated rating')
  end
  def test_invalid_json_ld_is_rejected
    change('compare.html') { |s| s.sub('"@graph":', '"@graph"=') }
    rejection('JSON::ParserError')
  end
  def test_machine_path_is_rejected
    change('compare.html') { |s| s.sub('</main>', '<p>/Users/fixture/private</p></main>') }
    rejection('local machine path')
  end
  def test_stale_public_version_schema_is_rejected
    change('index.html') { |s| s.sub(/"softwareVersion":"[^"]+"/, '"softwareVersion":"0.0.0"') }
    rejection('schema version mismatch')
  end
end
