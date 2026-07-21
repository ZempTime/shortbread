# frozen_string_literal: true

require "securerandom"

module Shortbread
  class PrivateBlobReadiness
    PROBE_CONTENT = "shortbread-private-blob-readiness\n".b.freeze

    def self.ready?(root)
      new(root).ready?
    end

    def initialize(root)
      @root = root
    end

    def ready?
      return false unless File.directory?(@root)

      token = SecureRandom.hex(12)
      source = File.join(@root, ".shortbread-readiness-#{token}")
      hard_link = "#{source}.link"
      operation_succeeded = false

      begin
        File.open(source, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.write(PROBE_CONTENT)
          file.flush
          file.fsync
        end
        File.link(source, hard_link)
        operation_succeeded = true
      rescue SystemCallError, IOError
        operation_succeeded = false
      ensure
        cleanup_succeeded = [ hard_link, source ].map { |path| remove_probe(path) }.all?
      end

      operation_succeeded && cleanup_succeeded
    end

    private

    def remove_probe(path)
      File.unlink(path)
      true
    rescue Errno::ENOENT
      true
    rescue SystemCallError
      false
    end
  end
end
