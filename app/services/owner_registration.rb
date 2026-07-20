# frozen_string_literal: true

require "base64"
require "cbor"
require "digest"
require "json"
require "openssl"
require "webauthn"

class OwnerRegistration
  ATTESTATION_OBJECT_KEYS = %w[attStmt authData fmt].freeze
  AUTHENTICATOR_DATA_MINIMUM_BYTES = 37
  BASE64URL_FORMAT = /\A[A-Za-z0-9_-]+\z/
  MAX_ATTESTATION_BYTES = 131_072
  MAX_AUTHENTICATOR_ATTACHMENT_BYTES = 64
  MAX_CLIENT_DATA_BYTES = 16_384
  MAX_CREDENTIAL_ID_BYTES = 1_024
  SECRET_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
  VERIFICATION_INPUT_ERRORS = [
    WebAuthn::Error,
    CBOR::UnpackError,
    CBOR::TypeError,
    JSON::ParserError,
    COSE::Error,
    ArgumentError,
    TypeError,
    EncodingError,
    OpenSSL::OpenSSLError
  ].freeze

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
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
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

      credential = verify_registration(public_key_credential, challenge: ceremony.challenge)
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

    decoded_id = decode_base64url(credential["id"], maximum: MAX_CREDENTIAL_ID_BYTES)
    decoded_raw_id = decode_base64url(credential["rawId"], maximum: MAX_CREDENTIAL_ID_BYTES)
    return false unless decoded_id && decoded_raw_id && decoded_id.bytesize == decoded_raw_id.bytesize
    return false unless ActiveSupport::SecurityUtils.fixed_length_secure_compare(decoded_id, decoded_raw_id)
    return false unless optional_bounded_string?(
      credential["authenticatorAttachment"],
      maximum: MAX_AUTHENTICATOR_ATTACHMENT_BYTES
    )
    return false unless credential["clientExtensionResults"].nil? ||
      credential["clientExtensionResults"].is_a?(Hash)

    response = credential["response"]
    return false unless response.is_a?(Hash)
    return false unless valid_none_attestation_object?(response["attestationObject"])
    return false unless decode_base64url(response["clientDataJSON"], maximum: MAX_CLIENT_DATA_BYTES)

    transports = response["transports"]
    transports.nil? || transports.is_a?(Array) &&
      transports.length <= OwnerCredential::TRANSPORTS.length &&
      transports.all? { |transport| OwnerCredential::TRANSPORTS.include?(transport) }
  end

  def verify_registration(public_key_credential, challenge:)
    relying_party = webauthn.relying_party

    begin
      relying_party.verify_registration(
        public_key_credential,
        challenge,
        user_verification: true
      )
    rescue *VERIFICATION_INPUT_ERRORS
      reject!
    end
  end

  def valid_none_attestation_object?(encoded_attestation_object)
    attestation_bytes = decode_base64url(encoded_attestation_object, maximum: MAX_ATTESTATION_BYTES)
    return false unless attestation_bytes

    attestation_object = CBOR.decode(attestation_bytes)
    return false unless attestation_object.is_a?(Hash) &&
      attestation_object.size == ATTESTATION_OBJECT_KEYS.size &&
      ATTESTATION_OBJECT_KEYS.all? { |key| attestation_object.key?(key) }
    return false unless attestation_object["fmt"] == "none" && attestation_object["attStmt"] == {}

    authenticator_data = attestation_object["authData"]
    authenticator_data.is_a?(String) && authenticator_data.encoding == Encoding::BINARY &&
      authenticator_data.bytesize.between?(AUTHENTICATOR_DATA_MINIMUM_BYTES, MAX_ATTESTATION_BYTES)
  rescue CBOR::UnpackError, CBOR::TypeError
    false
  end

  def decode_base64url(value, maximum:)
    return unless bounded_string?(value, maximum:) && value.match?(BASE64URL_FORMAT)

    decoded = Base64.urlsafe_decode64(value)
    return unless Base64.urlsafe_encode64(decoded, padding: false) == value

    decoded
  rescue ArgumentError
    nil
  end

  def optional_bounded_string?(value, maximum:)
    value.nil? || bounded_string?(value, maximum:)
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
