# frozen_string_literal: true

require "test_helper"

require "base64"
require "cbor"
require "digest"
require "nokogiri"
require "openssl"
require "securerandom"
require "webauthn/fake_client"

class OwnerRegistrationTest < ActionDispatch::IntegrationTest
  REQUEST_HEADERS = {
    "Host" => "localhost",
    "Origin" => "http://localhost",
    "Sec-Fetch-Site" => "same-origin",
    "Sec-Fetch-Mode" => "cors",
    "Sec-Fetch-Dest" => "empty"
  }.freeze

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_rp_id = ENV["SHORTBREAD_OWNER_RP_ID"]
    @previous_origin = ENV["SHORTBREAD_OWNER_ORIGIN"]
    ENV["SHORTBREAD_OWNER_RP_ID"] = "localhost"
    ENV["SHORTBREAD_OWNER_ORIGIN"] = "http://localhost"
    @sensitive_values = []

    get "/owner/bootstrap", headers: { "Host" => "localhost" }
    assert_response :ok
    @csrf_token = Nokogiri::HTML5(response.body)
      .at_css('meta[name="csrf-token"]')
      &.[]("content")
    assert_not_nil @csrf_token
    @bootstrap_session_cookie = cookies["shortbread_apex"]
    assert_not_nil @bootstrap_session_cookie
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    ENV["SHORTBREAD_OWNER_RP_ID"] = @previous_rp_id
    ENV["SHORTBREAD_OWNER_ORIGIN"] = @previous_origin
    @sensitive_values.each(&:clear)
  end

  test "deployment ceremony creates the first Owner and passkey atomically on its configured apex" do
    ceremony, ceremony_secret = issue_ceremony
    _expired, expired_secret = issue_ceremony(expires_at: 1.second.ago)
    invalid_secret = sensitive(SecureRandom.urlsafe_base64(32, false))
    request_headers = REQUEST_HEADERS.merge("X-CSRF-Token" => @csrf_token)

    assert_no_difference -> { Owner.count } do
      post "/owner/bootstrap/options",
        params: { ceremony_secret: },
        headers: request_headers.merge("Host" => "first-site.sites.localhost"),
        as: :json
      assert_response :not_found

      [
        { "Host" => "shortbread.chriszempel.com" },
        { "X-Forwarded-Host" => "shortbread.chriszempel.com" }
      ].each do |host_headers|
        post "/owner/bootstrap/options",
          params: { ceremony_secret: },
          headers: request_headers.merge(host_headers),
          as: :json
        assert_response :not_found
      end

      post "/owner/bootstrap/options",
        params: { ceremony_secret: },
        headers: request_headers.merge("Origin" => "http://first-site.sites.localhost"),
        as: :json
      assert_response :not_found

      [
        request_headers.except("Origin"),
        request_headers.merge("Sec-Fetch-Site" => "cross-site"),
        request_headers.merge("Sec-Fetch-Mode" => "navigate"),
        request_headers.merge("Sec-Fetch-Dest" => "document"),
        request_headers.except("X-CSRF-Token"),
        request_headers.merge("X-CSRF-Token" => "invalid-synthetic-csrf-token")
      ].each do |rejected_headers|
        post "/owner/bootstrap/options",
          params: { ceremony_secret: },
          headers: rejected_headers,
          as: :json
        assert_response :not_found
      end

      post "/owner/bootstrap/options",
        params: { ceremony_secret: invalid_secret },
        headers: request_headers,
        as: :json
      assert_response :not_found

      post "/owner/bootstrap/options",
        params: { ceremony_secret: expired_secret },
        headers: request_headers,
        as: :json
      assert_response :not_found

      assert_no_difference -> { ceremony_model.count } do
        post "/owner/bootstrap/issue",
          params: { ceremony_secret: },
          headers: request_headers,
          as: :json
        assert_response :not_found
      end
    end

    post "/owner/bootstrap/options",
      params: { ceremony_secret: },
      headers: request_headers,
      as: :json

    assert_response :ok
    public_key = response.parsed_body.fetch("public_key")
    assert_equal "localhost", public_key.dig("rp", "id")
    assert_equal "Shortbread", public_key.dig("rp", "name")
    assert_equal "Owner", public_key.dig("user", "name")
    assert_equal "required", public_key.dig("authenticatorSelection", "userVerification")
    assert_equal "required", public_key.dig("authenticatorSelection", "residentKey")
    assert_equal true, public_key.dig("authenticatorSelection", "requireResidentKey")
    assert_equal 0, Owner.count
    assert_equal 0, table_count("owner_credentials")

    wrong_origin_credential = WebAuthn::FakeClient
      .new("http://wrong.localhost")
      .create(challenge: public_key.fetch("challenge"), rp_id: "localhost", user_verified: true)

    assert_no_difference -> { Owner.count } do
      post "/owner/bootstrap",
        params: {
          ceremony_secret:,
          credential_label: "Primary passkey",
          public_key_credential: wrong_origin_credential
        },
        headers: request_headers,
        as: :json
      assert_response :not_found
    end
    assert_nil ceremony_model.find(ceremony.id).consumed_at

    valid_credential = WebAuthn::FakeClient
      .new("http://localhost")
      .create(challenge: public_key.fetch("challenge"), rp_id: "localhost", user_verified: true)

    unbound_id_credential = valid_credential.deep_dup
    unbound_id = Base64.urlsafe_encode64("attacker-selected-credential-id", padding: false)
    unbound_id_credential["id"] = unbound_id
    unbound_id_credential["rawId"] = unbound_id
    mismatched_id_credential = valid_credential.deep_dup
    mismatched_id_credential["id"] = Base64.urlsafe_encode64("mismatched-credential-id", padding: false)
    malformed_attestation_credential = valid_credential.deep_dup
    malformed_attestation_credential["response"]["attestationObject"] = Base64.urlsafe_encode64(
      "malformed-attestation",
      padding: false
    )
    tpm_attestation_credential = valid_credential.deep_dup
    tpm_attestation_object = CBOR.decode(
      Base64.urlsafe_decode64(valid_credential.dig("response", "attestationObject"))
    )
    tpm_attestation_object["fmt"] = "tpm"
    tpm_attestation_object["attStmt"] = {}
    tpm_attestation_credential["response"]["attestationObject"] = Base64.urlsafe_encode64(
      CBOR.encode(tpm_attestation_object),
      padding: false
    )
    unknown_algorithm_credential = valid_credential.deep_dup
    unknown_algorithm_attestation = CBOR.decode(
      Base64.urlsafe_decode64(valid_credential.dig("response", "attestationObject"))
    )
    authenticator_data = unknown_algorithm_attestation.fetch("authData")
    credential_id_length = authenticator_data.byteslice(53, 2).unpack1("n")
    public_key_offset = 55 + credential_id_length
    public_key = CBOR.decode(authenticator_data.byteslice(public_key_offset..))
    public_key[3] = 999
    unknown_algorithm_attestation["authData"] =
      authenticator_data.byteslice(0, public_key_offset) + CBOR.encode(public_key)
    unknown_algorithm_credential["response"]["attestationObject"] = Base64.urlsafe_encode64(
      CBOR.encode(unknown_algorithm_attestation),
      padding: false
    )
    unsupported_curve_credential = valid_credential.deep_dup
    unsupported_curve_attestation = CBOR.decode(
      Base64.urlsafe_decode64(valid_credential.dig("response", "attestationObject"))
    )
    authenticator_data = unsupported_curve_attestation.fetch("authData")
    credential_id_length = authenticator_data.byteslice(53, 2).unpack1("n")
    public_key_offset = 55 + credential_id_length
    public_key = CBOR.decode(authenticator_data.byteslice(public_key_offset..))
    public_key[-1] = 999
    unsupported_curve_attestation["authData"] =
      authenticator_data.byteslice(0, public_key_offset) + CBOR.encode(public_key)
    unsupported_curve_credential["response"]["attestationObject"] = Base64.urlsafe_encode64(
      CBOR.encode(unsupported_curve_attestation),
      padding: false
    )
    mismatched_curve_credential = valid_credential.deep_dup
    mismatched_curve_attestation = CBOR.decode(
      Base64.urlsafe_decode64(valid_credential.dig("response", "attestationObject"))
    )
    authenticator_data = mismatched_curve_attestation.fetch("authData")
    credential_id_length = authenticator_data.byteslice(53, 2).unpack1("n")
    public_key_offset = 55 + credential_id_length
    p384_public_key = COSE::Key::EC2
      .from_pkey(OpenSSL::PKey::EC::Group.new("secp384r1").generator)
      .map
      .merge(3 => -7)
    mismatched_curve_attestation["authData"] =
      authenticator_data.byteslice(0, public_key_offset) + CBOR.encode(p384_public_key)
    mismatched_curve_credential["response"]["attestationObject"] = Base64.urlsafe_encode64(
      CBOR.encode(mismatched_curve_attestation),
      padding: false
    )
    private_key_credential = valid_credential.deep_dup
    private_key_attestation = CBOR.decode(
      Base64.urlsafe_decode64(valid_credential.dig("response", "attestationObject"))
    )
    authenticator_data = private_key_attestation.fetch("authData")
    credential_id_length = authenticator_data.byteslice(53, 2).unpack1("n")
    public_key_offset = 55 + credential_id_length
    p256_private_key = COSE::Key::EC2
      .from_pkey(OpenSSL::PKey::EC::Group.new("prime256v1").generator)
      .map
      .merge(3 => -7, -4 => "\x01".b)
    private_key_attestation["authData"] =
      authenticator_data.byteslice(0, public_key_offset) + CBOR.encode(p256_private_key)
    private_key_credential["response"]["attestationObject"] = Base64.urlsafe_encode64(
      CBOR.encode(private_key_attestation),
      padding: false
    )

    {
      "Unbound passkey ID" => unbound_id_credential,
      "Mismatched passkey" => mismatched_id_credential,
      "Malformed attestation" => malformed_attestation_credential,
      "TPM attestation" => tpm_attestation_credential,
      "Unknown credential algorithm" => unknown_algorithm_credential,
      "Unsupported credential curve" => unsupported_curve_credential,
      "Credential curve incompatible with ES256" => mismatched_curve_credential,
      "Credential containing private key material" => private_key_credential
    }.each do |label, attacker_credential|
      assert_no_difference -> { Owner.count }, -> { table_count("owner_credentials") } do
        post "/owner/bootstrap",
          params: {
            ceremony_secret:,
            credential_label: label,
            public_key_credential: attacker_credential
          },
          headers: request_headers,
          as: :json
        assert_response :not_found
      end
      assert_nil ceremony_model.find(ceremony.id).consumed_at
    end

    assert_no_difference -> { Owner.count }, -> { table_count("owner_credentials") } do
      post "/owner/bootstrap",
        params: {
          ceremony_secret:,
          credential_label: "Malformed passkey",
          public_key_credential: { type: "public-key" }
        },
        headers: request_headers,
        as: :json
      assert_response :not_found
    end
    assert_nil ceremony_model.find(ceremony.id).consumed_at

    assert_difference -> { Owner.count } => 1, -> { table_count("owner_credentials") } => 1 do
      post "/owner/bootstrap",
        params: {
          ceremony_secret:,
          credential_label: "Primary passkey",
          public_key_credential: valid_credential
        },
        headers: request_headers,
        as: :json
      assert_response :created
    end

    owner = Owner.sole
    stored_credential = credential_model.find_by!(owner_id: owner.id)
    assert_equal valid_credential.fetch("id"), stored_credential.credential_id
    assert_equal "Primary passkey", stored_credential.label
    assert_not_nil ceremony_model.find(ceremony.id).consumed_at
    assert_equal({ "owner" => { "id" => owner.id }, "redirect" => "/owner" }, response.parsed_body)
    owner_cookie = Array(response.headers["Set-Cookie"]).join("\n")
    assert_match(/(?:\A|\n)shortbread_apex=/, owner_cookie)
    assert_includes owner_cookie, "path=/"
    assert_includes owner_cookie.downcase, "httponly"
    refute_equal @bootstrap_session_cookie, cookies["shortbread_apex"]

    get "/owner", headers: { "Host" => "localhost" }

    assert_response :ok
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.body, "Owner landing"

    get "/owner", headers: { "Host" => "first-site.sites.localhost" }
    assert_response :not_found

    assert_no_difference -> { Owner.count } do
      post "/owner/bootstrap",
        params: {
          ceremony_secret:,
          credential_label: "Replay",
          public_key_credential: valid_credential
        },
        headers: request_headers,
        as: :json
      assert_response :not_found
    end
    assert_equal 1, table_count("owner_credentials")
  end

  test "registration accepts an RP-allowed RSA public credential" do
    _ceremony, ceremony_secret = issue_ceremony
    request_headers = REQUEST_HEADERS.merge("X-CSRF-Token" => @csrf_token)

    post "/owner/bootstrap/options",
      params: { ceremony_secret: },
      headers: request_headers,
      as: :json
    assert_response :ok

    public_key = response.parsed_body.fetch("public_key")
    rsa_credential = WebAuthn::FakeClient
      .new("http://localhost")
      .create(
        challenge: public_key.fetch("challenge"),
        rp_id: "localhost",
        user_verified: true,
        credential_algorithm: "RS256"
      )

    assert_difference -> { Owner.count } => 1, -> { table_count("owner_credentials") } => 1 do
      post "/owner/bootstrap",
        params: {
          ceremony_secret:,
          credential_label: "RSA passkey",
          public_key_credential: rsa_credential
        },
        headers: request_headers,
        as: :json
      assert_response :created
    end

    assert_equal rsa_credential.fetch("id"), credential_model.find_by!(owner_id: Owner.sole.id).credential_id
  end

  test "completion rejects a ceremony that expires after options were issued" do
    ceremony, ceremony_secret = issue_ceremony(expires_at: 1.second.from_now)
    request_headers = REQUEST_HEADERS.merge("X-CSRF-Token" => @csrf_token)

    post "/owner/bootstrap/options",
      params: { ceremony_secret: },
      headers: request_headers,
      as: :json
    assert_response :ok
    public_key = response.parsed_body.fetch("public_key")
    credential = WebAuthn::FakeClient
      .new("http://localhost")
      .create(challenge: public_key.fetch("challenge"), rp_id: "localhost", user_verified: true)

    travel 2.seconds do
      assert_no_difference -> { Owner.count }, -> { table_count("owner_credentials") } do
        post "/owner/bootstrap",
          params: {
            ceremony_secret:,
            credential_label: "Expired passkey",
            public_key_credential: credential
          },
          headers: request_headers,
          as: :json
        assert_response :not_found
      end
    end
    assert_nil ceremony.reload.consumed_at
  end

  private

  def issue_ceremony(expires_at: 10.minutes.from_now)
    secret = sensitive(SecureRandom.urlsafe_base64(32, false))
    ceremony = ceremony_model.create!(
      purpose: "bootstrap",
      authority: "deployment",
      secret_digest: Digest::SHA256.hexdigest(secret),
      expires_at:
    )
    [ ceremony, secret ]
  end

  def ceremony_model
    @ceremony_model ||= Class.new(ApplicationRecord) do
      self.table_name = "owner_ceremonies"
    end
  end

  def credential_model
    @credential_model ||= Class.new(ApplicationRecord) do
      self.table_name = "owner_credentials"
    end
  end

  def table_count(name)
    ApplicationRecord.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i
  end

  def sensitive(value)
    @sensitive_values << value
    value
  end
end
