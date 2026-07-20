# frozen_string_literal: true

require "test_helper"

require "base64"
require "digest"
require "nokogiri"
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

    mismatched_id_credential = valid_credential.deep_dup
    mismatched_id_credential["id"] = Base64.urlsafe_encode64("mismatched-credential-id", padding: false)
    malformed_attestation_credential = valid_credential.deep_dup
    malformed_attestation_credential["response"]["attestationObject"] = Base64.urlsafe_encode64(
      "malformed-attestation",
      padding: false
    )

    {
      "Mismatched passkey" => mismatched_id_credential,
      "Malformed attestation" => malformed_attestation_credential
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
