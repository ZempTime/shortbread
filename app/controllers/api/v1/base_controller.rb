# frozen_string_literal: true

require "digest"

module Api
  module V1
    class BaseController < ActionController::API
      before_action :require_apex_host
      before_action :authenticate_producer

      private

      def require_apex_host
        host = Shortbread::Hosts.parse(host: request.host, scheme: request.scheme, port: request.port)
        head :not_found unless host.kind == :apex
      rescue Shortbread::Hosts::InvalidHost
        head :not_found
      end

      def authenticate_producer
        expected = ENV["SHORTBREAD_BOOTSTRAP_TOKEN"]
        match = request.authorization.to_s.match(/\ABearer ([^\s]+)\z/)
        supplied = match&.captures&.first

        return if expected.present? && supplied.present? && secure_token?(expected, supplied)

        render json: { error: { code: "authentication_required" } }, status: :unauthorized
      end

      def secure_token?(expected, supplied)
        expected_digest = Digest::SHA256.hexdigest(expected)
        supplied_digest = Digest::SHA256.hexdigest(supplied)
        ActiveSupport::SecurityUtils.secure_compare(expected_digest, supplied_digest)
      end
    end
  end
end
