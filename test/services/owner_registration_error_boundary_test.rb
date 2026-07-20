# frozen_string_literal: true

require "test_helper"

require "base64"
require "securerandom"

class OwnerRegistrationErrorBoundaryTest < ActiveSupport::TestCase
  ORIGIN = "http://localhost"
  RP_ID = "localhost"

  class UnexpectedVerificationError < RuntimeError; end

  class RelyingPartySeam
    def initialize(error)
      @error = error
    end

    def verify_registration(*)
      raise @error
    end
  end

  class WebAuthnSeam
    attr_reader :origin, :rp_id

    def initialize(relying_party: nil, relying_party_error: nil)
      @origin = ORIGIN
      @rp_id = RP_ID
      @relying_party = relying_party
      @relying_party_error = relying_party_error
    end

    def relying_party
      raise @relying_party_error if @relying_party_error

      @relying_party
    end
  end

  setup do
    @secret = SecureRandom.urlsafe_base64(32, false)
    OwnerCeremony.issue_bootstrap!(secret: @secret).update!(
      challenge: "synthetic-registration-challenge",
      origin: ORIGIN,
      rp_id: RP_ID
    )
  end

  teardown do
    @secret.clear
  end

  test "an unexpected relying-party construction exception escapes" do
    injected_error = UnexpectedVerificationError.new("synthetic construction fault")
    webauthn = WebAuthnSeam.new(relying_party_error: injected_error)

    raised_error = assert_raises(UnexpectedVerificationError) do
      complete_with(webauthn:)
    end

    assert_same injected_error, raised_error
  end

  test "an unexpected verifier exception escapes" do
    injected_error = UnexpectedVerificationError.new("synthetic verifier fault")
    webauthn = WebAuthnSeam.new(relying_party: RelyingPartySeam.new(injected_error))

    raised_error = assert_raises(UnexpectedVerificationError) do
      complete_with(webauthn:)
    end

    assert_same injected_error, raised_error
  end

  private

  def complete_with(webauthn:)
    OwnerRegistration.complete!(
      secret: @secret,
      label: "Synthetic passkey",
      public_key_credential: public_key_credential,
      webauthn:
    )
  end

  def public_key_credential
    credential_id = Base64.urlsafe_encode64("synthetic-credential-id", padding: false)

    {
      "id" => credential_id,
      "rawId" => credential_id,
      "type" => "public-key",
      "clientExtensionResults" => {},
      "response" => {
        "attestationObject" => Base64.urlsafe_encode64("synthetic-attestation", padding: false),
        "clientDataJSON" => Base64.urlsafe_encode64("synthetic-client-data", padding: false),
        "transports" => []
      }
    }
  end
end
