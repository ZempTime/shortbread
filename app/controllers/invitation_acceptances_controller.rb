# frozen_string_literal: true

require "securerandom"

class InvitationAcceptancesController < ActionController::Base
  skip_forgery_protection

  def create
    apex = Shortbread::Hosts.parse(host: request.host, scheme: request.scheme, port: request.port)
    return not_found unless apex.kind == :apex && valid_request_policy?(apex)

    locator = params[:locator]
    return not_found unless locator.is_a?(String) && Invitation::LOCATOR_FORMAT.match?(locator)

    site = Invitation.includes(grant: :site).find_by(locator:)&.grant&.site
    return not_found unless site

    site_origin = apex.site_origin(site.slug)
    acceptance = InvitationFlow.accept!(
      locator:,
      secret: params[:invitation_secret],
      audience: site_origin
    )

    nonce = SecureRandom.base64(18)
    set_success_headers(nonce:, site_origin:)
    render :create, layout: false, locals: { handoff: acceptance.token, nonce:, site_origin: }
  rescue InvitationFlow::Rejected, Shortbread::Hosts::InvalidHost
    not_found
  end

  private

  def valid_request_policy?(apex)
    request.headers["Origin"] == apex.apex_origin &&
      request.get_header("HTTP_SEC_FETCH_SITE") == "same-origin" &&
      request.get_header("HTTP_SEC_FETCH_MODE") == "navigate" &&
      request.get_header("HTTP_SEC_FETCH_DEST") == "document"
  end

  def set_success_headers(nonce:, site_origin:)
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "origin"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Content-Security-Policy"] = [
      "default-src 'none'",
      "script-src 'nonce-#{nonce}'",
      "style-src 'none'",
      "base-uri 'none'",
      "form-action #{site_origin}",
      "frame-ancestors 'none'"
    ].join("; ")
  end

  def not_found
    head :not_found
  end
end
