# frozen_string_literal: true

require "test_helper"

require "rack/mock"

class Shortbread::HostIdentityGuardTest < ActiveSupport::TestCase
  test "matching apex and Site identities reach the application through a proxy" do
    calls = []
    application = lambda do |environment|
      calls << environment.fetch("HTTP_HOST")
      [ 204, { "x-downstream" => "reached" }, [] ]
    end
    middleware = Shortbread::HostIdentityGuard.new(application)
    attempts = [
      environment_for("localhost:3000"),
      environment_for("localhost:3000", forwarded_host: "untrusted.example, localhost:443"),
      environment_for(
        "first-site.sites.localhost:3000",
        forwarded_host: "untrusted.example, first-site.sites.localhost:443"
      )
    ]

    attempts.each do |environment|
      response = middleware.call(environment)

      assert_equal 204, response.first
      assert_equal "reached", response.fetch(1).fetch("x-downstream")
    end
    assert_equal attempts.map { |environment| environment.fetch("HTTP_HOST") }, calls
  end

  test "confused or malformed forwarded authorities fail before the application" do
    calls = []
    middleware = Shortbread::HostIdentityGuard.new(lambda do |environment|
      calls << environment
      [ 204, {}, [] ]
    end)
    attempts = [
      environment_for("first-site.sites.localhost:3000", forwarded_host: "localhost"),
      environment_for("localhost:3000", forwarded_host: "first-site.sites.localhost"),
      environment_for("localhost:3000", forwarded_host: "bad_host"),
      environment_for("localhost:3000", forwarded_host: "localhost:"),
      environment_for("localhost:3000", forwarded_host: "localhost:70000"),
      environment_for("localhost:3000", forwarded_host: ""),
      environment_for("localhost:3000", forwarded_host: "localhost,")
    ]

    attempts.each do |environment|
      response = middleware.call(environment)

      assert_equal 404, response.first
      assert_equal "0", response.fetch(1).fetch("content-length")
      assert_empty response.last
    end
    assert_empty calls
  end

  private

  def environment_for(raw_host, forwarded_host: nil)
    environment = Rack::MockRequest.env_for(
      "http://#{raw_host}/",
      "HTTP_HOST" => raw_host
    )
    environment["HTTP_X_FORWARDED_HOST"] = forwarded_host unless forwarded_host.nil?
    environment
  end
end
