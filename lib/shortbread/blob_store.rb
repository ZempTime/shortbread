# frozen_string_literal: true

module Shortbread
  module BlobStore
    CHUNK_SIZE = 64 * 1024

    class ContentMismatch < StandardError; end
    class StorageFailure < StandardError; end
  end
end
