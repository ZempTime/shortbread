# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"
require "tempfile"

class LocalBlobStore
  CHUNK_SIZE = 64 * 1024

  class ContentMismatch < StandardError; end
  class StorageFailure < StandardError; end

  def initialize(root: ENV.fetch("SHORTBREAD_BLOB_ROOT", Rails.root.join("tmp", "blob-store")))
    @root = Pathname(root)
  end

  def put_verified(io:, sha256:, byte_size:)
    validate_identity!(sha256, byte_size)
    directory = prepare_directory(@root.join(sha256.first(2)))
    final_path = directory.join(sha256)
    return sha256 if file_verified?(final_path, sha256:, byte_size:)

    Tempfile.create([ "upload-", ".tmp" ], directory.to_s) do |temporary|
      temporary.binmode
      temporary.chmod(0o600)
      digest = Digest::SHA256.new
      actual_size = 0

      while (chunk = io.read(CHUNK_SIZE))
        next if chunk.empty?

        actual_size += chunk.bytesize
        raise ContentMismatch if actual_size > byte_size

        digest.update(chunk)
        temporary.write(chunk)
      end

      temporary.flush
      temporary.fsync
      raise ContentMismatch unless actual_size == byte_size && digest.hexdigest == sha256

      begin
        File.link(temporary.path, final_path.to_s)
      rescue Errno::EEXIST
        raise StorageFailure unless file_verified?(final_path, sha256:, byte_size:)
      end
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

    file_verified?(storage_path(storage_key), sha256:, byte_size:)
  rescue ContentMismatch, StorageFailure, StandardError
    false
  end

  def open(storage_key)
    io = open_secure(storage_key)
    yield io
  rescue StorageFailure
    raise
  rescue StandardError
    raise StorageFailure
  ensure
    io&.close
  end

  def open_verified(storage_key:, sha256:, byte_size:)
    validate_identity!(sha256, byte_size)
    raise StorageFailure unless storage_key == sha256

    io = open_secure(storage_key)
    raise StorageFailure unless io_verified?(io, sha256:, byte_size:)

    io.rewind
    io
  rescue ContentMismatch, StorageFailure
    io&.close
    raise
  rescue StandardError
    io&.close
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

  def validate_identity!(sha256, byte_size)
    valid_digest = sha256.is_a?(String) && sha256.match?(Blob::SHA256_FORMAT)
    valid_size = byte_size.is_a?(Integer) && byte_size >= 0
    raise ContentMismatch unless valid_digest && valid_size
  end

  def prepare_directory(path)
    prepare_one_directory(@root)
    prepare_one_directory(path)
  end

  def prepare_one_directory(path)
    FileUtils.mkdir_p(path, mode: 0o700)
    stat = File.lstat(path)
    raise StorageFailure unless stat.directory? && !stat.symlink?

    File.chmod(0o700, path)
    path
  end

  def storage_path(storage_key)
    @root.join(storage_key.first(2), storage_key)
  end

  def open_secure(storage_key)
    raise StorageFailure unless storage_key.to_s.match?(Blob::SHA256_FORMAT)

    path = storage_path(storage_key)
    path_stat = File.lstat(path)
    raise StorageFailure unless secure_file?(path_stat)

    io = File.open(path, "rb")
    opened_stat = io.stat
    same_file = path_stat.dev == opened_stat.dev && path_stat.ino == opened_stat.ino
    raise StorageFailure unless same_file && secure_file?(opened_stat)

    io
  rescue StorageFailure
    io&.close
    raise
  rescue StandardError
    io&.close
    raise StorageFailure
  end

  def secure_file?(stat)
    stat.file? && !stat.symlink? && stat.mode & 0o777 == 0o600
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

  def file_verified?(path, sha256:, byte_size:)
    stat = File.lstat(path)
    return false unless stat.file? && !stat.symlink? && stat.mode & 0o777 == 0o600
    return false unless stat.size == byte_size

    digest = Digest::SHA256.new
    File.open(path, "rb") do |io|
      while (chunk = io.read(CHUNK_SIZE))
        digest.update(chunk)
      end
    end
    digest.hexdigest == sha256
  rescue Errno::ENOENT
    false
  end
end
