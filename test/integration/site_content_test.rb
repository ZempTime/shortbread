# frozen_string_literal: true

require "test_helper"

require "digest"
require "stringio"
require "tmpdir"

class SiteContentTest < ActionDispatch::IntegrationTest
  test "an authenticated Viewer receives the current private HTML with exact response metadata" do
    content = "<h1>PRIVATE_SITE_CONTENT</h1>"

    with_private_site(content:) do |site, grant, digest|
      host! "#{site.slug}.sites.localhost"
      authenticate(grant:, site:)

      get "/"

      assert_response :ok
      assert_equal content, response.body
      assert_equal "text/html", response.headers["Content-Type"]
      assert_equal content.bytesize.to_s, response.headers["Content-Length"]
      assert_equal %Q("#{digest}"), response.headers["ETag"]
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    end
  end

  test "HEAD returns the same private response metadata without a body" do
    content = "<h1>PRIVATE_HEAD_CONTENT</h1>"

    with_private_site(content:) do |site, grant, digest|
      host! "#{site.slug}.sites.localhost"
      authenticate(grant:, site:)

      head "/"

      assert_response :ok
      assert_empty response.body
      assert_equal "text/html", response.headers["Content-Type"]
      assert_equal content.bytesize.to_s, response.headers["Content-Length"]
      assert_equal %Q("#{digest}"), response.headers["ETag"]
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    end
  end

  test "GET and HEAD fail closed before success metadata when the private Blob is unusable" do
    failure_modes = {
      missing: ->(path) { File.delete(path) },
      wrong_mode: ->(path) { File.chmod(0o644, path) },
      truncated: ->(path) { File.truncate(path, 1) }
    }

    failure_modes.each do |failure_mode, make_unusable|
      %i[get head].each do |method|
        content = "<h1>PRIVATE_UNUSABLE_#{failure_mode}_#{method}</h1>"
        slug = "#{failure_mode.to_s.tr("_", "-")}-#{method}"

        with_private_site(content:, slug:) do |site, grant, _digest|
          host! "#{site.slug}.sites.localhost"
          authenticate(grant:, site:)
          blob = site.current_release.manifest_entries.find_by!(path: "index.html").blob
          make_unusable.call(blob_path(blob))

          public_send(method, "/")

          assert_response :not_found, "#{method.upcase} accepted a #{failure_mode} Blob"
          assert_empty response.body
          assert_includes [ nil, "0" ], response.headers["Content-Length"]
          assert_nil response.headers["ETag"]
          refute_equal "no-store", response.headers["Cache-Control"]
        end
      end
    end
  end

  test "unauthenticated, revoked, wrong-host, and incomplete Site requests fail before Blob storage opens" do
    content = "<h1>PRIVATE_DENIAL_CONTENT</h1>"

    with_private_site(content:) do |site, grant, _digest|
      blob = site.current_release.manifest_entries.find_by!(path: "index.html").blob
      other_site = Site.create!(slug: "other-site", name: "Other Site")

      host! "#{site.slug}.sites.localhost"
      assert_rejected_without_opening(blob) { get "/" }

      authenticate(grant:, site:)
      host! "#{other_site.slug}.sites.localhost"
      assert_rejected_without_opening(blob) { get "/" }

      host! "localhost"
      assert_rejected_without_opening(blob) { get "/" }

      host! "nested.#{site.slug}.sites.localhost"
      assert_rejected_without_opening(blob) { get "/" }

      grant.update!(revoked_at: Time.current)
      host! "#{site.slug}.sites.localhost"
      assert_rejected_without_opening(blob) { get "/" }

      empty_site = Site.create!(slug: "empty-site", name: "Empty Site")
      empty_person = Person.create!(first_name: "Blair")
      empty_grant = Grant.create!(site: empty_site, person: empty_person)
      host! "#{empty_site.slug}.sites.localhost"
      authenticate(grant: empty_grant, site: empty_site)
      assert_rejected_without_opening(blob) { get "/" }
    end
  end

  test "HTTPS reads only the Secure __Host Site session cookie" do
    content = "<h1>PRIVATE_HTTPS_CONTENT</h1>"

    with_private_site(content:) do |site, grant, _digest|
      https!
      host! "#{site.slug}.sites.localhost"
      issued = SiteSession.issue(
        grant:,
        audience: "https://#{site.slug}.sites.localhost",
        now: Time.current
      )
      blob = site.current_release.manifest_entries.find_by!(path: "index.html").blob

      cookies["shortbread_site"] = issued.token
      assert_rejected_without_opening(blob) { get "/" }

      cookies.delete("shortbread_site")
      cookies["__Host-shortbread_site"] = issued.token
      get "/"

      assert_response :ok
      assert_equal content, response.body
    end
  end

  private

  def with_private_site(content:, slug: "first-site")
    Dir.mktmpdir("shortbread-private-site") do |root|
      previous_root = ENV["SHORTBREAD_BLOB_ROOT"]
      ENV["SHORTBREAD_BLOB_ROOT"] = root

      site = Site.create!(slug:, name: "First Site")
      person = Person.create!(first_name: "Avery")
      grant = Grant.create!(site:, person:)
      digest = Digest::SHA256.hexdigest(content)
      storage_key = LocalBlobStore.new.put_verified(
        io: StringIO.new(content),
        sha256: digest,
        byte_size: content.bytesize
      )
      blob = Blob.create!(sha256: digest, byte_size: content.bytesize, storage_key:)
      release = site.releases.create!(
        number: 1,
        manifest_sha256: Digest::SHA256.hexdigest("manifest"),
        finalized_at: Time.current
      )
      release.manifest_entries.create!(
        blob:,
        path: "index.html",
        byte_size: content.bytesize,
        content_type: "text/html",
        offline_policy: "required"
      )
      site.update!(current_release: release)

      yield site, grant, digest
    ensure
      ENV["SHORTBREAD_BLOB_ROOT"] = previous_root
    end
  end

  def authenticate(grant:, site:, scheme: "http")
    issued = SiteSession.issue(
      grant:,
      audience: "#{scheme}://#{site.slug}.sites.localhost",
      now: Time.current
    )
    cookies[SiteSession.cookie_name(secure: scheme == "https")] = issued.token
  end

  def assert_rejected_without_opening(blob)
    opened = false
    original_open = File.method(:open)
    expected_path = File.join(
      ENV.fetch("SHORTBREAD_BLOB_ROOT"),
      blob.storage_key.first(2),
      blob.storage_key
    )
    tracked_open = proc do |path, *arguments, **keywords, &block|
      opened = true if File.expand_path(path.to_s) == File.expand_path(expected_path)
      original_open.call(path, *arguments, **keywords, &block)
    end

    File.stub(:open, tracked_open) { yield }

    assert_response :not_found
    assert_empty response.body
    assert_nil response.headers["ETag"]
    assert_equal "0", response.headers["Content-Length"]
    assert_not opened, "private Blob storage was opened before the request was authorized"
  end

  def blob_path(blob)
    File.join(
      ENV.fetch("SHORTBREAD_BLOB_ROOT"),
      blob.storage_key.first(2),
      blob.storage_key
    )
  end
end
