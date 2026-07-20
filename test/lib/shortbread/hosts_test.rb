# frozen_string_literal: true

require "test_helper"

class Shortbread::HostsTest < ActiveSupport::TestCase
  test "recognizes the configured apex and builds its request origin" do
    host = Shortbread::Hosts.parse(
      host: "shortbread.example",
      scheme: "https",
      port: 443,
      apex_host: "shortbread.example"
    )

    assert_equal :apex, host.kind
    assert_equal "shortbread.example", host.apex
    assert_nil host.site_slug
    assert_equal "https://shortbread.example", host.apex_origin
    assert_equal "https://family-trip.sites.shortbread.example", host.site_origin("family-trip")
    assert_predicate host, :frozen?
  end

  test "recognizes exactly one Site label and builds apex and Site origins" do
    host = Shortbread::Hosts.parse(
      host: "family-trip.sites.shortbread.example",
      scheme: "http",
      port: 3000,
      apex_host: "shortbread.example"
    )

    assert_equal :site, host.kind
    assert_equal "shortbread.example", host.apex
    assert_equal "family-trip", host.site_slug
    assert_equal "http://shortbread.example:3000", host.apex_origin
    assert_equal "http://family-trip.sites.shortbread.example:3000", host.site_origin
  end

  test "rejects every host outside the exact apex and one-label Site forms without echoing it" do
    invalid_hosts = [
      "extra.family-trip.sites.shortbread.example",
      "family-trip.sites.shortbread.example.attacker.test",
      "family-trip.sites.shortbread.example.",
      "family_trip.sites.shortbread.example",
      "sites.shortbread.example",
      "family-trip.sites.shortbread.example:3000",
      "family-trip.sites.shortbread.example/path",
      " family-trip.sites.shortbread.example"
    ]

    invalid_hosts.each do |invalid_host|
      error = assert_raises(Shortbread::Hosts::InvalidHost) do
        Shortbread::Hosts.parse(
          host: invalid_host,
          scheme: "https",
          port: 443,
          apex_host: "shortbread.example"
        )
      end

      assert_equal "invalid Shortbread host", error.message
      refute_includes error.message, invalid_host
    end
  end

  test "rejects a malformed configured apex including one containing a port" do
    invalid_apex_hosts = [
      "shortbread.example:443",
      "https://shortbread.example",
      "shortbread..example",
      ".shortbread.example",
      "shortbread.example.",
      "short_bread.example",
      ""
    ]

    invalid_apex_hosts.each do |invalid_apex_host|
      error = assert_raises(Shortbread::Hosts::InvalidHost) do
        Shortbread::Hosts.parse(
          host: invalid_apex_host,
          scheme: "https",
          port: 443,
          apex_host: invalid_apex_host
        )
      end

      assert_equal "invalid Shortbread host", error.message
      refute_includes error.message, invalid_apex_host unless invalid_apex_host.empty?
    end
  end

  test "reads the apex from the environment and defaults to localhost" do
    with_apex_host("control.example") do
      host = Shortbread::Hosts.parse(host: "control.example", scheme: "https", port: 443)

      assert_equal "control.example", host.apex
    end

    with_apex_host(nil) do
      host = Shortbread::Hosts.parse(host: "localhost", scheme: "http", port: 3000)

      assert_equal "localhost", host.apex
      assert_equal "http://localhost:3000", host.apex_origin
    end
  end

  test "builds the pre-routing allowlist for only the apex and one-label Site hosts" do
    pattern = Shortbread::Hosts.authorization_pattern(apex_host: "shortbread.example")
    permissions = ActionDispatch::HostAuthorization::Permissions.new([ pattern ])

    assert permissions.allows?("shortbread.example")
    assert permissions.allows?("shortbread.example:443")
    assert permissions.allows?("family-trip.sites.shortbread.example")
    assert permissions.allows?("family-trip.sites.shortbread.example:443")
    refute permissions.allows?("extra.family-trip.sites.shortbread.example")
    refute permissions.allows?("family-trip.sites.shortbread.example.attacker.test")
    refute permissions.allows?("sites.shortbread.example")

    assert_raises(Shortbread::Hosts::InvalidHost) do
      Shortbread::Hosts.authorization_pattern(apex_host: "bad_host")
    end

    longest_apex = [ "a" * 63, "b" * 63, "c" * 63, "d" * 53 ].join(".")
    bounded = ActionDispatch::HostAuthorization::Permissions.new(
      [ Shortbread::Hosts.authorization_pattern(apex_host: longest_apex) ]
    )
    assert bounded.allows?("s.sites.#{longest_apex}")
    refute bounded.allows?("ss.sites.#{longest_apex}")

    oversized_apex = [ "a" * 63, "b" * 63, "c" * 63, "d" * 54 ].join(".")
    assert_raises(Shortbread::Hosts::InvalidHost) do
      Shortbread::Hosts.authorization_pattern(apex_host: oversized_apex)
    end
  end

  test "validates a complete Site hostname before building its origin" do
    longest_apex = [ "a" * 63, "b" * 63, "c" * 63, "d" * 53 ].join(".")

    assert Shortbread::Hosts.valid_site_hostname?(slug: "s", apex_host: longest_apex)
    refute Shortbread::Hosts.valid_site_hostname?(slug: "ss", apex_host: longest_apex)

    host = Shortbread::Hosts.parse(
      host: longest_apex,
      scheme: "https",
      port: 443,
      apex_host: longest_apex
    )
    assert_equal "https://s.sites.#{longest_apex}", host.site_origin("s")

    error = assert_raises(Shortbread::Hosts::InvalidHost) { host.site_origin("ss") }
    assert_equal "invalid Shortbread host", error.message
    refute_includes error.message, longest_apex
  end

  test "rejects request context that cannot form an HTTP origin" do
    invalid_contexts = [
      { scheme: "ftp", port: 21 },
      { scheme: "https://", port: 443 },
      { scheme: "http", port: 0 },
      { scheme: "http", port: 65_536 },
      { scheme: "http", port: "3000" },
      { scheme: "http", port: nil }
    ]

    invalid_contexts.each do |context|
      error = assert_raises(Shortbread::Hosts::InvalidHost) do
        Shortbread::Hosts.parse(
          host: "localhost",
          scheme: context.fetch(:scheme),
          port: context.fetch(:port),
          apex_host: "localhost"
        )
      end

      assert_equal "invalid Shortbread host", error.message
    end
  end

  private

  def with_apex_host(value)
    previous = ENV["SHORTBREAD_APEX_HOST"]
    value.nil? ? ENV.delete("SHORTBREAD_APEX_HOST") : ENV["SHORTBREAD_APEX_HOST"] = value
    yield
  ensure
    previous.nil? ? ENV.delete("SHORTBREAD_APEX_HOST") : ENV["SHORTBREAD_APEX_HOST"] = previous
  end
end
