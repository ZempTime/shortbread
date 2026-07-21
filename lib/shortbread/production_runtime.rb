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
    POSTGRESQL_EXTERNAL_IDENTITY_QUERY_KEYS = %w[dbname service].freeze
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
      database_path = decoded_database_path(uri)
      options = postgresql_query_options(uri)
      identity = database_identity_from(uri, options)
      %w[postgres postgresql].include?(uri.scheme) &&
        uri.host && !uri.host.empty? &&
        database_path.match?(%r{\A/[^/]+\z}) &&
        identity[0] && !identity[0].empty? &&
        identity[1].between?(1, 65_535) &&
        identity[2] && !identity[2].empty? &&
        (POSTGRESQL_EXTERNAL_IDENTITY_QUERY_KEYS & options.keys).empty?
    rescue ArgumentError
      false
    end

    def distinct_databases?
      database_identity("DATABASE_URL") != database_identity("QUEUE_DATABASE_URL")
    end

    def database_identity(key)
      uri = URI.parse(@environment.fetch(key))
      database_identity_from(uri, postgresql_query_options(uri))
    rescue ArgumentError
      [ nil, nil, nil ]
    end

    def database_identity_from(uri, options)
      host = options["hostaddr"]
      host = options.fetch("host", uri.host.to_s) if host.to_s.empty?
      port = options.fetch("port", uri.port || 5432)
      database = options.fetch("database", decoded_database_path(uri).delete_prefix("/"))

      [ host.to_s.downcase, Integer(port.to_s, 10), database ]
    end

    def decoded_database_path(uri)
      URI::DEFAULT_PARSER.unescape(uri.path.to_s)
    end

    def postgresql_query_options(uri)
      uri.query.to_s.split("&").filter_map do |pair|
        name, value = pair.split("=", 2)
        [ name, URI::DEFAULT_PARSER.unescape(value.to_s) ] unless name.to_s.empty?
      end.to_h
    end
  end
end
