# frozen_string_literal: true

module Shortbread
  class HostIdentityGuard
    AUTHORITY_FORMAT = /\A(?<host>[a-z0-9.-]+)(?::(?<port>[0-9]+))?\z/
    NOT_FOUND_HEADERS = {
      "Content-Type" => "text/plain; charset=utf-8",
      "Content-Length" => "0"
    }.freeze

    def initialize(app)
      @app = app
    end

    def call(environment)
      request = ActionDispatch::Request.new(environment)
      raw_host = parse_authority(request.get_header("HTTP_HOST"), scheme: request.scheme)
      forwarded_host = parse_forwarded_host(request, scheme: request.scheme)
      raise Hosts::InvalidHost if forwarded_host && host_identity(forwarded_host) != host_identity(raw_host)

      @app.call(environment)
    rescue Hosts::InvalidHost
      [ 404, NOT_FOUND_HEADERS, [] ]
    end

    private

    def parse_forwarded_host(request, scheme:)
      authority = request.get_header("HTTP_X_FORWARDED_HOST")
      return unless authority

      effective_authority = authority.to_s.split(",", -1).last&.strip
      parse_authority(effective_authority, scheme:)
    end

    def parse_authority(authority, scheme:)
      match = AUTHORITY_FORMAT.match(authority.to_s)
      raise Hosts::InvalidHost unless match

      port = match[:port]&.to_i || (scheme == "https" ? 443 : 80)
      Hosts.parse(host: match[:host], scheme:, port:)
    end

    def host_identity(host)
      [ host.kind, host.apex, host.site_slug ]
    end
  end
end
