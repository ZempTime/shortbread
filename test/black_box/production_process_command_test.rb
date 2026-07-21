# frozen_string_literal: true

require "test_helper"

require "json"
require "open3"
require "yaml"

class ProductionProcessCommandTest < ActiveSupport::TestCase
  VALID_ENVIRONMENT = {
    "ANYCABLE_HTTP_BROADCAST_URL" => "http://cable:8090/_broadcast",
    "ANYCABLE_RPC_HOST" => "http://shortbread.internal:3000/_anycable",
    "ANYCABLE_SECRET" => "a" * 64,
    "ANYCABLE_WEBSOCKET_URL" => "wss://shortbread.example/cable",
    "DATABASE_URL" => "postgresql://shortbread:example@postgres/shortbread_production",
    "QUEUE_DATABASE_URL" => "postgresql://shortbread:example@postgres/shortbread_production_queue",
    "RAILS_ENV" => "production",
    "SECRET_KEY_BASE" => "b" * 64,
    "SHORTBREAD_APEX_HOST" => "shortbread.example",
    "SHORTBREAD_BLOB_ROOT" => "/var/lib/shortbread/blobs",
    "SHORTBREAD_BOOTSTRAP_TOKEN" => "c" * 64
  }.freeze

  test "the shared process command validates and redacts the exact environment inventory" do
    stdout, stderr, status = run_production("config", VALID_ENVIRONMENT)

    assert status.success?, stderr
    inventory = JSON.parse(stdout)
    assert_equal Shortbread::ProductionRuntime::REQUIRED_KEYS.sort, inventory.keys.sort
    assert_equal "[configured secret]", inventory.fetch("DATABASE_URL")
    assert_equal "shortbread.example", inventory.fetch("SHORTBREAD_APEX_HOST")
    refute_includes stdout, VALID_ENVIRONMENT.fetch("SECRET_KEY_BASE")
  end

  test "every role exits with a configuration error before starting when configuration is missing" do
    Shortbread::ProductionRuntime::REQUIRED_KEYS.each do |missing_key|
      environment = VALID_ENVIRONMENT.merge(missing_key => nil)
      stdout, stderr, status = run_production("web", environment)

      assert_empty stdout, missing_key
      assert_equal 78, status.exitstatus, missing_key
      assert_equal "production configuration error: missing production configuration: #{missing_key}\n", stderr
    end
  end

  test "inventory rejects AnyCable endpoint components that could disclose secrets" do
    unsafe_endpoints = {
      "ANYCABLE_RPC_HOST" => "http://operator:synthetic-rpc-secret@shortbread.internal:3000/_anycable",
      "ANYCABLE_HTTP_BROADCAST_URL" => "http://cable:8090/_broadcast?token=synthetic-broadcast-secret",
      "ANYCABLE_WEBSOCKET_URL" => "wss://shortbread.example/cable#synthetic-websocket-secret"
    }

    unsafe_endpoints.each do |key, endpoint|
      stdout, stderr, status = run_production("config", VALID_ENVIRONMENT.merge(key => endpoint))

      assert_empty stdout, key
      assert_equal 78, status.exitstatus, key
      refute_includes stderr, endpoint, key
      refute_match(/(?:rpc|broadcast|websocket)-secret/, stderr, key)
    end
  end

  test "non-web process inventories neither require nor expose the Producer credential" do
    environment = VALID_ENVIRONMENT.except("SHORTBREAD_BOOTSTRAP_TOKEN")

    %w[migrate worker cable].each do |role|
      stdout, stderr, status = run_production("config", environment, role)

      assert status.success?, "#{role}: #{stderr}"
      refute_includes JSON.parse(stdout), "SHORTBREAD_BOOTSTRAP_TOKEN", role
    end

    _, stderr, status = run_production("config", environment, "web")
    assert_equal 78, status.exitstatus
    assert_equal "production configuration error: missing production configuration: SHORTBREAD_BOOTSTRAP_TOKEN\n", stderr
  end

  test "Compose injects the Producer credential into web only" do
    compose = YAML.safe_load(
      Rails.root.join("compose.production.yml").read,
      aliases: true
    )
    services = compose.fetch("services")

    assert services.fetch("web").fetch("environment").key?("SHORTBREAD_BOOTSTRAP_TOKEN")
    %w[migrate worker cable].each do |role|
      refute services.fetch(role).fetch("environment").key?("SHORTBREAD_BOOTSTRAP_TOKEN"), role
    end
  end

  private

  def run_production(role, environment, *arguments)
    Open3.capture3(environment, Rails.root.join("bin/production").to_s, role, *arguments, chdir: Rails.root.to_s)
  end
end
