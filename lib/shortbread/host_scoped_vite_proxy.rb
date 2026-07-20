# frozen_string_literal: true

module Shortbread
  class HostScopedViteProxy
    def initialize(app, options = {})
      @app = app
      options = options.dup
      @apex_proxy = options.delete(:proxy) || ViteRuby::DevServerProxy.new(app, options)
    end

    def call(environment)
      raw_host = HostIdentity.resolve(ActionDispatch::Request.new(environment))

      raw_host.kind == :apex ? @apex_proxy.call(environment) : @app.call(environment)
    rescue Hosts::InvalidHost
      RackResponses.not_found
    end
  end
end
