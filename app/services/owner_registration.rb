# frozen_string_literal: true

require "base64"
require "cbor"
require "digest"
require "json"
require "openssl"
require "stringio"
require "webauthn"

class OwnerRegistration
  AAGUID_BYTES = 16
  ATTESTED_CREDENTIAL_DATA_FLAG = 0b0100_0000
  ATTESTATION_OBJECT_KEYS = %w[attStmt authData fmt].freeze
  AUTHENTICATOR_FLAGS_OFFSET = 32
  AUTHENTICATOR_DATA_MINIMUM_BYTES = 37
  BASE64URL_FORMAT = /\A[A-Za-z0-9_-]+\z/
  CREDENTIAL_ID_LENGTH_BYTES = 2
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

  AttestedCredentialData = Data.define(:id, :algorithm)
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
        authenticator_selection: {
          user_verification: "required",
          resident_key: "required",
          require_resident_key: true
        },
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
    attested_credential = parse_none_attested_credential(response["attestationObject"])
    return false unless attested_credential &&
      webauthn.relying_party.algorithms.include?(attested_credential.algorithm)
    return false unless decoded_raw_id.bytesize == attested_credential.id.bytesize
    return false unless ActiveSupport::SecurityUtils.fixed_length_secure_compare(
      decoded_raw_id,
      attested_credential.id
    )
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

  def parse_none_attested_credential(encoded_attestation_object)
    attestation_bytes = decode_base64url(encoded_attestation_object, maximum: MAX_ATTESTATION_BYTES)
    return unless attestation_bytes

    attestation_object = CBOR.decode(attestation_bytes)
    return unless attestation_object.is_a?(Hash) &&
      attestation_object.size == ATTESTATION_OBJECT_KEYS.size &&
      ATTESTATION_OBJECT_KEYS.all? { |key| attestation_object.key?(key) }
    return unless attestation_object["fmt"] == "none" && attestation_object["attStmt"] == {}

    authenticator_data = attestation_object["authData"]
    return unless authenticator_data.is_a?(String) && authenticator_data.encoding == Encoding::BINARY &&
      authenticator_data.bytesize.between?(AUTHENTICATOR_DATA_MINIMUM_BYTES, MAX_ATTESTATION_BYTES)
    authenticator_flags = authenticator_data.getbyte(AUTHENTICATOR_FLAGS_OFFSET)
    return unless (authenticator_flags & ATTESTED_CREDENTIAL_DATA_FLAG).positive?

    credential_id_length_offset = AUTHENTICATOR_DATA_MINIMUM_BYTES + AAGUID_BYTES
    credential_id_offset = credential_id_length_offset + CREDENTIAL_ID_LENGTH_BYTES
    credential_id_length_bytes = authenticator_data.byteslice(
      credential_id_length_offset,
      CREDENTIAL_ID_LENGTH_BYTES
    )
    return unless credential_id_length_bytes&.bytesize == CREDENTIAL_ID_LENGTH_BYTES

    credential_id_length = credential_id_length_bytes.unpack1("n")
    return unless credential_id_length.between?(1, MAX_CREDENTIAL_ID_BYTES)

    public_key_offset = credential_id_offset + credential_id_length
    return unless public_key_offset < authenticator_data.bytesize

    credential_id = authenticator_data.byteslice(credential_id_offset, credential_id_length)
    return unless credential_id&.bytesize == credential_id_length

    public_key_bytes = authenticator_data.byteslice(public_key_offset..)
    public_key_map = CBOR::Unpacker.new(StringIO.new(public_key_bytes)).each.first
    return unless public_key_map.is_a?(Hash)

    cose_key = COSE::Key.deserialize(CBOR.encode(public_key_map))
    algorithm = COSE::Algorithm.find(cose_key.alg)
    return unless algorithm && compatible_cose_public_key?(algorithm, cose_key)

    AttestedCredentialData.new(id: credential_id, algorithm: algorithm.name)
  rescue CBOR::UnpackError, CBOR::TypeError, COSE::Error, ArgumentError, TypeError, EncodingError
    nil
  end

  def compatible_cose_public_key?(algorithm, cose_key)
    return false unless public_cose_key?(cose_key)
    return false if algorithm.is_a?(COSE::Algorithm::ECDSA) &&
      (!cose_key.is_a?(COSE::Key::EC2) || cose_key.curve != algorithm.curve)

    !!algorithm.compatible_key?(cose_key)
  rescue COSE::Error, OpenSSL::OpenSSLError, ArgumentError, TypeError, RuntimeError, NoMethodError
    false
  end

  def public_cose_key?(cose_key)
    case cose_key
    when COSE::Key::EC2
      cose_key.d.nil?
    when COSE::Key::RSA
      [ cose_key.d, cose_key.p, cose_key.q, cose_key.dp, cose_key.dq, cose_key.qinv ].all?(&:nil?)
    else
      false
    end
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
