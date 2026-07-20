# frozen_string_literal: true

require "test_helper"

class HostAuthorizationTest < ActionDispatch::IntegrationTest
  test "the exact apex reaches the health route" do
    get "/up", headers: { "Host" => "localhost" }

    assert_response :ok
  end

  test "an allowed Site host cannot reach the apex health route" do
    get "/up", headers: { "Host" => "first-site.sites.localhost" }

    assert_response :not_found
    assert_empty response.body
  end

  test "public apex files are never served directly from a Site host" do
    get "/robots.txt", headers: { "Host" => "localhost" }

    assert_response :ok
    assert_predicate response.body, :present?

    public_paths = [ "/robots.txt" ]
    vite_asset = Dir[Rails.root.join("public/vite/assets/*")].find { |path| File.file?(path) }
    public_paths << "/#{Pathname(vite_asset).relative_path_from(Rails.root.join("public"))}" if vite_asset

    public_paths.each do |path|
      get path, headers: { "Host" => "first-site.sites.localhost" }

      assert_response :not_found
      assert_empty response.body
      refute_equal "public, max-age=3600", response.headers["Cache-Control"]
    end
  end

  test "an authenticated Producer cannot mutate the apex API from a Site host" do
    previous_token = ENV["SHORTBREAD_BOOTSTRAP_TOKEN"]
    token = "SYNTHETIC_HOST_AUTHORIZATION_TOKEN"
    ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = token

    assert_no_difference -> { Site.count } do
      post "/api/v1/sites",
        params: { slug: "blocked-site", name: "Blocked Site" },
        headers: {
          "Host" => "first-site.sites.localhost",
          "Authorization" => "Bearer #{token}"
        },
        as: :json
    end

    assert_response :not_found
    assert_empty response.body
  ensure
    ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = previous_token
  end

  test "unknown, deeper, malformed, and forwarded hosts fail before health routing" do
    attempts = [
      { "Host" => "wrong.example" },
      { "Host" => "extra.first-site.sites.localhost" },
      { "Host" => "first-site.sites.localhost.attacker.test" },
      { "Host" => "bad_host" },
      { "Host" => "localhost", "X-Forwarded-Host" => "wrong.example" },
      { "Host" => "wrong.example", "X-Forwarded-Host" => "localhost" }
    ]

    attempts.each do |headers|
      get "/up", headers: headers

      assert_response :not_found
      assert_empty response.body
    end
  end
end
