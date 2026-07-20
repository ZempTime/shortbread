# frozen_string_literal: true

require "action_dispatch/middleware/static"

module Shortbread
  class HostScopedStatic
    NOT_FOUND_HEADERS = {
      "Content-Type" => "text/plain; charset=utf-8",
      "Content-Length" => "0"
    }.freeze

    def initialize(app)
      @app = app
      settings = Rails.application.config.public_file_server
      @apex_static = ActionDispatch::Static.new(
        app,
        Rails.public_path.to_s,
        index: settings.index_name,
        headers: settings.headers || {}
      )
    end

    def call(environment)
      request = ActionDispatch::Request.new(environment)
      host = Hosts.parse(host: request.host, scheme: request.scheme, port: request.port)

      return @apex_static.call(environment) if host.kind == :apex

      blank_not_found(@app.call(environment))
    rescue Hosts::InvalidHost
      not_found
    end

    private

    def blank_not_found(response)
      return response unless response.first == 404

      response.last.close if response.last.respond_to?(:close)
      not_found
    end

    def not_found
      [ 404, NOT_FOUND_HEADERS.dup, [] ]
    end
  end
end
