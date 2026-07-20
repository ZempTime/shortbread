# frozen_string_literal: true

require "test_helper"

require "json"
require "open3"
require "rbconfig"

class DevelopmentHostIdentityTest < ActiveSupport::TestCase
  DEVELOPMENT_PROBE = <<~'RUBY'
    require "json"
    require "rack/mock"

    ViteRuby.instance.define_singleton_method(:dev_server_running?) do
      raise "VITE_PROXY_REACHED"
    end

    def request_snapshot(forwarded_host)
      environment = Rack::MockRequest.env_for(
        "http://localhost:3000/vite-dev/assets/application.js",
        "HTTP_HOST" => "localhost:3000",
        "HTTP_X_FORWARDED_HOST" => forwarded_host
      )
      status, headers, body = Rails.application.call(environment)
      content = +""
      body.each { |chunk| content << chunk }
      body.close if body.respond_to?(:close)
      { "status" => status, "body" => content, "content_length" => headers["content-length"] }
    end

    middleware = Rails.application.middleware.map { |entry| entry.klass.name }
    puts JSON.generate({
      "middleware" => middleware,
      "responses" => [ request_snapshot(""), request_snapshot("localhost,") ]
    })
  RUBY

  test "development Vite boundary rejects malformed forwarded hosts before proxying" do
    stdout, stderr, status = Open3.capture3(
      {
        "RAILS_ENV" => "development",
        "RAILS_LOG_LEVEL" => "fatal",
        "SHORTBREAD_APEX_HOST" => "localhost"
      },
      RbConfig.ruby,
      Rails.root.join("bin/rails").to_s,
      "runner",
      DEVELOPMENT_PROBE,
      chdir: Rails.root.to_s
    )

    assert status.success?, stderr
    payload = JSON.parse(stdout)
    payload.fetch("responses").each do |response|
      assert_equal 404, response.fetch("status")
      assert_equal "", response.fetch("body")
      assert_equal "0", response.fetch("content_length")
    end

    middleware = payload.fetch("middleware")
    vite_index = middleware.index("Shortbread::HostScopedViteProxy")
    guard_index = middleware.index("Shortbread::HostIdentityGuard")
    authorization_index = middleware.index("ActionDispatch::HostAuthorization")

    assert_not_nil vite_index
    assert_not_nil guard_index
    assert_not_nil authorization_index
    assert_operator vite_index, :<, guard_index
    assert_operator guard_index, :<, authorization_index
  end
end
