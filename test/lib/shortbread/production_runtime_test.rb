# frozen_string_literal: true

require "test_helper"

require "shortbread/production_runtime"

class ProductionRuntimeTest < ActiveSupport::TestCase
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
    "SHORTBREAD_BLOB_ROOT" => "/var/lib/shortbread/blobs"
  }.freeze

  test "valid production configuration has one redacted exact inventory" do
    runtime = Shortbread::ProductionRuntime.new(VALID_ENVIRONMENT)

    assert runtime.validate!
    assert_equal Shortbread::ProductionRuntime::REQUIRED_KEYS.sort, runtime.inventory.keys.sort
    assert_equal "[configured secret]", runtime.inventory.fetch("SECRET_KEY_BASE")
    assert_equal "shortbread.example", runtime.inventory.fetch("SHORTBREAD_APEX_HOST")
  end

  test "missing configuration fails without printing configured values" do
    environment = VALID_ENVIRONMENT.except("DATABASE_URL", "ANYCABLE_SECRET")

    error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration) do
      Shortbread::ProductionRuntime.new(environment).validate!
    end

    assert_equal "missing production configuration: ANYCABLE_SECRET, DATABASE_URL", error.message
    Shortbread::ProductionRuntime::SECRET_KEYS.filter_map { |key| environment[key] }.each do |value|
      refute_includes error.message, value
    end
  end

  test "contradictory configuration fails before a process can start" do
    contradictions = {
      "same primary and queue database" => { "QUEUE_DATABASE_URL" => VALID_ENVIRONMENT.fetch("DATABASE_URL") },
      "development AnyCable secret" => { "ANYCABLE_SECRET" => "shortbread-development-only" },
      "relative Blob root" => { "SHORTBREAD_BLOB_ROOT" => "tmp/blobs" },
      "apex URL instead of host" => { "SHORTBREAD_APEX_HOST" => "https://shortbread.example" },
      "plain production WebSocket" => { "ANYCABLE_WEBSOCKET_URL" => "ws://shortbread.example/cable" }
    }

    contradictions.each do |name, override|
      error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration, name) do
        Shortbread::ProductionRuntime.new(VALID_ENVIRONMENT.merge(override)).validate!
      end

      assert_match(/^invalid production configuration:/, error.message, name)
      override.each_value { |value| refute_includes error.message, value, name }
    end
  end

  test "PostgreSQL URLs must select a database" do
    [
      "postgresql://shortbread:example@postgres",
      "postgresql://shortbread:example@postgres/"
    ].each do |database_url|
      error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration) do
        Shortbread::ProductionRuntime.new(VALID_ENVIRONMENT.merge("DATABASE_URL" => database_url)).validate!
      end

      assert_includes error.message, "DATABASE_URL must be a PostgreSQL URL selecting a database"
      refute_includes error.message, database_url
    end
  end

  test "database separation canonicalizes PostgreSQL host and default port aliases" do
    environment = VALID_ENVIRONMENT.merge(
      "DATABASE_URL" => "postgresql://primary:secret@postgres/shortbread",
      "QUEUE_DATABASE_URL" => "postgres://queue:other@POSTGRES:5432/shortbread"
    )

    error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration) do
      Shortbread::ProductionRuntime.new(environment).validate!
    end

    assert_includes error.message, "DATABASE_URL and QUEUE_DATABASE_URL must select distinct databases"
    environment.values_at("DATABASE_URL", "QUEUE_DATABASE_URL").each do |database_url|
      refute_includes error.message, database_url
    end
  end

  test "database separation canonicalizes percent-encoded PostgreSQL database names" do
    environment = VALID_ENVIRONMENT.merge(
      "DATABASE_URL" => "postgresql://primary:secret@postgres/shortbread",
      "QUEUE_DATABASE_URL" => "postgresql://queue:other@postgres/%73hortbread"
    )

    error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration) do
      Shortbread::ProductionRuntime.new(environment).validate!
    end

    assert_includes error.message, "DATABASE_URL and QUEUE_DATABASE_URL must select distinct databases"
    environment.values_at("DATABASE_URL", "QUEUE_DATABASE_URL").each do |database_url|
      refute_includes error.message, database_url
    end
  end

  test "database separation uses effective PostgreSQL query connection identity" do
    aliases = [
      [ "postgresql://primary:secret@postgres/shortbread", "postgresql://queue:other@elsewhere/shortbread?host=postgres" ],
      [ "postgresql://primary:secret@postgres:5432/shortbread", "postgresql://queue:other@postgres:15432/shortbread?port=5432" ],
      [ "postgresql://primary:secret@postgres/shortbread", "postgresql://queue:other@postgres/elsewhere?database=shortbread" ],
      [ "postgresql://primary:secret@postgres/shortbread?hostaddr=192.0.2.1", "postgresql://queue:other@elsewhere/shortbread?hostaddr=192.0.2.1" ]
    ]

    aliases.each do |primary_url, queue_url|
      environment = VALID_ENVIRONMENT.merge("DATABASE_URL" => primary_url, "QUEUE_DATABASE_URL" => queue_url)

      error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration) do
        Shortbread::ProductionRuntime.new(environment).validate!
      end

      assert_includes error.message, "DATABASE_URL and QUEUE_DATABASE_URL must select distinct databases"
      environment.values_at("DATABASE_URL", "QUEUE_DATABASE_URL").each do |database_url|
        refute_includes error.message, database_url
      end
    end
  end

  test "PostgreSQL URLs reject external identity sources" do
    %w[dbname service].each do |parameter|
      database_url = "postgresql://primary:secret@postgres/shortbread?#{parameter}=synthetic-override"

      error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration, parameter) do
        Shortbread::ProductionRuntime.new(VALID_ENVIRONMENT.merge("DATABASE_URL" => database_url)).validate!
      end

      assert_includes error.message, "DATABASE_URL must be a PostgreSQL URL selecting a database", parameter
      refute_includes error.message, database_url, parameter
    end
  end

  test "PostgreSQL URLs accept a host supplied only by an encoded Unix socket query" do
    environment = VALID_ENVIRONMENT.merge(
      "DATABASE_URL" => "postgresql:///shortbread?host=%2Ftmp%2FPGSock",
      "QUEUE_DATABASE_URL" => "postgresql:///shortbread_queue?host=%2Ftmp%2FPGSock"
    )

    assert Shortbread::ProductionRuntime.new(environment).validate!
  end

  test "database separation preserves case-sensitive Unix socket paths" do
    environment = VALID_ENVIRONMENT.merge(
      "DATABASE_URL" => "postgresql:///shortbread?host=%2Ftmp%2FPGSock",
      "QUEUE_DATABASE_URL" => "postgresql:///shortbread?host=%2Ftmp%2Fpgsock"
    )

    assert Shortbread::ProductionRuntime.new(environment).validate!
  end

  VALID_R2_ENVIRONMENT = VALID_ENVIRONMENT.merge(
    "SHORTBREAD_BLOB_STORE" => "r2",
    "SHORTBREAD_R2_ACCESS_KEY_ID" => "c" * 32,
    "SHORTBREAD_R2_SECRET_ACCESS_KEY" => "d" * 64,
    "SHORTBREAD_R2_BUCKET" => "shortbread-blobs",
    "SHORTBREAD_R2_ENDPOINT" => "https://abc123.r2.cloudflarestorage.com"
  ).freeze

  test "the Blob store defaults to local when unselected" do
    runtime = Shortbread::ProductionRuntime.new(VALID_ENVIRONMENT)

    assert runtime.validate!
    assert_equal "local", runtime.blob_store
  end

  test "selecting R2 without credentials fails closed before serving" do
    error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration) do
      Shortbread::ProductionRuntime.new(VALID_ENVIRONMENT.merge("SHORTBREAD_BLOB_STORE" => "r2")).validate!
    end

    assert_equal(
      "missing production configuration: SHORTBREAD_R2_ACCESS_KEY_ID, SHORTBREAD_R2_BUCKET, " \
        "SHORTBREAD_R2_ENDPOINT, SHORTBREAD_R2_SECRET_ACCESS_KEY",
      error.message
    )
  end

  test "a complete R2 configuration validates and redacts its credentials" do
    runtime = Shortbread::ProductionRuntime.new(VALID_R2_ENVIRONMENT)

    assert runtime.validate!
    assert_equal "r2", runtime.blob_store
    assert_equal "[configured secret]", runtime.inventory.fetch("SHORTBREAD_R2_ACCESS_KEY_ID")
    assert_equal "[configured secret]", runtime.inventory.fetch("SHORTBREAD_R2_SECRET_ACCESS_KEY")
    assert_equal "shortbread-blobs", runtime.inventory.fetch("SHORTBREAD_R2_BUCKET")
  end

  test "R2 credentials never appear in inventory or failure messages" do
    secrets = VALID_R2_ENVIRONMENT.values_at("SHORTBREAD_R2_ACCESS_KEY_ID", "SHORTBREAD_R2_SECRET_ACCESS_KEY")
    environment = VALID_R2_ENVIRONMENT.merge("SHORTBREAD_R2_ENDPOINT" => "http://abc123.r2.cloudflarestorage.com")

    error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration) do
      Shortbread::ProductionRuntime.new(environment).validate!
    end

    rendered = Shortbread::ProductionRuntime.new(VALID_R2_ENVIRONMENT).inventory.values.join(" ")
    secrets.each do |secret|
      refute_includes error.message, secret
      refute_includes rendered, secret
    end
  end

  test "an unrecognized Blob store selection fails rather than falling back" do
    error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration) do
      Shortbread::ProductionRuntime.new(VALID_ENVIRONMENT.merge("SHORTBREAD_BLOB_STORE" => "s3")).validate!
    end

    assert_includes error.message, "SHORTBREAD_BLOB_STORE must be one of local, r2"
  end

  test "the R2 endpoint must be an HTTPS URL without credentials embedded" do
    [
      "http://abc123.r2.cloudflarestorage.com",
      "https://key:secret@abc123.r2.cloudflarestorage.com",
      "abc123.r2.cloudflarestorage.com"
    ].each do |endpoint|
      error = assert_raises(Shortbread::ProductionRuntime::InvalidConfiguration, endpoint) do
        Shortbread::ProductionRuntime.new(VALID_R2_ENVIRONMENT.merge("SHORTBREAD_R2_ENDPOINT" => endpoint)).validate!
      end

      assert_includes error.message, "SHORTBREAD_R2_ENDPOINT must be an HTTPS URL", endpoint
      refute_includes error.message, endpoint, endpoint
    end
  end

  test "selecting R2 does not require a local Blob root" do
    runtime = Shortbread::ProductionRuntime.new(VALID_R2_ENVIRONMENT.except("SHORTBREAD_BLOB_ROOT"))

    assert runtime.validate!
  end
end
