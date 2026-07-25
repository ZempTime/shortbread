# frozen_string_literal: true

module Shortbread
  module BlobStores
    class UnconfiguredStore < StandardError; end

    def self.selection(environment = ENV)
      value = environment["SHORTBREAD_BLOB_STORE"].to_s
      value.empty? ? ProductionRuntime::DEFAULT_BLOB_STORE : value
    end

    def self.local?(environment = ENV)
      selection(environment) == "local"
    end

    def self.build(environment = ENV)
      selected = selection(environment)

      case selected
      when "local" then LocalBlobStore.new
      when "r2" then build_r2(environment)
      else raise UnconfiguredStore, "unknown Blob store: #{selected}"
      end
    end

    def self.build_r2(environment)
      values = ProductionRuntime::R2_BLOB_STORE_KEYS.to_h do |key|
        value = environment[key].to_s
        raise UnconfiguredStore, "missing Blob store configuration: #{key}" if value.empty?

        [ key, value ]
      end

      R2BlobStore.new(
        bucket: values.fetch("SHORTBREAD_R2_BUCKET"),
        client: R2BlobStore.client_for(
          access_key_id: values.fetch("SHORTBREAD_R2_ACCESS_KEY_ID"),
          secret_access_key: values.fetch("SHORTBREAD_R2_SECRET_ACCESS_KEY"),
          endpoint: values.fetch("SHORTBREAD_R2_ENDPOINT")
        )
      )
    end
    private_class_method :build_r2
  end
end
