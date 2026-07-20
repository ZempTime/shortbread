# frozen_string_literal: true

require "securerandom"

class InvitationPreviewsController < ActionController::Base
  def show
    host = Shortbread::Hosts.parse(host: request.host, scheme: request.scheme, port: request.port)
    return head :not_found unless host.kind == :apex

    nonce = SecureRandom.base64(18)
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "origin"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Content-Security-Policy"] = [
      "default-src 'none'",
      "script-src 'nonce-#{nonce}'",
      "style-src 'none'",
      "base-uri 'none'",
      "form-action 'self'",
      "frame-ancestors 'none'"
    ].join("; ")
    render :show, layout: false, locals: { nonce: }
  rescue Shortbread::Hosts::InvalidHost
    head :not_found
  end
end
