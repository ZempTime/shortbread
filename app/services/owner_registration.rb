# frozen_string_literal: true

require "base64"
require "cbor"
require "digest"
require "json"
require "openssl"

class OwnerRegistration
  MAX_ATTESTATION_BYTES = 131_072
  MAX_CLIENT_DATA_BYTES = 16_384
  MAX_CREDENTIAL_ID_BYTES = 2_048
  SECRET_FORMAT = /\A[A-Za-z0-9_-]{43}\z/

  Result = Data.define(:owner)

  class Rejected < StandardError
    def initialize = super("Owner registration rejected")
  end

  class << self
    def options!(secret:, webauthn:, now: Time.current)
      new(webauthn:).options!(secret:, now:)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      raise Rejected
    end

    def complete!(secret:, label:, public_key_credential:, webauthn:, now: Time.current)
      new(webauthn:).complete!(secret:, label:, public_key_credential:, now:)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, WebAuthn::Error,
      JSON::ParserError, CBOR::UnpackError, CBOR::TypeError, ArgumentError, TypeError
      raise Rejected
    end
  end

  def initialize(webauthn:)
    @webauthn = webauthn
  end

  def options!(secret:, now:)
    digest = secret_digest(secret)

    OwnerCeremony.transaction do
      ceremony = available_ceremony!(digest:, now:)
      reject! if Owner.exists?

      options = webauthn.relying_party.options_for_registration(
        user: {
          id: owner_webauthn_id(ceremony),
          name: "Owner",
          display_name: "Owner"
        },
        authenticator_selection: { user_verification: "required" },
        attestation: "none"
      )
      ceremony.update!(challenge: options.challenge, origin: webauthn.origin, rp_id: webauthn.rp_id)

      options.as_json
    end
  end

  def complete!(secret:, label:, public_key_credential:, now:)
    digest = secret_digest(secret)
    reject! unless label.is_a?(String) && label.present? && label.bytesize <= 100
    reject! unless valid_public_key_credential_shape?(public_key_credential)

    OwnerCeremony.transaction do
      ceremony = available_ceremony!(digest:, now:)
      reject! if Owner.exists?
      reject! unless ceremony.challenge.present? &&
        ceremony.origin == webauthn.origin && ceremony.rp_id == webauthn.rp_id

      credential = webauthn.relying_party.verify_registration(
        public_key_credential,
        ceremony.challenge,
        user_verification: true
      )
      reject! unless credential

      owner = Owner.create!(webauthn_id: owner_webauthn_id(ceremony))
      owner.owner_credentials.create!(
        credential_id: credential.id,
        public_key: credential.public_key,
        sign_count: credential.sign_count,
        label:,
        transports: credential.response.transports || []
      )
      ceremony.update!(consumed_at: now)

      Result.new(owner:)
    end
  end

  private

  attr_reader :webauthn

  def available_ceremony!(digest:, now:)
    ceremony = OwnerCeremony.lock.find_by(secret_digest: digest)
    reject! unless ceremony&.available_bootstrap?(now:)

    ceremony
  end

  def owner_webauthn_id(ceremony)
    material = OpenSSL::HMAC.digest(
      "SHA256",
      Rails.application.secret_key_base,
      "shortbread-owner-v1:#{ceremony.id}:#{ceremony.secret_digest}"
    )
    Base64.urlsafe_encode64(material, padding: false)
  end

  def valid_public_key_credential_shape?(credential)
    return false unless credential.is_a?(Hash) && credential["type"] == "public-key"
    return false unless bounded_string?(credential["id"], maximum: MAX_CREDENTIAL_ID_BYTES)
    return false unless bounded_string?(credential["rawId"], maximum: MAX_CREDENTIAL_ID_BYTES)

    response = credential["response"]
    return false unless response.is_a?(Hash)
    return false unless bounded_string?(response["attestationObject"], maximum: MAX_ATTESTATION_BYTES)
    return false unless bounded_string?(response["clientDataJSON"], maximum: MAX_CLIENT_DATA_BYTES)

    transports = response["transports"]
    transports.nil? || transports.is_a?(Array)
  end

  def bounded_string?(value, maximum:)
    value.is_a?(String) && value.bytesize.between?(1, maximum)
  end

  def secret_digest(secret)
    reject! unless secret.is_a?(String) && secret.match?(SECRET_FORMAT)

    Digest::SHA256.hexdigest(secret)
  end

  def reject!
    raise Rejected
  end
end
