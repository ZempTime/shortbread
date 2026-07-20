# frozen_string_literal: true

require "test_helper"

require "rack/lint"
require "rack/mock"

class Shortbread::RackResponsesTest < ActiveSupport::TestCase
  test "blank not-found responses have independent mutable headers" do
    first_response = Shortbread::RackResponses.not_found
    second_response = Shortbread::RackResponses.not_found

    refute_same first_response.fetch(1), second_response.fetch(1)
    first_response.fetch(1)["content-length"] = "changed"
    assert_equal "0", second_response.fetch(1).fetch("content-length")
  end

  test "host identity rejections are Rack-conformant blank responses" do
    assert_rack_not_found(
      Shortbread::HostIdentityGuard.new(unreachable_application),
      host: "wrong.example"
    )
  end

  test "Vite host rejections are Rack-conformant blank responses" do
    assert_rack_not_found(
      Shortbread::HostScopedViteProxy.new(unreachable_application, proxy: unreachable_application),
      host: "wrong.example",
      path: "/vite-test/assets/application.js"
    )
  end

  test "static host rejections are Rack-conformant blank responses" do
    assert_rack_not_found(
      Shortbread::HostScopedStatic.new(unreachable_application),
      host: "wrong.example",
      path: "/robots.txt"
    )
  end

  test "host authorization rejections are Rack-conformant blank responses" do
    assert_rack_not_found(
      Rails.application.config.host_authorization.fetch(:response_app),
      host: "wrong.example"
    )
  end

  test "the Site health fallback is a Rack-conformant blank response" do
    assert_rack_not_found(
      Rails.application.routes,
      host: "first-site.sites.localhost",
      path: "/up"
    )
  end

  private

  def assert_rack_not_found(application, host:, path: "/")
    status, headers, body = Rack::Lint.new(application).call(
      Rack::MockRequest.env_for("http://#{host}#{path}", "HTTP_HOST" => host)
    )
    content = body.each.to_a.join

    assert_equal 404, status
    assert_equal(
      { "content-type" => "text/plain; charset=utf-8", "content-length" => "0" },
      headers
    )
    assert_empty content
  ensure
    body&.close
  end

  def unreachable_application
    ->(_environment) { raise "unexpected downstream Rack application call" }
  end
end
