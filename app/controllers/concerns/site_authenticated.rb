# frozen_string_literal: true

# Resolves a request on a Site host to the active Grant behind its Site session, or fails closed.
# Shared by every surface a Viewer reaches: serving a document and leaving a Comment authenticate
# identically, so neither can drift into being the more permissive one.
module SiteAuthenticated
  extend ActiveSupport::Concern

  private

  attr_reader :current_site, :current_grant, :current_host

  def authenticate_site!
    @current_host = Shortbread::Hosts.parse(
      host: request.host, scheme: request.scheme, port: request.port
    )
    return false unless current_host.kind == :site

    @current_site = Site.find_by(slug: current_host.site_slug)
    return false unless current_site

    @current_grant = SiteSession.authenticate(
      token: cookies[SiteSession.cookie_name(secure: request.ssl?)],
      audience: current_host.site_origin,
      site: current_site,
      now: Time.current
    )
    true
  end

  def not_found
    head :not_found
  end
end
