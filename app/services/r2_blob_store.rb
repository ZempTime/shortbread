# frozen_string_literal: true

require "aws-sdk-s3"
require "digest"
require "tempfile"

class R2BlobStore
  include Shortbread::BlobStore

  def self.client_for(access_key_id:, secret_access_key:, endpoint:)
    Aws::S3::Client.new(
      access_key_id:,
      secret_access_key:,
      endpoint:,
      region: "auto",
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required"
    )
  end

  def initialize(bucket:, client:)
    @bucket = bucket
    @client = client
  end

  def put_verified(io:, sha256:, byte_size:)
    validate_identity!(sha256, byte_size)
    staged = stage_verified(io, sha256:, byte_size:)

    begin
      @client.put_object(bucket: @bucket, key: sha256, body: staged)
    ensure
      staged.close!
    end

    sha256
  rescue ContentMismatch, StorageFailure
    raise
  rescue StandardError
    raise StorageFailure
  end

  def verified?(storage_key:, sha256:, byte_size:)
    validate_identity!(sha256, byte_size)
    return false unless storage_key == sha256

    @client.head_object(bucket: @bucket, key: storage_key).content_length == byte_size
  rescue ContentMismatch, StorageFailure, StandardError
    false
  end

  def open(storage_key)
    io = download(storage_key)
    yield io
  rescue StorageFailure
    raise
  rescue StandardError
    raise StorageFailure
  ensure
    io&.close!
  end

  def open_verified(storage_key:, sha256:, byte_size:)
    validate_identity!(sha256, byte_size)
    raise StorageFailure unless storage_key == sha256

    io = download(storage_key)
    raise StorageFailure unless io_verified?(io, sha256:, byte_size:)

    io.rewind
    io
  rescue ContentMismatch, StorageFailure
    io&.close!
    raise
  rescue StandardError
    io&.close!
    raise StorageFailure
  end

  def each_chunk(storage_key)
    return enum_for(__method__, storage_key) unless block_given?

    open(storage_key) do |io|
      while (chunk = io.read(CHUNK_SIZE))
        yield chunk unless chunk.empty?
      end
    end
  end

  private

  def spool
    file = Tempfile.new([ "r2-blob-", ".tmp" ])
    file.binmode
    file.chmod(0o600)
    file.unlink
    file
  end

  def validate_identity!(sha256, byte_size)
    valid_digest = sha256.is_a?(String) && sha256.match?(Blob::SHA256_FORMAT)
    valid_size = byte_size.is_a?(Integer) && byte_size >= 0
    raise ContentMismatch unless valid_digest && valid_size
  end

  def stage_verified(io, sha256:, byte_size:)
    staged = spool
    digest = Digest::SHA256.new
    actual_size = 0

    while (chunk = io.read(CHUNK_SIZE))
      next if chunk.empty?

      actual_size += chunk.bytesize
      raise ContentMismatch if actual_size > byte_size

      digest.update(chunk)
      staged.write(chunk)
    end

    raise ContentMismatch unless actual_size == byte_size && digest.hexdigest == sha256

    staged.rewind
    staged
  rescue StandardError
    staged&.close!
    raise
  end

  def download(storage_key)
    raise StorageFailure unless storage_key.to_s.match?(Blob::SHA256_FORMAT)

    staged = spool
    @client.get_object(bucket: @bucket, key: storage_key) do |chunk|
      staged.write(chunk)
    end
    staged.rewind
    staged
  rescue StorageFailure
    staged&.close!
    raise
  rescue StandardError
    staged&.close!
    raise StorageFailure
  end

  def io_verified?(io, sha256:, byte_size:)
    digest = Digest::SHA256.new
    actual_size = 0

    while (chunk = io.read(CHUNK_SIZE))
      actual_size += chunk.bytesize
      return false if actual_size > byte_size

      digest.update(chunk)
    end

    actual_size == byte_size && digest.hexdigest == sha256
  end
end
