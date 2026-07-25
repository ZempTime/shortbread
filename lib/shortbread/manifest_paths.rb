# frozen_string_literal: true

module Shortbread
  # The single definition of what a Manifest path may be. Publishing validates against it so an
  # unsafe path never enters a Manifest; serving normalizes against it so a request can only ever
  # name a path publishing would have accepted.
  module ManifestPaths
    INDEX = "index.html"
    SEGMENT_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/
    RESERVED_PREFIX = "_shortbread"
    RESERVED_PATHS = [ "service-worker.js" ].freeze

    module_function

    def valid?(path)
      return false unless path.is_a?(String) && path.present? && path.valid_encoding? && path.ascii_only?
      return false if path.start_with?("/") || path.include?("\\") || path.include?("\0")

      segments = path.split("/", -1)
      return false if segments.any? { |segment| segment.empty? || segment == "." || segment == ".." }
      return false unless segments.all? { |segment| segment.match?(SEGMENT_FORMAT) }
      return false if segments.any? { |segment| segment == ".env" || segment.start_with?(".env.") }
      return false if segments.first == RESERVED_PREFIX
      return false if RESERVED_PATHS.include?(path)

      true
    end

    # A request path to the Manifest path it names, or nil when it names none. The site root is
    # the only rewrite; everything else must already be exactly what publishing stored, so a
    # traversal or encoded variant resolves to nothing rather than to a neighbouring document.
    def normalize(requested)
      return INDEX if requested.nil? || requested == "" || requested == "/"

      candidate = requested.to_s.delete_prefix("/")
      return INDEX if candidate.empty?
      return nil unless valid?(candidate)

      candidate
    end
  end
end
