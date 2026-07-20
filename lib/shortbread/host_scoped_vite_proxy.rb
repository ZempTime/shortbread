# frozen_string_literal: true

module Shortbread
  class HostScopedViteProxy
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
      raw_host = HostIdentity.resolve(ActionDispatch::Request.new(environment))

      raw_host.kind == :apex ? @apex_proxy.call(environment) : @app.call(environment)
    rescue Hosts::InvalidHost
      [ 404, NOT_FOUND_HEADERS, [] ]
    end
  end
end
