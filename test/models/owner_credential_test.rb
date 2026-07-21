# frozen_string_literal: true

require "test_helper"

require "base64"

class OwnerCredentialTest < ActiveSupport::TestCase
  test "stored base64url credential IDs fit the accepted decoded boundary" do
    owner = Owner.create!(webauthn_id: "synthetic-owner-id")
    maximum = OwnerCredential::ENCODED_CREDENTIAL_ID_MAXIMUM_BYTES
    encoded_boundary = Base64.urlsafe_encode64(
      "\0" * OwnerRegistration::MAX_CREDENTIAL_ID_BYTES,
      padding: false
    )
    assert_equal maximum, encoded_boundary.bytesize

    credential = owner.owner_credentials.create!(
      credential_id: encoded_boundary,
      public_key: "synthetic-public-key",
      label: "Boundary passkey",
      transports: []
    )
    assert_equal maximum, credential.credential_id.bytesize

    oversized = owner.owner_credentials.new(
      credential_id: "A" * (maximum + 1),
      public_key: "synthetic-public-key",
      label: "Oversized passkey",
      transports: []
    )
    assert_not oversized.valid?
    assert_includes oversized.errors[:credential_id], "is too long (maximum is #{maximum} characters)"
  end
end
