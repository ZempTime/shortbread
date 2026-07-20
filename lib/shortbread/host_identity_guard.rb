# frozen_string_literal: true

module Shortbread
  class HostIdentityGuard
    def initialize(app)
      @app = app
    end

    def call(environment)
      HostIdentity.resolve(ActionDispatch::Request.new(environment))

      @app.call(environment)
    rescue Hosts::InvalidHost
      RackResponses.not_found
    end
  end
end
