# frozen_string_literal: true

class SiteSessionsController < ActionController::Base
  skip_forgery_protection

  def create
    host = Shortbread::Hosts.parse(host: request.host, scheme: request.scheme, port: request.port)
    return not_found unless host.kind == :site && valid_request_policy?(host)

    site = Site.find_by(slug: host.site_slug)
    return not_found unless site

    issued = SiteHandoff.transaction do
      grant = InvitationFlow.exchange!(token: params[:handoff], audience: host.site_origin, site:)
      SiteSession.issue(grant:, audience: host.site_origin, now: Time.current)
    end

    secure = request.ssl?
    cookies[SiteSession.cookie_name(secure:)] = {
      value: issued.token,
      **SiteSession.cookie_options(secure:, expires_at: issued.expires_at)
    }
    response.set_header("Location", "/")
    head :see_other
  rescue InvitationFlow::Rejected, SiteSession::Rejected, Shortbread::Hosts::InvalidHost
    not_found
  end

  private

  def valid_request_policy?(host)
    request.headers["Origin"] == host.apex_origin &&
      request.get_header("HTTP_SEC_FETCH_SITE") == "same-site" &&
      request.get_header("HTTP_SEC_FETCH_MODE") == "navigate" &&
      request.get_header("HTTP_SEC_FETCH_DEST") == "document"
  end

  def not_found
    head :not_found
  end
end
