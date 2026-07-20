# frozen_string_literal: true

require "test_helper"

class PublishingManifestTest < ActiveSupport::TestCase
  CANONICAL_MANIFEST = <<~JSON.chomp.freeze
    {"entries":[{"path":"assets/site.css","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":34,"content_type":"text/css","offline_policy":"optional"},{"path":"index.html","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","size":12,"content_type":"text/html","offline_policy":"required"}]}
  JSON

  test "canonical Manifest bytes and hash ignore input order" do
    index = manifest_entry(
      path: "index.html",
      sha256: "a" * 64,
      size: 12,
      content_type: "text/html",
      offline_policy: "required"
    )
    stylesheet = manifest_entry(
      path: "assets/site.css",
      sha256: "b" * 64,
      size: 34,
      content_type: "text/css",
      offline_policy: "optional"
    )

    first = Publishing::Manifest.build(entries: [ index, stylesheet ])
    reordered = Publishing::Manifest.build(entries: [ stylesheet.to_a.reverse.to_h, index.to_a.reverse.to_h ])

    assert_equal CANONICAL_MANIFEST, first.canonical_json
    assert_equal first.canonical_json, reordered.canonical_json
    assert_equal "5fc62506fd7053fc772eabedafb1849d8933179645d0df977647b0c4688b4105", first.sha256
    assert_equal [ "assets/site.css", "index.html" ], first.entries.pluck("path")
  end

  test "delta deterministically classifies added changed reused and removed paths" do
    base = Publishing::Manifest.build(entries: [
      manifest_entry(path: "index.html", sha256: "a" * 64),
      manifest_entry(path: "kept.txt", sha256: "b" * 64, content_type: "text/plain", offline_policy: "download"),
      manifest_entry(path: "removed.txt", sha256: "c" * 64, content_type: "text/plain", offline_policy: "download")
    ])
    candidate = Publishing::Manifest.build(entries: [
      manifest_entry(path: "added.txt", sha256: "d" * 64, content_type: "text/plain", offline_policy: "download"),
      manifest_entry(path: "index.html", sha256: "e" * 64),
      manifest_entry(path: "kept.txt", sha256: "b" * 64, content_type: "text/plain", offline_policy: "download")
    ])

    delta = candidate.delta_from(base)

    assert_equal [ "added.txt" ], delta.added
    assert_equal [ "index.html" ], delta.changed
    assert_equal [ "kept.txt" ], delta.reused
    assert_equal [ "removed.txt" ], delta.removed
    assert_equal({ added: 1, changed: 1, reused: 1, removed: 1 }, delta.counts)
  end

  private

  def manifest_entry(path:, sha256:, size: 1, content_type: "text/html", offline_policy: "required")
    {
      path:,
      sha256:,
      size:,
      content_type:,
      offline_policy:
    }
  end
end
