# frozen_string_literal: true

require "test_helper"

require "json"
require "open3"
require "rbconfig"

class ProductionHostIdentityTest < ActiveSupport::TestCase
  PRODUCTION_PROBE = <<~'RUBY'
    require "json"
    require "rack/mock"

    def request_snapshot(raw_host:, forwarded_host:, path:, method: "GET")
      environment = Rack::MockRequest.env_for(
        "https://#{raw_host}#{path}",
        method:,
        "HTTP_HOST" => raw_host,
        "HTTP_X_FORWARDED_HOST" => forwarded_host,
        "HTTPS" => "on",
        "rack.url_scheme" => "https",
        "SERVER_PORT" => "443"
      )
      status, headers, body = Rails.application.call(environment)
      content = +""
      body.each { |chunk| content << chunk }
      body.close if body.respond_to?(:close)
      { "status" => status, "body" => content, "content_length" => headers["Content-Length"] }
    end

    raw_site = "first-site.sites.shortbread.example:8443"
    forwarded_apex = "shortbread.example"
    spoofed = [ "/up", "/invitations/#{"z" * 32}", "/robots.txt" ].to_h do |path|
      [ path, request_snapshot(raw_host: raw_site, forwarded_host: forwarded_apex, path:) ]
    end
    matching_apex = request_snapshot(
      raw_host: "shortbread.example:8443",
      forwarded_host: forwarded_apex,
      path: "/up"
    )
    forwarded_site = "untrusted.example, first-site.sites.shortbread.example"
    matching_site = {
      "GET /up" => request_snapshot(raw_host: raw_site, forwarded_host: forwarded_site, path: "/up"),
      "GET /robots.txt" => request_snapshot(raw_host: raw_site, forwarded_host: forwarded_site, path: "/robots.txt"),
      "GET /invitations" => request_snapshot(
        raw_host: raw_site,
        forwarded_host: forwarded_site,
        path: "/invitations/#{"y" * 32}"
      ),
      "POST /api/v1/sites" => request_snapshot(
        raw_host: raw_site,
        forwarded_host: forwarded_site,
        path: "/api/v1/sites",
        method: "POST"
      )
    }
    middleware = Rails.application.middleware.map { |entry| entry.klass.name }

    puts JSON.generate({
      "middleware" => middleware,
      "spoofed" => spoofed,
      "matching_apex" => matching_apex,
      "matching_site" => matching_site
    })
  RUBY

  test "production rejects a Site raw host forwarded as the apex before routes and static files" do
    stdout, stderr, status = Open3.capture3(
      {
        "RAILS_ENV" => "production",
        "RAILS_LOG_LEVEL" => "fatal",
        "SECRET_KEY_BASE" => "synthetic-production-host-boundary-key-0123456789abcdef",
        "SHORTBREAD_APEX_HOST" => "shortbread.example"
      },
      RbConfig.ruby,
      Rails.root.join("bin/rails").to_s,
      "runner",
      PRODUCTION_PROBE,
      chdir: Rails.root.to_s
    )

    assert status.success?, stderr
    payload = JSON.parse(stdout)
    assert_equal({ "status" => 200 }, payload.fetch("matching_apex").slice("status"))

    payload.fetch("spoofed").each_value do |response|
      assert_equal 404, response.fetch("status")
      assert_equal "", response.fetch("body")
      assert_equal "0", response.fetch("content_length")
    end
    payload.fetch("matching_site").each_value do |response|
      assert_equal 404, response.fetch("status")
      assert_equal "", response.fetch("body")
      assert_equal "0", response.fetch("content_length")
    end

    middleware = payload.fetch("middleware")
    guard_index = middleware.index("Shortbread::HostIdentityGuard")
    authorization_index = middleware.index("ActionDispatch::HostAuthorization")
    static_index = middleware.index("Shortbread::HostScopedStatic")

    assert_not_nil guard_index
    assert_not_nil authorization_index
    assert_not_nil static_index
    assert_operator guard_index, :<, authorization_index
    assert_operator guard_index, :<, static_index
    refute_includes middleware, "Shortbread::HostScopedViteProxy"
  end
end
