# frozen_string_literal: true

require "test_helper"

require "rack/mock"

class Shortbread::HostScopedViteProxyTest < ActiveSupport::TestCase
  test "only the apex can reach a running Vite development proxy" do
    proxy_hosts = []
    app_hosts = []
    proxy = lambda do |environment|
      proxy_hosts << environment.fetch("HTTP_HOST")
      [ 200, { "Content-Type" => "application/javascript" }, [ "SYNTHETIC_VITE_RESPONSE" ] ]
    end
    app = lambda do |environment|
      app_hosts << environment.fetch("HTTP_HOST")
      [ 404, { "Content-Type" => "text/plain; charset=utf-8", "Content-Length" => "0" }, [] ]
    end
    middleware = Shortbread::HostScopedViteProxy.new(app, proxy:)

    apex_response = middleware.call(environment_for("localhost"))
    assert_equal 200, apex_response.first
    assert_equal "SYNTHETIC_VITE_RESPONSE", response_body(apex_response)

    site_response = middleware.call(environment_for("first-site.sites.localhost"))
    assert_blank_not_found(site_response)

    invalid_response = middleware.call(environment_for("wrong.example"))
    assert_blank_not_found(invalid_response)

    site_spoofing_apex = middleware.call(
      environment_for("first-site.sites.localhost", forwarded_host: "localhost")
    )
    assert_blank_not_found(site_spoofing_apex)

    apex_spoofing_site = middleware.call(
      environment_for("localhost", forwarded_host: "first-site.sites.localhost")
    )
    assert_blank_not_found(apex_spoofing_site)

    assert_equal [ "localhost" ], proxy_hosts
    assert_equal [ "first-site.sites.localhost" ], app_hosts
  end

  private

  def environment_for(host, forwarded_host: nil)
    environment = Rack::MockRequest.env_for(
      "http://#{host}/vite-test/assets/application.js",
      "HTTP_HOST" => host
    )
    environment["HTTP_X_FORWARDED_HOST"] = forwarded_host if forwarded_host
    environment
  end

  def assert_blank_not_found(response)
    assert_equal 404, response.first
    assert_equal "0", response.fetch(1).fetch("Content-Length")
    assert_empty response_body(response)
  end

  def response_body(response)
    response.last.each.to_a.join
  end
end
