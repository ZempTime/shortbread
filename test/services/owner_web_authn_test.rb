# frozen_string_literal: true

require "test_helper"

class OwnerWebAuthnTest < ActiveSupport::TestCase
  PRODUCTION_APEX = "shortbread.chriszempel.com"
  PRODUCTION_ORIGIN = "https://#{PRODUCTION_APEX}"

  test "the configured production apex is the exact HTTPS WebAuthn RP and origin" do
    configuration = OwnerWebAuthn.new(
      apex_host: PRODUCTION_APEX,
      rp_id: PRODUCTION_APEX,
      origin: PRODUCTION_ORIGIN,
      local_environment: false
    )

    assert_equal PRODUCTION_APEX, configuration.rp_id
    assert_equal PRODUCTION_ORIGIN, configuration.origin
    assert_equal PRODUCTION_APEX, configuration.relying_party.id
    assert_equal [ PRODUCTION_ORIGIN ], configuration.relying_party.allowed_origins
  end

  test "production rejects HTTP and an origin or RP that differs from the configured apex" do
    invalid_configurations = [
      { apex_host: PRODUCTION_APEX, rp_id: PRODUCTION_APEX, origin: "http://#{PRODUCTION_APEX}" },
      { apex_host: PRODUCTION_APEX, rp_id: PRODUCTION_APEX, origin: "#{PRODUCTION_ORIGIN}/" },
      { apex_host: PRODUCTION_APEX, rp_id: PRODUCTION_APEX, origin: "https://other.example" },
      { apex_host: PRODUCTION_APEX, rp_id: "sites.#{PRODUCTION_APEX}", origin: PRODUCTION_ORIGIN }
    ]

    invalid_configurations.each do |attributes|
      assert_raises OwnerWebAuthn::InvalidConfiguration do
        OwnerWebAuthn.new(**attributes, local_environment: false)
      end
    end
  end

  test "development permits explicit HTTP loopback but not another HTTP host" do
    loopback = OwnerWebAuthn.new(
      apex_host: "localhost",
      rp_id: "localhost",
      origin: "http://localhost:3000",
      local_environment: true
    )

    assert_equal "http://localhost:3000", loopback.origin
    assert_raises OwnerWebAuthn::InvalidConfiguration do
      OwnerWebAuthn.new(
        apex_host: "shortbread.localhost",
        rp_id: "shortbread.localhost",
        origin: "http://shortbread.localhost:3000",
        local_environment: true
      )
    end
  end
end
