# frozen_string_literal: true

module Shortbread
  class HostIdentityGuard
    NOT_FOUND_HEADERS = {
      "Content-Type" => "text/plain; charset=utf-8",
      "Content-Length" => "0"
    }.freeze

    def initialize(app)
      @app = app
    end

    def call(environment)
      HostIdentity.resolve(ActionDispatch::Request.new(environment))

      @app.call(environment)
    rescue Hosts::InvalidHost
      [ 404, NOT_FOUND_HEADERS, [] ]
    end
  end
end
