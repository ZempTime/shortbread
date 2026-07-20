# frozen_string_literal: true

module Shortbread
  class HostScopedViteProxy
    AUTHORITY_FORMAT = /\A(?<host>[a-z0-9.-]+)(?::(?<port>[0-9]+))?\z/
    NOT_FOUND_HEADERS = {
      "Content-Type" => "text/plain; charset=utf-8",
      "Content-Length" => "0"
    }.freeze

    def initialize(app, options = {})
      @app = app
      options = options.dup
      @apex_proxy = options.delete(:proxy) || ViteRuby::DevServerProxy.new(app, options)
    end

    def call(environment)
      request = ActionDispatch::Request.new(environment)
      raw_host = parse_authority(request.get_header("HTTP_HOST"), scheme: request.scheme)
      forwarded_host = parse_forwarded_host(request, scheme: request.scheme)
      raise Hosts::InvalidHost if forwarded_host && host_identity(forwarded_host) != host_identity(raw_host)

      raw_host.kind == :apex ? @apex_proxy.call(environment) : @app.call(environment)
    rescue Hosts::InvalidHost
      [ 404, NOT_FOUND_HEADERS, [] ]
    end

    private

    def parse_forwarded_host(request, scheme:)
      authority = request.x_forwarded_host.to_s.split(",").last&.strip
      parse_authority(authority, scheme:) if authority.present?
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
