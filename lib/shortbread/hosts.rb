# frozen_string_literal: true

module Shortbread
  class Hosts
    MAX_HOST_BYTES = 253
    MAX_ORIGIN_BYTES = "https://".bytesize + MAX_HOST_BYTES + ":65535".bytesize
    SITE_HOST_INFIX = ".sites."
    MAX_APEX_BYTES = MAX_HOST_BYTES - SITE_HOST_INFIX.bytesize - 1
    HOST_LABEL = "[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"
    HOST_FORMAT = /\A(?=.{1,#{MAX_HOST_BYTES}}\z)#{HOST_LABEL}(?:\.#{HOST_LABEL})*\z/

    class InvalidHost < StandardError
      def initialize
        super("invalid Shortbread host")
      end
    end

    class Result
      attr_reader :kind, :apex, :site_slug

      def initialize(kind:, apex:, site_slug:, scheme:, port:)
        @kind = kind
        @apex = apex.freeze
        @site_slug = site_slug&.freeze
        @scheme = scheme.freeze
        @port = port
        freeze
      end

      def apex_origin
        "#{@scheme}://#{apex}#{port_suffix}"
      end

      def site_origin(slug = site_slug)
        raise InvalidHost unless Hosts.valid_site_hostname?(slug:, apex_host: apex)

        "#{@scheme}://#{slug}.sites.#{apex}#{port_suffix}"
      end

      private

      def port_suffix
        return "" if (@scheme == "http" && @port == 80) || (@scheme == "https" && @port == 443)

        ":#{@port}"
      end
    end

    def self.parse(host:, scheme:, port:, apex_host: ENV.fetch("SHORTBREAD_APEX_HOST", "localhost"))
      raise InvalidHost unless valid_apex_hostname?(apex_host) && valid_hostname?(host) && valid_origin?(scheme, port)

      return Result.new(kind: :apex, apex: apex_host, site_slug: nil, scheme: scheme, port: port) if host == apex_host

      site_suffix = "#{SITE_HOST_INFIX}#{apex_host}"
      site_slug = host.delete_suffix(site_suffix) if host.end_with?(site_suffix)
      raise InvalidHost unless valid_site_hostname?(slug: site_slug, apex_host:)

      Result.new(kind: :site, apex: apex_host, site_slug: site_slug, scheme: scheme, port: port)
    end

    def self.valid_site_hostname?(slug:, apex_host: ENV.fetch("SHORTBREAD_APEX_HOST", "localhost"))
      return false unless slug.is_a?(String) && Site::SLUG_FORMAT.match?(slug)
      return false unless valid_apex_hostname?(apex_host)

      valid_hostname?("#{slug}#{SITE_HOST_INFIX}#{apex_host}")
    end

    def self.authorization_pattern(apex_host: ENV.fetch("SHORTBREAD_APEX_HOST", "localhost"))
      raise InvalidHost unless valid_apex_hostname?(apex_host)

      escaped_apex = Regexp.escape(apex_host)
      max_site_label_bytes = [ 63, MAX_HOST_BYTES - SITE_HOST_INFIX.bytesize - apex_host.bytesize ].min
      site_label = bounded_host_label(max_site_label_bytes)
      /(?:#{escaped_apex}|#{site_label}\.sites\.#{escaped_apex})/
    end

    def self.valid_hostname?(value)
      value.is_a?(String) && HOST_FORMAT.match?(value)
    end
    private_class_method :valid_hostname?

    def self.valid_apex_hostname?(value)
      valid_hostname?(value) && value.bytesize <= MAX_APEX_BYTES
    end
    private_class_method :valid_apex_hostname?

    def self.bounded_host_label(max_bytes)
      return "[a-z0-9]" if max_bytes == 1

      "[a-z0-9](?:[a-z0-9-]{0,#{max_bytes - 2}}[a-z0-9])?"
    end
    private_class_method :bounded_host_label

    def self.valid_origin?(scheme, port)
      %w[http https].include?(scheme) && port.is_a?(Integer) && (1..65_535).cover?(port)
    end
    private_class_method :valid_origin?
  end
end
