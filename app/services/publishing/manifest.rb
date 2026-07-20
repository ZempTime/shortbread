# frozen_string_literal: true

require "digest"
require "json"

module Publishing
  class Manifest
    CANONICAL_VERSION = 1

    Delta = Data.define(:added, :changed, :reused, :removed) do
      def counts
        {
          added: added.length,
          changed: changed.length,
          reused: reused.length,
          removed: removed.length
        }
      end
    end

    attr_reader :entries, :canonical_json, :sha256

    def self.build(entries:)
      normalized = Publishing.normalize_manifest("entries" => entries)
      new(normalized.fetch("entries"))
    end

    def self.from_release(release)
      return unless release

      build(entries: release.manifest_entries.includes(:blob).map do |entry|
        {
          path: entry.path,
          sha256: entry.blob.sha256,
          size: entry.byte_size,
          content_type: entry.content_type,
          offline_policy: entry.offline_policy
        }
      end)
    end

    def initialize(entries)
      @entries = entries.map(&:freeze).freeze
      @canonical_json = JSON.generate("entries" => @entries).freeze
      @sha256 = Digest::SHA256.hexdigest(@canonical_json).freeze
      freeze
    end

    def delta_from(base)
      base_by_path = base&.entries&.index_by { |entry| entry.fetch("path") } || {}
      candidate_by_path = entries.index_by { |entry| entry.fetch("path") }
      candidate_paths = candidate_by_path.keys.sort
      base_paths = base_by_path.keys.sort

      added = candidate_paths - base_paths
      removed = base_paths - candidate_paths
      common = candidate_paths & base_paths
      changed, reused = common.partition do |path|
        candidate_by_path.fetch(path) != base_by_path.fetch(path)
      end

      Delta.new(added:, changed:, reused:, removed:)
    end
  end
end
