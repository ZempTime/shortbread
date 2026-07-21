# frozen_string_literal: true

require "test_helper"

class OwnerBootstrapTest < ActionDispatch::IntegrationTest
  test "Owner bootstrap is available once on the apex and never on a Site host" do
    host! "localhost"

    get "/owner/bootstrap"

    assert_response :ok
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.body, "Register the Owner passkey"

    host! "first-site.sites.localhost"
    get "/owner/bootstrap"
    assert_response :not_found

    Owner.create!(webauthn_id: "synthetic-owner-id")
    host! "localhost"
    get "/owner/bootstrap"
    assert_response :not_found
  end
end
