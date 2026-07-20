# frozen_string_literal: true

module Shortbread
  class HostIdentity
    AUTHORITY_FORMAT = /\A(?<host>[a-z0-9.-]+)(?::(?<port>[0-9]+))?\z/

    def self.resolve(request)
      raw_host = parse_authority(request.get_header("HTTP_HOST"), scheme: request.scheme)
      forwarded_host = parse_forwarded_host(request, scheme: request.scheme)
      raise Hosts::InvalidHost if forwarded_host && identity(forwarded_host) != identity(raw_host)

      raw_host
    end

    class << self
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

      def identity(host)
        [ host.kind, host.apex, host.site_slug ]
      end
    end
  end
end
