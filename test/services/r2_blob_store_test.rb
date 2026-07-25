# frozen_string_literal: true

require "test_helper"

require "digest"
require "stringio"

class R2BlobStoreTest < ActiveSupport::TestCase
  BUCKET = "shortbread-test"

  test "round trip stores and reads back verified content" do
    content = "shared immutable bytes"
    store = store_with(content)

    assert_equal digest(content), store.put_verified(io: StringIO.new(content), **identity(content))

    io = store.open_verified(storage_key: digest(content), **identity(content))
    assert_equal content, io.read
  ensure
    io&.close
  end

  test "put_verified rejects content whose digest does not match the claimed sha256" do
    content = "shared immutable bytes"
    store = store_with(content)

    assert_raises(Shortbread::BlobStore::ContentMismatch) do
      store.put_verified(io: StringIO.new("different bytes entirely"), **identity(content))
    end
  end

  test "put_verified rejects content whose length does not match the claimed byte size" do
    content = "shared immutable bytes"
    store = store_with(content)

    assert_raises(Shortbread::BlobStore::ContentMismatch) do
      store.put_verified(io: StringIO.new(content), sha256: digest(content), byte_size: content.bytesize + 1)
    end
  end

  test "reading a key the bucket does not hold fails closed" do
    content = "shared immutable bytes"
    store = store_for { |client| client.stub_responses(:get_object, "NoSuchKey") }

    assert_raises(Shortbread::BlobStore::StorageFailure) do
      store.open_verified(storage_key: digest(content), **identity(content))
    end
  end

  test "a transport failure surfaces as StorageFailure rather than an S3 error" do
    content = "shared immutable bytes"
    store = store_for { |client| client.stub_responses(:put_object, "InternalError") }

    assert_raises(Shortbread::BlobStore::StorageFailure) do
      store.put_verified(io: StringIO.new(content), **identity(content))
    end
  end

  test "open_verified rejects stored bytes that no longer match their digest" do
    content = "shared immutable bytes"
    store = store_with("tampered bytes of the very same length")

    assert_raises(Shortbread::BlobStore::StorageFailure) do
      store.open_verified(storage_key: digest(content), **identity(content))
    end
  end

  test "each_chunk streams a blob larger than one chunk without buffering it whole" do
    content = "z" * (Shortbread::BlobStore::CHUNK_SIZE * 2 + 17)
    store = store_with(content)

    chunks = store.each_chunk(digest(content)).to_a

    assert_operator chunks.length, :>, 1
    assert_operator chunks.map(&:bytesize).max, :<=, Shortbread::BlobStore::CHUNK_SIZE
    assert_equal content, chunks.join
  end

  test "verified? reports presence without trusting the caller's storage key" do
    content = "shared immutable bytes"
    store = store_with(content)

    assert store.verified?(storage_key: digest(content), **identity(content))
    refute store.verified?(storage_key: "not-a-digest", **identity(content))
  end

  private

  def digest(content) = Digest::SHA256.hexdigest(content)

  def identity(content) = { sha256: digest(content), byte_size: content.bytesize }

  def store_with(stored_content)
    store_for do |client|
      client.stub_responses(:put_object, {})
      client.stub_responses(:get_object, { body: stored_content, content_length: stored_content.bytesize })
      client.stub_responses(:head_object, { content_length: stored_content.bytesize })
    end
  end

  def store_for
    client = Aws::S3::Client.new(stub_responses: true, region: "auto")
    yield client
    R2BlobStore.new(bucket: BUCKET, client:)
  end
end
