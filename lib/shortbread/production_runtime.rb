# frozen_string_literal: true

require "pathname"
require "uri"

module Shortbread
  class ProductionRuntime
    REQUIRED_KEYS = %w[
      ANYCABLE_HTTP_BROADCAST_URL
      ANYCABLE_RPC_HOST
      ANYCABLE_SECRET
      ANYCABLE_WEBSOCKET_URL
      DATABASE_URL
      QUEUE_DATABASE_URL
      RAILS_ENV
      SECRET_KEY_BASE
      SHORTBREAD_APEX_HOST
      SHORTBREAD_BLOB_ROOT
    ].freeze
    SECRET_KEYS = %w[ANYCABLE_SECRET DATABASE_URL QUEUE_DATABASE_URL SECRET_KEY_BASE].freeze
    DEVELOPMENT_SECRETS = %w[anycable-local-secret shortbread-development-only].freeze
    HOST_PATTERN = /\A(?=.{1,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

    class InvalidConfiguration < StandardError; end

    def initialize(environment = ENV)
      @environment = environment
    end

    def validate!
      missing = REQUIRED_KEYS.select { |key| @environment[key].to_s.empty? }
      raise InvalidConfiguration, "missing production configuration: #{missing.sort.join(', ')}" if missing.any?

      invalid = []
      invalid << "RAILS_ENV must equal production" unless @environment.fetch("RAILS_ENV") == "production"
      invalid << "SHORTBREAD_APEX_HOST must be a lowercase hostname without scheme or port" unless valid_host?
      invalid << "SHORTBREAD_BLOB_ROOT must be an absolute path" unless Pathname(@environment.fetch("SHORTBREAD_BLOB_ROOT")).absolute?
      invalid << "SECRET_KEY_BASE must contain at least 32 characters" unless valid_secret?("SECRET_KEY_BASE")
      invalid << "ANYCABLE_SECRET must contain at least 32 characters and must not use a development value" unless valid_anycable_secret?
      invalid << "DATABASE_URL must be a PostgreSQL URL selecting a database" unless valid_postgresql_url?("DATABASE_URL")
      invalid << "QUEUE_DATABASE_URL must be a PostgreSQL URL selecting a database" unless valid_postgresql_url?("QUEUE_DATABASE_URL")
      invalid << "DATABASE_URL and QUEUE_DATABASE_URL must select distinct databases" unless distinct_databases?
      invalid << "ANYCABLE_RPC_HOST must be an HTTP URL without userinfo, query, or fragment" unless valid_endpoint_url?("ANYCABLE_RPC_HOST", %w[http https])
      invalid << "ANYCABLE_HTTP_BROADCAST_URL must be an HTTP URL without userinfo, query, or fragment" unless valid_endpoint_url?("ANYCABLE_HTTP_BROADCAST_URL", %w[http https])
      invalid << "ANYCABLE_WEBSOCKET_URL must be a secure WebSocket URL without userinfo, query, or fragment" unless valid_endpoint_url?("ANYCABLE_WEBSOCKET_URL", %w[wss])

      raise InvalidConfiguration, "invalid production configuration: #{invalid.join('; ')}" if invalid.any?

      true
    rescue URI::InvalidURIError
      raise InvalidConfiguration, "invalid production configuration: one or more URLs are malformed"
    end

    def inventory
      REQUIRED_KEYS.to_h do |key|
        value = @environment[key].to_s
        rendered = if value.empty?
          "[missing]"
        elsif SECRET_KEYS.include?(key)
          "[configured secret]"
        else
          value
        end
        [ key, rendered ]
      end
    end

    private

    def valid_host?
      @environment.fetch("SHORTBREAD_APEX_HOST").match?(HOST_PATTERN)
    end

    def valid_secret?(key)
      @environment.fetch(key).bytesize >= 32
    end

    def valid_anycable_secret?
      secret = @environment.fetch("ANYCABLE_SECRET")
      secret.bytesize >= 32 && !DEVELOPMENT_SECRETS.include?(secret)
    end

    def valid_endpoint_url?(key, schemes)
      uri = URI.parse(@environment.fetch(key))
      schemes.include?(uri.scheme) && uri.host && !uri.host.empty? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
    end

    def valid_postgresql_url?(key)
      uri = URI.parse(@environment.fetch(key))
      %w[postgres postgresql].include?(uri.scheme) && uri.host && !uri.host.empty? && uri.path.to_s.match?(%r{\A/[^/]+\z})
    end

    def distinct_databases?
      database_identity("DATABASE_URL") != database_identity("QUEUE_DATABASE_URL")
    end

    def database_identity(key)
      uri = URI.parse(@environment.fetch(key))
      [ uri.host.to_s.downcase, uri.port || 5432, uri.path ]
    end
  end
end
