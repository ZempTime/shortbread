# frozen_string_literal: true

require "test_helper"

class BlobStoresTest < ActiveSupport::TestCase
  test "an unselected Blob store builds the local implementation" do
    assert_instance_of LocalBlobStore, Shortbread::BlobStores.build({})
  end

  test "an explicit local selection builds the local implementation" do
    store = Shortbread::BlobStores.build({ "SHORTBREAD_BLOB_STORE" => "local" })

    assert_instance_of LocalBlobStore, store
  end

  test "selecting R2 builds the R2 implementation from its configured credentials" do
    store = Shortbread::BlobStores.build(r2_environment)

    assert_instance_of R2BlobStore, store
  end

  test "selecting R2 without credentials fails closed rather than silently using local storage" do
    R2_REQUIRED_KEYS.each do |key|
      error = assert_raises(Shortbread::BlobStores::UnconfiguredStore, key) do
        Shortbread::BlobStores.build(r2_environment.except(key))
      end

      refute_includes error.message, r2_environment.fetch("SHORTBREAD_R2_SECRET_ACCESS_KEY"), key
    end
  end

  test "an unrecognized selection fails closed and names the rejected value" do
    error = assert_raises(Shortbread::BlobStores::UnconfiguredStore) do
      Shortbread::BlobStores.build({ "SHORTBREAD_BLOB_STORE" => "s3" })
    end

    assert_equal "unknown Blob store: s3", error.message
  end

  private

  R2_REQUIRED_KEYS = %w[
    SHORTBREAD_R2_ACCESS_KEY_ID
    SHORTBREAD_R2_BUCKET
    SHORTBREAD_R2_ENDPOINT
    SHORTBREAD_R2_SECRET_ACCESS_KEY
  ].freeze

  def r2_environment
    {
      "SHORTBREAD_BLOB_STORE" => "r2",
      "SHORTBREAD_R2_ACCESS_KEY_ID" => "c" * 32,
      "SHORTBREAD_R2_SECRET_ACCESS_KEY" => "d" * 64,
      "SHORTBREAD_R2_BUCKET" => "shortbread-blobs",
      "SHORTBREAD_R2_ENDPOINT" => "https://abc123.r2.cloudflarestorage.com"
    }
  end
end
