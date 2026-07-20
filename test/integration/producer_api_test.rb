# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"

class ProducerApiTest < ActionDispatch::IntegrationTest
  test "a producer cannot create a Site without the local bootstrap bearer" do
    host! "localhost"

    post "/api/v1/sites", params: { slug: "first-site", name: "First Site" }, as: :json

    assert_response :unauthorized
    assert_equal "authentication_required", response.parsed_body.dig("error", "code")
  end

  test "an authenticated local Producer creates a Site" do
    with_bootstrap_token do |token|
      host! "localhost"

      post "/api/v1/sites",
        params: { slug: "first-site", name: "First Site" },
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      assert_response :created
      assert_equal({ "slug" => "first-site", "name" => "First Site" },
        response.parsed_body.fetch("site").slice("slug", "name"))
    end
  end

  test "a raw credential without the exact Bearer scheme is rejected" do
    with_bootstrap_token do |token|
      host! "localhost"

      assert_no_difference -> { Site.count } do
        post "/api/v1/sites",
          params: { slug: "first-site", name: "First Site" },
          headers: { "Authorization" => token },
          as: :json
      end

      assert_response :unauthorized
    end
  end

  test "invalid and duplicate Site input has stable errors" do
    with_bootstrap_token do |token|
      host! "localhost"
      headers = { "Authorization" => "Bearer #{token}" }

      post "/api/v1/sites", params: { slug: "../unsafe", name: "Unsafe" }, headers:, as: :json
      assert_response :unprocessable_entity
      assert_equal "invalid_site", response.parsed_body.dig("error", "code")

      post "/api/v1/sites", params: { slug: "first-site", name: "First Site" }, headers:, as: :json
      assert_response :created

      post "/api/v1/sites", params: { slug: "first-site", name: "Duplicate" }, headers:, as: :json
      assert_response :conflict
      assert_equal "site_exists", response.parsed_body.dig("error", "code")
    end
  end

  test "an authenticated local Producer adds a Person" do
    with_bootstrap_token do |token|
      host! "localhost"

      post "/api/v1/people",
        params: { first_name: "Avery" },
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      assert_response :created
      assert_equal "Avery", response.parsed_body.dig("person", "first_name")
      assert_equal "Avery", Person.find(response.parsed_body.dig("person", "id")).first_name

      filtered = ActiveSupport::ParameterFilter
        .new(Rails.application.config.filter_parameters)
        .filter("first_name" => "PRIVATE_PERSON_MARKER")
      assert_equal "[FILTERED]", filtered.fetch("first_name")
    end
  end

  test "an authenticated local Producer grants a Person access to a Site" do
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")

    with_bootstrap_token do |token|
      host! "localhost"

      post "/api/v1/grants",
        params: { site_slug: site.slug, person_id: person.id },
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      assert_response :created
      assert_equal({ "site_slug" => site.slug, "person_id" => person.id },
        response.parsed_body.fetch("grant").slice("site_slug", "person_id"))
      assert Grant.exists?(site:, person:)
    end
  end

  test "People may share a first name while blank names fail with a stable error" do
    with_bootstrap_token do |token|
      host! "localhost"
      headers = { "Authorization" => "Bearer #{token}" }

      2.times do
        post "/api/v1/people", params: { first_name: "Avery" }, headers:, as: :json
        assert_response :created
      end
      assert_equal 2, Person.where(first_name: "Avery").count

      assert_no_difference -> { Person.count } do
        post "/api/v1/people", params: { first_name: "" }, headers:, as: :json
      end
      assert_response :unprocessable_entity
      assert_equal "invalid_person", response.parsed_body.dig("error", "code")
    end
  end

  test "duplicate and missing Grant references fail closed with stable errors" do
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")

    with_bootstrap_token do |token|
      host! "localhost"
      headers = { "Authorization" => "Bearer #{token}" }
      params = { site_slug: site.slug, person_id: person.id }

      post "/api/v1/grants", params:, headers:, as: :json
      assert_response :created

      assert_no_difference -> { Grant.count } do
        post "/api/v1/grants", params:, headers:, as: :json
      end
      assert_response :conflict
      assert_equal "grant_exists", response.parsed_body.dig("error", "code")

      assert_no_difference -> { Grant.count } do
        post "/api/v1/grants",
          params: { site_slug: "missing-site", person_id: person.id }, headers:, as: :json
      end
      assert_response :not_found
      assert_equal "site_not_found", response.parsed_body.dig("error", "code")

      assert_no_difference -> { Grant.count } do
        post "/api/v1/grants",
          params: { site_slug: site.slug, person_id: 0 }, headers:, as: :json
      end
      assert_response :not_found
      assert_equal "person_not_found", response.parsed_body.dig("error", "code")
    end
  end

  test "an authenticated local Producer issues a digest-only Invitation" do
    grant = create_grant
    secret = SecureRandom.urlsafe_base64(32, false)
    secret_digest = Digest::SHA256.hexdigest(secret)

    with_bootstrap_token do |token|
      host! "localhost"

      post "/api/v1/grants/#{grant.id}/invitations",
        params: { secret_digest: },
        headers: { "Authorization" => "Bearer #{token}" },
        as: :json

      assert_response :created
      payload = response.parsed_body.fetch("invitation")
      assert_equal %w[expires_at id locator status], payload.keys.sort
      assert_equal "pending", payload.fetch("status")
      assert_match(/\A[A-Za-z0-9_-]{32}\z/, payload.fetch("locator"))

      invitation = Invitation.find(payload.fetch("id"))
      assert_equal grant, invitation.grant
      assert_equal secret_digest, invitation.secret_digest
      assert_nil invitation.accepted_at
      assert_nil invitation.revoked_at
      assert_in_delta 24.hours.from_now, invitation.expires_at, 3.seconds
      refute_includes Invitation.column_names, "secret"
      refute_includes response.body, secret
      refute_includes response.body, secret_digest

      filtered = ActiveSupport::ParameterFilter
        .new(Rails.application.config.filter_parameters)
        .filter("secret_digest" => secret_digest)
      assert_equal "[FILTERED]", filtered.fetch("secret_digest")
    end
  end

  test "Invitation issuance rejects malformed commitments and inactive Grants" do
    grant = create_grant

    with_bootstrap_token do |token|
      host! "localhost"
      headers = { "Authorization" => "Bearer #{token}" }

      [ "", "a" * 63, "A" * 64, "g" * 64 ].each do |invalid_digest|
        assert_no_difference -> { Invitation.count } do
          post "/api/v1/grants/#{grant.id}/invitations",
            params: { secret_digest: invalid_digest }, headers:, as: :json
        end
        assert_response :unprocessable_entity
        assert_equal "invalid_invitation_digest", response.parsed_body.dig("error", "code")
      end

      assert_no_difference -> { Invitation.count } do
        post "/api/v1/grants/0/invitations",
          params: { secret_digest: Digest::SHA256.hexdigest("missing") }, headers:, as: :json
      end
      assert_response :not_found
      assert_equal "grant_not_found", response.parsed_body.dig("error", "code")

      grant.update!(revoked_at: Time.current)
      assert_no_difference -> { Invitation.count } do
        post "/api/v1/grants/#{grant.id}/invitations",
          params: { secret_digest: Digest::SHA256.hexdigest("revoked") }, headers:, as: :json
      end
      assert_response :conflict
      assert_equal "grant_inactive", response.parsed_body.dig("error", "code")
    end
  end

  test "Invitation commitments are unique while one Grant may receive a rotated locator" do
    grant = create_grant
    first_digest = Digest::SHA256.hexdigest("first synthetic secret")
    second_digest = Digest::SHA256.hexdigest("second synthetic secret")

    with_bootstrap_token do |token|
      host! "localhost"
      headers = { "Authorization" => "Bearer #{token}" }

      post "/api/v1/grants/#{grant.id}/invitations",
        params: { secret_digest: first_digest }, headers:, as: :json
      assert_response :created
      first = response.parsed_body.fetch("invitation")

      assert_no_difference -> { Invitation.count } do
        post "/api/v1/grants/#{grant.id}/invitations",
          params: { secret_digest: first_digest }, headers:, as: :json
      end
      assert_response :conflict
      assert_equal "invitation_exists", response.parsed_body.dig("error", "code")

      post "/api/v1/grants/#{grant.id}/invitations",
        params: { secret_digest: second_digest }, headers:, as: :json
      assert_response :created
      second = response.parsed_body.fetch("invitation")
      refute_equal first.fetch("locator"), second.fetch("locator")
    end
  end

  private

  def create_grant
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")
    Grant.create!(site:, person:)
  end

  def with_bootstrap_token
    previous = ENV["SHORTBREAD_BOOTSTRAP_TOKEN"]
    token = SecureRandom.urlsafe_base64(32)
    ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = token
    yield token
  ensure
    ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = previous
  end
end
